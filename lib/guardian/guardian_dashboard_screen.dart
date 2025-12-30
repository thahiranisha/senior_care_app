import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'dialogs/register_senior_dialog.dart' as reg;
import 'guardian_bookings_screen.dart';
import 'guardian_dashboard_content.dart';
import 'models/senior_registration_data.dart';

class GuardianDashboardScreen extends StatefulWidget {
  const GuardianDashboardScreen({super.key});

  @override
  State<GuardianDashboardScreen> createState() => _GuardianDashboardScreenState();
}

class _GuardianDashboardScreenState extends State<GuardianDashboardScreen> {
  static const Color _themeColor = Colors.teal;
  static const Color _bgColor = Color(0xFFF3FAF9);

  String? _selectedSeniorId;

  // streams cached (Flutter web stability)
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _userDocStream;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _guardianDocStream;

  // senior cache
  final Map<String, Map<String, dynamic>> _seniorCache = {};
  bool _loadingCache = false;
  String _cacheKey = '';

  // -------------------------------
  // LOGOUT
  // -------------------------------
  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Do you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Logout')),
        ],
      ),
    );

    if (ok != true) return;

    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  // -------------------------------
  // REGISTER SENIOR
  // -------------------------------
  Future<void> _registerSenior(String guardianUid) async {
    final SeniorRegistrationData? data = await reg.showRegisterSeniorDialog(context);
    if (data == null) return;

    try {
      final db = FirebaseFirestore.instance;

      final seniorRef = await db.collection('seniors').add({
        ...data.toFirestore(),
        'createdByGuardianId': guardianUid,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      await db.collection('users').doc(guardianUid).set(
        {
          'linkedSeniorIds': FieldValue.arrayUnion([seniorRef.id]),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      _snack('Senior registered successfully');
    } catch (e) {
      _snack('Failed to register senior: $e');
    }
  }

  // -------------------------------
  // UNLINK SENIOR
  // -------------------------------
  Future<void> _unlinkSenior(String guardianUid, String seniorId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove senior'),
        content: const Text('Remove this senior from your account?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(guardianUid).update({
        'linkedSeniorIds': FieldValue.arrayRemove([seniorId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _seniorCache.remove(seniorId);
        if (_selectedSeniorId == seniorId) _selectedSeniorId = null;
      });

      _snack('Senior removed');
    } catch (e) {
      _snack('Failed: $e');
    }
  }

  // -------------------------------
  // CACHE SENIORS
  // -------------------------------
  Future<void> _ensureCache(List<String> ids) async {
    if (_loadingCache) return;

    final key = ids.join('|');
    if (key == _cacheKey) return;

    _cacheKey = key;
    _loadingCache = true;

    try {
      final db = FirebaseFirestore.instance;
      for (final id in ids) {
        if (_seniorCache.containsKey(id)) continue;
        final snap = await db.collection('seniors').doc(id).get();
        _seniorCache[id] = snap.data() ?? {};
      }
      if (mounted) setState(() {});
    } finally {
      _loadingCache = false;
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    final uid = currentUser.uid;

    // cache streams once
    _userDocStream ??= FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
    _guardianDocStream ??= FirebaseFirestore.instance.collection('guardians').doc(uid).snapshots();

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _themeColor,
        foregroundColor: Colors.white,
        title: const Text('Guardian Dashboard'),
        actions: [
          IconButton(tooltip: 'Logout', onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _userDocStream,
        builder: (context, userSnap) {
          if (userSnap.hasError) return Center(child: Text('Error: ${userSnap.error}'));
          if (!userSnap.hasData) return const Center(child: CircularProgressIndicator());

          final userData = userSnap.data!.data() ?? {};
          final role = (userData['role'] as String?) ?? '';
          if (role != 'guardian') {
            return const Center(child: Text('Access denied (guardian only).'));
          }

          final fullName = (userData['fullName'] as String?) ?? 'Guardian';
          final ids = ((userData['linkedSeniorIds'] ?? []) as List).map((e) => e.toString()).toList();

          // cache seniors when ids change
          WidgetsBinding.instance.addPostFrameCallback((_) => _ensureCache(ids));

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _guardianDocStream,
            builder: (context, gSnap) {
              if (gSnap.hasError) return Center(child: Text('Error: ${gSnap.error}'));
              if (!gSnap.hasData) return const Center(child: CircularProgressIndicator());

              final g = gSnap.data!.data() ?? {};
              final phone = (g['phone'] as String?)?.trim() ?? '';

              // -------------------
              // EMPTY STATE: no seniors
              // -------------------
              if (ids.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: _themeColor.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(Icons.people_alt_outlined, size: 40, color: _themeColor),
                            ),
                            const SizedBox(height: 14),
                            Text('Hello, $fullName',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text(phone.isEmpty ? 'Contact: Not set' : 'Contact: $phone'),
                            const SizedBox(height: 10),
                            if (phone.isEmpty)
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => Navigator.pushNamed(context, '/guardianProfileEdit'),
                                  icon: const Icon(Icons.phone),
                                  label: const Text('Add contact number'),
                                ),
                              ),
                            const SizedBox(height: 10),
                            const Text(
                              'No seniors linked yet.\nRegister a senior to start monitoring.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _themeColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () => _registerSenior(uid),
                                icon: const Icon(Icons.person_add_alt_1),
                                label: const Text('Register Senior'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }

              // -------------------
              // Selected senior must be valid
              // -------------------
              final String chosenId = (_selectedSeniorId != null && ids.contains(_selectedSeniorId))
                  ? _selectedSeniorId!
                  : ids.first;

              if (chosenId != _selectedSeniorId) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  setState(() => _selectedSeniorId = chosenId);
                });
              }

              final senior = _seniorCache[chosenId] ?? {};
              final seniorName =
                  (senior['fullName'] as String?) ?? (senior['name'] as String?) ?? 'Senior';
              final seniorsCount = ids.length;

              // -------------------
              // MAIN UI
              // -------------------
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  // Header card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _themeColor,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.elderly, color: _themeColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hello, $fullName',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                phone.isEmpty ? 'Contact: Not set' : 'Contact: $phone',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Selected: $seniorName • Seniors: $seniorsCount',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              if (phone.isEmpty) ...[
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(color: Colors.white70),
                                    ),
                                    onPressed: () => Navigator.pushNamed(context, '/guardianProfileEdit'),
                                    icon: const Icon(Icons.phone),
                                    label: const Text('Add contact number'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Register Senior',
                          onPressed: () => _registerSenior(uid),
                          icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Senior selector
                  Card(
                    elevation: 1.5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Selected Senior',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: chosenId,
                                  decoration: InputDecoration(
                                    labelText: 'Choose senior',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  items: ids.map((id) {
                                    final s = _seniorCache[id];
                                    final n = (s?['fullName'] as String?)?.trim();
                                    return DropdownMenuItem<String>(
                                      value: id,
                                      child: Text(
                                        (n != null && n.isNotEmpty) ? n : 'Loading...',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) => setState(() => _selectedSeniorId = value),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: 'Remove selected senior',
                                onPressed: () => _unlinkSenior(uid, chosenId),
                                icon: const Icon(Icons.person_remove_alt_1, color: Colors.redAccent),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),
// My Bookings card
                  Card(
                    elevation: 1.5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    child: ListTile(
                      leading: const Icon(Icons.event_note, color: Colors.teal),
                      title: const Text('My Bookings'),
                      subtitle: const Text('View your caregiver requests & bookings'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const GuardianBookingsScreen()),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Dashboard content
                  GuardianDashboardContent(seniorId: chosenId),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
