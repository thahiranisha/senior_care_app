import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../common/reminder_cache.dart';
import '../common/reminder_runner.dart';
import '../common/med_reminder_sync.dart';

import 'dialogs/register_senior_dialog.dart' as reg;
import 'guardian_bookings_screen.dart';
import 'guardian_medications_screen.dart';
import 'models/senior_registration_data.dart';
import 'caregiver_search_screen.dart';

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

  final ReminderCache _reminderCache = ReminderCache();
  final ReminderRunner _reminderRunner = ReminderRunner();
  String? _reminderSeniorsKey;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sosSub;
  String? _listeningSeniorsKey;

  String? _activeSosAlertId;
  bool _bannerVisible = false;

  @override
  void dispose() {
    _reminderRunner.stop();
    _sosSub?.cancel();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _fmtTs(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}  ${two(d.hour)}:${two(d.minute)}';
  }

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

  Future<void> _pickSenior(BuildContext context, List<String> ids) async {
    final sorted = List<String>.from(ids)..sort();
    await _primeSeniorCache(sorted);
    if (!mounted) return;

    final picked = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
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
      ),
    );

    if (picked != null && mounted) {
      setState(() => _selectedSeniorId = picked);
    }
  }

  Future<String> _generateUniqueLinkCode(FirebaseFirestore db) async {
    final rnd = Random.secure();

    for (int attempt = 0; attempt < 10; attempt++) {
      final code = (rnd.nextInt(900000) + 100000).toString();
      final snap = await db.collection('link_codes').doc(code).get();
      if (!snap.exists) return code;
    }

    final v = DateTime.now().millisecondsSinceEpoch % 1000000;
    return v.toString().padLeft(6, '0');
  }

  Future<void> _showLinkCodeDialog({required String seniorName, required String linkCode}) async {
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

      await _primeSeniorCache([seniorDoc.id]);
      await _showLinkCodeDialog(seniorName: data.fullName, linkCode: linkCode);
      _snack('Senior registered successfully');
    } catch (e) {
      _snack('Failed to register senior: $e');
    }
  }

  void _openMedications(String seniorId, String seniorName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GuardianMedicationsScreen(
          seniorId: seniorId,
          seniorName: seniorName,
        ),
      ),
    );
  }

  bool _isMedValidForToday(Map<String, dynamic> d) {
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    final dayEnd = dayStart.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));

    final sd = d['startDate'];
    final ed = d['endDate'];
    final start = (sd is Timestamp) ? sd.toDate() : null;
    final end = (ed is Timestamp) ? ed.toDate() : null;

    final startOk = (start == null) || !start.isAfter(dayEnd);
    final endOk = (end == null) || !end.isBefore(dayStart);
    return startOk && endOk;
  }

  DateTime? _nextDose(DateTime now, List<String> times) {
    DateTime? best;
    for (final t in times) {
      final parts = t.split(':');
      if (parts.length != 2) continue;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null) continue;

      var candidate = DateTime(now.year, now.month, now.day, h, m);
      if (!candidate.isAfter(now)) candidate = candidate.add(const Duration(days: 1));
      if (best == null || candidate.isBefore(best)) best = candidate;
    }
    return best;
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? color,
  }) {
    final c = color ?? _themeColor;
    return Card(
      elevation: 1.2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: c),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: const TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black45),
            ],
          ),
        ),
      ),
    );
  }

  void _ensureGuardianRemindersForIds(List<String> seniorIds) {
    final ids = seniorIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toList()..sort();
    final key = ids.join(',');
    if (_reminderSeniorsKey == key) return;

    _reminderSeniorsKey = key;
    _reminderRunner.stop();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      await _reminderCache.load();
      await syncMedicationRemindersForSeniors(seniorIds: ids, cache: _reminderCache);
      _reminderRunner.start(cache: _reminderCache, context: context);
    });
  }

  Future<bool> _isSosAcked(String alertId, String guardianUid) async {
    final ref = FirebaseFirestore.instance
        .collection('alerts')
        .doc(alertId)
        .collection('acks')
        .doc(guardianUid);
    final snap = await ref.get();
    return snap.exists;
  }

  Future<void> _ackSos(String alertId, String guardianUid) async {
    final ref = FirebaseFirestore.instance
        .collection('alerts')
        .doc(alertId)
        .collection('acks')
        .doc(guardianUid);

    await ref.set({
      'guardianId': guardianUid,
      'ackAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _hideBanner() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
    _bannerVisible = false;
  }

  void _showSosBanner({
    required String alertId,
    required String seniorId,
    required String seniorName,
    required String message,
    required String timeText,
    required String guardianUid,
  }) {
    if (!mounted) return;
    if (_bannerVisible && _activeSosAlertId == alertId) return;

    _hideBanner();
    _bannerVisible = true;
    _activeSosAlertId = alertId;

    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        backgroundColor: Colors.red.shade50,
        leading: const Icon(Icons.sos_rounded, color: Colors.redAccent),
        content: Text(
          'SOS from $seniorName\n$message\n$timeText',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _ackSos(alertId, guardianUid);
              _hideBanner();
            },
            child: const Text('DISMISS'),
          ),
        ],
      ),
    );
  }

  void _attachSosListenerForGuardianSeniors(List<String> seniorIds) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final cleaned = seniorIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toList()..sort();
    final key = cleaned.join(',');

    if (_listeningSeniorsKey == key) return;
    _listeningSeniorsKey = key;

    _sosSub?.cancel();

    if (cleaned.isEmpty) return;

    if (cleaned.length > 10) {
      _snack('Too many linked seniors for SOS watch (max 10).');
      return;
    }

    final db = FirebaseFirestore.instance;

    _sosSub = db
        .collection('alerts')
        .where('type', isEqualTo: 'SOS')
        .where('seniorId', whereIn: cleaned)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snap) async {
      if (!mounted) return;

      if (snap.docs.isEmpty) {
        if (_bannerVisible) _hideBanner();
        return;
      }

      final doc = snap.docs.first;
      final alertId = doc.id;

      final acked = await _isSosAcked(alertId, user.uid);
      if (acked) {
        if (_bannerVisible && _activeSosAlertId == alertId) _hideBanner();
        return;
      }

      final data = doc.data();
      final sid = (data['seniorId'] as String?) ?? '';
      final msg = (data['message'] as String?) ?? 'SOS alert';
      final ts = data['createdAt'] as Timestamp?;
      final timeText = _fmtTs(ts);

      final sName = (_seniorCache[sid]?['fullName'] as String?)?.trim();
      final seniorName = (sName != null && sName.isNotEmpty) ? sName : sid;

      _showSosBanner(
        alertId: alertId,
        seniorId: sid,
        seniorName: seniorName,
        message: msg,
        timeText: timeText,
        guardianUid: user.uid,
      );
    }, onError: (e) {
      if (!mounted) return;
      _snack('SOS listener error: $e');
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _seniorStatusStream(String seniorId) {
    return FirebaseFirestore.instance.collection('senior_status').doc(seniorId).snapshots();
  }

  void _openCaregivers(String seniorId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CaregiverSearchScreen(seniorId: seniorId)),
    );
  }

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
          final ids = ((userData['linkedSeniorIds'] ?? []) as List).map((e) => e.toString()).toList()..sort();

          _primeSeniorCache(ids);
          _attachSosListenerForGuardianSeniors(ids);

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

          _ensureGuardianRemindersForIds([chosenId]);

          final s = _seniorCache[chosenId];
          final name = (s?['fullName'] as String?)?.trim();
          final display = (name != null && name.isNotEmpty) ? name : chosenId;

          final medsStream = FirebaseFirestore.instance
              .collection('seniors')
              .doc(chosenId)
              .collection('medications')
              .where('isActive', isEqualTo: true)
              .snapshots();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
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
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: _seniorStatusStream(chosenId),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      child: const ListTile(
                        leading: Icon(Icons.favorite_border, color: Colors.orange),
                        title: Text('Check-in status', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Loading...'),
                      ),
                    );
                  }

                  final data = snap.data!.data() ?? {};
                  final lastCheckIn = data['lastCheckIn'] as Timestamp?;
                  final mood = (data['lastMood'] as String?)?.trim();

                  if (lastCheckIn == null) {
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      child: const ListTile(
                        leading: Icon(Icons.favorite_border, color: Colors.orange),
                        title: Text('Check-in status', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('No check-ins yet'),
                      ),
                    );
                  }

                  final moodText = (mood == null || mood.isEmpty) ? 'Mood: -' : 'Mood: $mood';

                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    child: ListTile(
                      leading: const Icon(Icons.favorite, color: Colors.orange),
                      title: const Text('Check-in status', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Last: ${_fmtTs(lastCheckIn)}\n$moodText'),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: medsStream,
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return _actionTile(
                      icon: Icons.medication_outlined,
                      title: 'Medications',
                      subtitle: 'Loading...',
                      onTap: () => _openMedications(chosenId, display),
                    );
                  }

                  final now = DateTime.now();

                  final validToday = snap.data!.docs
                      .map((d) => d.data())
                      .where(_isMedValidForToday)
                      .where((d) => ((d['times'] ?? []) as List).isNotEmpty)
                      .toList();

                  if (validToday.isEmpty) {
                    return _actionTile(
                      icon: Icons.medication_outlined,
                      title: 'Medications',
                      subtitle: 'No meds today',
                      onTap: () => _openMedications(chosenId, display),
                    );
                  }

                  DateTime? bestTime;
                  String bestName = '';

                  for (final d in validToday) {
                    final medName = (d['name'] as String?) ?? 'Medication';
                    final times = ((d['times'] ?? []) as List).map((e) => e.toString()).toList();
                    final next = _nextDose(now, times);
                    if (next == null) continue;

                    if (bestTime == null || next.isBefore(bestTime!)) {
                      bestTime = next;
                      bestName = medName;
                    }
                  }

                  final subtitle = (bestTime == null)
                      ? '${validToday.length} meds'
                      : 'Next: ${TimeOfDay.fromDateTime(bestTime!).format(context)}\n$bestName';

                  return _actionTile(
                    icon: Icons.medication_outlined,
                    title: 'Medications',
                    subtitle: subtitle,
                    onTap: () => _openMedications(chosenId, display),
                  );
                },
              ),
              const SizedBox(height: 14),
              Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: ListTile(
                  leading: const Icon(Icons.event_note, color: Colors.teal),
                  title: const Text('My Bookings'),
                  subtitle: const Text('View your caregiver requests & bookings'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const GuardianBookingsScreen()));
                  },
                ),
              ),
              const SizedBox(height: 14),
              _actionTile(
                icon: Icons.search,
                title: 'Find Caregivers',
                subtitle: 'Search and request care',
                onTap: () => _openCaregivers(chosenId),
              ),
            ],
          );
        },
      ),
    );
  }
}
