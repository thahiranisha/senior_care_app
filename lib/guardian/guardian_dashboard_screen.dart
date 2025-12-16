import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'dialogs/register_senior_dialog.dart';
import 'guardian_dashboard_content.dart';
import 'dialogs/register_senior_dialog.dart' as reg;
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

  // Cache senior docs (id -> senior doc)
  final Map<String, Map<String, dynamic>> _seniorCache = {};
  bool _loadingCache = false;
  String _cacheKey = '';

  // -------------------------------
  // LOGOUT (confirm)
  // -------------------------------
  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Do you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  // -------------------------------
  // REGISTER SENIOR (dialog -> Firestore)
  // -------------------------------
  Future<void> _registerSenior(String guardianUid) async {
    final SeniorRegistrationData? data =
    await reg.showRegisterSeniorDialog(context);
    if (data == null) return;

    try {
      final db = FirebaseFirestore.instance;

      // 1️⃣ Create senior
      final seniorRef = await db.collection('seniors').add({
        ...data.toFirestore(),
        'createdByGuardianId': guardianUid,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      // 2️⃣ Link senior to guardian
      await db.collection('users').doc(guardianUid).set(
        {
          'linkedSeniorIds': FieldValue.arrayUnion([seniorRef.id]),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      debugPrint('✅ Senior saved: ${seniorRef.id}');
      _snack('Senior registered successfully');
    } catch (e, st) {
      debugPrint('❌ Firestore error: $e');
      debugPrint('$st');
      _snack('Failed to register senior');
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
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
  // Cache seniors once when ids change
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
    final userDocStream = FirebaseFirestore.instance.collection('users').doc(uid).snapshots();

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _themeColor,
        foregroundColor: Colors.white,
        title: const Text('Guardian Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: userDocStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() ?? {};
          final role = (data['role'] as String?) ?? '';
          if (role != 'guardian') {
            return const Center(child: Text('Access denied (guardian only).'));
          }

          final fullName = (data['fullName'] as String?) ?? 'Guardian';
          final ids = ((data['linkedSeniorIds'] ?? []) as List).map((e) => e.toString()).toList();

          // load cache once when ids change
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _ensureCache(ids);
          });

          // ✅ keep selected id valid (without messy build-time changes)
          if (ids.isNotEmpty) {
            final desired = (_selectedSeniorId != null && ids.contains(_selectedSeniorId))
                ? _selectedSeniorId
                : ids.first;

            if (desired != _selectedSeniorId) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                setState(() => _selectedSeniorId = desired);
              });
            }
          }

          // Empty state
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
                        Text(
                          'Hello, $fullName',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
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

          final selectedId = _selectedSeniorId ?? ids.first;
          final senior = _seniorCache[selectedId] ?? {};
          final seniorName =
              (senior['fullName'] as String?) ?? (senior['name'] as String?) ?? 'Senior';

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
                            'Monitoring: $seniorName',
                            style: const TextStyle(color: Colors.white70),
                          ),
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

              // Senior selector card
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
                              value: selectedId,
                              decoration: InputDecoration(
                                labelText: 'Choose senior',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              items: ids.map((id) {
                                final s = _seniorCache[id];
                                final fullName = (s?['fullName'] as String?)?.trim();

                                return DropdownMenuItem<String>(
                                  value: id,
                                  child: Text(
                                    (fullName != null && fullName.isNotEmpty) ? fullName : 'Loading...',
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
                            onPressed: () => _unlinkSenior(uid, selectedId),
                            icon: const Icon(Icons.person_remove_alt_1, color: Colors.redAccent),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Dashboard content
              GuardianDashboardContent(seniorId: selectedId),
            ],
          );
        },
      ),
    );
  }
}
