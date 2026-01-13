import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  Stream<DocumentSnapshot<Map<String, dynamic>>>? _userDocStream;

  final Map<String, Map<String, dynamic>> _seniorCache = {};
  bool _loadingCache = false;

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

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // -------------------------------
  // LOAD SENIOR NAMES (only when needed)
  // -------------------------------
  Future<void> _primeSeniorCache(List<String> ids) async {
    if (_loadingCache) return;

    final missing = ids.where((id) => !_seniorCache.containsKey(id)).toList();
    if (missing.isEmpty) return;

    _loadingCache = true;
    try {
      final db = FirebaseFirestore.instance;
      final snaps = await Future.wait(missing.map((id) => db.collection('seniors').doc(id).get()));

      final next = <String, Map<String, dynamic>>{};
      for (final s in snaps) {
        next[s.id] = s.data() ?? {};
      }

      if (!mounted) return;
      setState(() => _seniorCache.addAll(next));
    } finally {
      _loadingCache = false;
    }
  }

  // -------------------------------
  // SENIOR PICKER (Dialog - stable)
  // -------------------------------
  Future<void> _pickSenior(BuildContext context, List<String> ids) async {
    final sorted = List<String>.from(ids)..sort();

    // ✅ load names BEFORE opening the picker (so no setState while list is open)
    await _primeSeniorCache(sorted);

    if (!mounted) return;

    final picked = await showDialog<String>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Select Senior'),
          content: SizedBox(
            width: double.maxFinite,
            height: 420,
            child: ListView.builder(
              itemCount: sorted.length,
              itemBuilder: (_, i) {
                final id = sorted[i];
                final name = (_seniorCache[id]?['fullName'] as String?)?.trim();
                final display = (name != null && name.isNotEmpty) ? name : id;

                return ListTile(
                  title: Text(display, overflow: TextOverflow.ellipsis),
                  subtitle: (name != null && name.isNotEmpty) ? Text(id) : null,
                  onTap: () => Navigator.pop(context, id),
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ],
        );
      },
    );

    if (picked != null && mounted) {
      setState(() => _selectedSeniorId = picked);
    }
  }

  // -------------------------------
  // REGISTER SENIOR
  // -------------------------------
  Future<String> _generateUniqueLinkCode(FirebaseFirestore db) async {
    final rnd = Random.secure();

    for (int attempt = 0; attempt < 10; attempt++) {
      final code = (rnd.nextInt(900000) + 100000).toString(); // 6 digits
      final snap = await db.collection('link_codes').doc(code).get();
      if (!snap.exists) return code;
    }

    final v = DateTime.now().millisecondsSinceEpoch % 1000000;
    return v.toString().padLeft(6, '0');
  }

  Future<void> _showLinkCodeDialog({
    required String seniorName,
    required String linkCode,
  }) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Senior link code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Give this code to $seniorName to link their login.'),
            const SizedBox(height: 12),
            SelectableText(
              linkCode,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: linkCode));
              if (mounted) _snack('Link code copied');
            },
            child: const Text('Copy'),
          ),
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _registerSenior(String guardianUid) async {
    final SeniorRegistrationData? data = await reg.showRegisterSeniorDialog(context);
    if (data == null) return;

    try {
      final db = FirebaseFirestore.instance;

      final seniorDoc = db.collection('seniors').doc();
      final linkCode = await _generateUniqueLinkCode(db);

      await seniorDoc.set({
        ...data.toFirestore(),
        'createdByGuardianId': guardianUid,
        'guardianId': guardianUid,
        'createdAt': FieldValue.serverTimestamp(),
        'linkCode': linkCode,
        'linkedAuthUid': null,
        'linked': false,
        'linkedAt': null,
        'isActive': true,
      });

      await db.collection('link_codes').doc(linkCode).set({
        'seniorId': seniorDoc.id,
        'used': false,
        'usedByUid': null,
        'createdByGuardianId': guardianUid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await db.collection('users').doc(guardianUid).set(
        {
          'linkedSeniorIds': FieldValue.arrayUnion([seniorDoc.id]),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // optional: cache immediately so it appears fast
      await _primeSeniorCache([seniorDoc.id]);

      await _showLinkCodeDialog(seniorName: data.fullName, linkCode: linkCode);
      _snack('Senior registered successfully');
    } catch (e) {
      _snack('Failed to register senior: $e');
    }
  }

  // -------------------------------
  // UI
  // -------------------------------
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    final uid = currentUser.uid;
    _userDocStream ??= FirebaseFirestore.instance.collection('users').doc(uid).snapshots();

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
          final ids = ((userData['linkedSeniorIds'] ?? []) as List).map((e) => e.toString()).toList()
            ..sort();

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

          final chosenId =
          (_selectedSeniorId != null && ids.contains(_selectedSeniorId)) ? _selectedSeniorId! : ids.first;

          final s = _seniorCache[chosenId];
          final name = (s?['fullName'] as String?)?.trim();
          final display = (name != null && name.isNotEmpty) ? name : chosenId;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              // Header
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
                          const SizedBox(height: 6),
                          Text(
                            'Selected: $display • Seniors: ${ids.length}',
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

              // Senior selector (tap -> dialog)
              Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: ListTile(
                  title: const Text('Selected Senior'),
                  subtitle: Text(display, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.arrow_drop_down),
                  onTap: () => _pickSenior(context, ids),
                ),
              ),

              const SizedBox(height: 14),

              // Bookings
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

              KeyedSubtree(
                key: ValueKey('guardian-content-$chosenId'),
                child: GuardianDashboardContent(seniorId: chosenId),
              ),

            ],
          );
        },
      ),
    );
  }
}