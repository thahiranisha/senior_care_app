import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../common/reminder_cache.dart';
import '../common/reminder_runner.dart';
import '../common/med_reminder_sync.dart';

class SeniorDashboardScreen extends StatefulWidget {
  const SeniorDashboardScreen({super.key});

  @override
  State<SeniorDashboardScreen> createState() => _SeniorDashboardScreenState();
}

class _SeniorDashboardScreenState extends State<SeniorDashboardScreen> {
  static const Color _themeColor = Colors.teal;
  static const Color _bgColor = Color(0xFFF3FAF9);

  String? _uid;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _userDocStream;

  String? _seniorId;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _seniorDocStream;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _statusStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _medicationsStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _alertsStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _activityStream;

  final ReminderCache _reminderCache = ReminderCache();
  final ReminderRunner _reminderRunner = ReminderRunner();

  bool _remindersSyncedForSenior = false;

  // Right after linking (or right after login), the users/{uid} stream can
  // briefly emit a state where role/seniorId is missing. If we immediately
  // redirect to /seniorLinkCode, the senior experiences a "bounce" back to
  // the link screen even though linking actually succeeded.
  DateTime? _unlinkedSince;

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _uid = user.uid;
      _userDocStream = FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots();
    }
  }

  @override
  void dispose() {
    _reminderRunner.stop();
    super.dispose();
  }

  void _initSeniorStreams(String seniorId) {
    final db = FirebaseFirestore.instance;

    // If senior changes, reset reminder sync + stop old runner
    if (_seniorId != null && _seniorId != seniorId) {
      _reminderRunner.stop();
      _remindersSyncedForSenior = false;
    }

    _seniorId = seniorId;

    _seniorDocStream = db.collection('seniors').doc(seniorId).snapshots();
    _statusStream = db.collection('senior_status').doc(seniorId).snapshots();

    _medicationsStream = db
        .collection('seniors')
        .doc(seniorId)
        .collection('medications')
        .where('isActive', isEqualTo: true)
        .snapshots();

    _alertsStream = db
        .collection('alerts')
        .where('seniorId', isEqualTo: seniorId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots();

    _activityStream = db
        .collection('activity_logs_today')
        .where('seniorId', isEqualTo: seniorId)
        .orderBy('time', descending: true)
        .limit(5)
        .snapshots();
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

  void _open(String route, {Map<String, dynamic>? args}) {
    Navigator.pushNamed(context, route, arguments: args);
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

  String _fmtTime(BuildContext context, Timestamp? ts) {
    if (ts == null) return '-';
    return TimeOfDay.fromDateTime(ts.toDate()).format(context);
  }

  bool _isMedValidNow(Map<String, dynamic> d, DateTime now) {
    final sd = d['startDate'];
    final ed = d['endDate'];

    final start = (sd is Timestamp) ? sd.toDate() : null;
    final end = (ed is Timestamp) ? ed.toDate() : null;

    if (start != null && now.isBefore(start)) return false;
    if (end != null && now.isAfter(end)) return false;
    return true;
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

  @override
  Widget build(BuildContext context) {
    if (_uid == null || _userDocStream == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _themeColor,
        foregroundColor: Colors.white,
        title: const Text('Senior Dashboard'),
        actions: [
          IconButton(tooltip: 'Logout', onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _userDocStream,
        builder: (context, userSnap) {
          if (userSnap.hasError) return Center(child: Text('Error: ${userSnap.error}'));
          if (!userSnap.hasData) return const Center(child: CircularProgressIndicator());

          final u = userSnap.data!.data() ?? <String, dynamic>{};
          final role = (u['role'] as String?)?.toLowerCase().trim();
          final seniorId = (u['seniorId'] as String?)?.trim();

          // Not linked -> go link screen
          if (role != 'senior' || seniorId == null || seniorId.isEmpty) {
            _unlinkedSince ??= DateTime.now();

            // Give Firestore a short grace period to deliver the updated user
            // profile (avoids redirect loop right after linking).
            final elapsed = DateTime.now().difference(_unlinkedSince!);
            if (elapsed < const Duration(seconds: 2)) {
              return const Center(child: CircularProgressIndicator());
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              Navigator.pushNamedAndRemoveUntil(context, '/seniorLinkCode', (_) => false);
            });
            return const Center(child: CircularProgressIndicator());
          }

          // Linked OK -> reset grace timer
          _unlinkedSince = null;

          // Init streams once per seniorId
          if (_seniorId != seniorId || _seniorDocStream == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() => _initSeniorStreams(seniorId));
            });
            return const Center(child: CircularProgressIndicator());
          }

          // Sync reminders ONCE (web timer reminders)
          if (!_remindersSyncedForSenior) {
            _remindersSyncedForSenior = true;

            WidgetsBinding.instance.addPostFrameCallback((_) async {
              if (!mounted) return;

              await _reminderCache.load();
              await syncMedicationRemindersForSeniors(seniorIds: [seniorId!], cache: _reminderCache);

              debugPrint('After sync: cache size = ${_reminderCache.all.length}');
              debugPrint('Sample keys: ${_reminderCache.all.keys.take(3).toList()}');

              _reminderRunner.start(cache: _reminderCache, context: context);
            });
          }


          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _seniorDocStream,
            builder: (context, sSnap) {
              if (sSnap.hasError) return Center(child: Text('Error: ${sSnap.error}'));
              if (!sSnap.hasData) return const Center(child: CircularProgressIndicator());

              final s = sSnap.data!.data() ?? <String, dynamic>{};

              final name = (s['fullName'] as String?)?.trim().isNotEmpty == true
                  ? (s['fullName'] as String)
                  : ((s['name'] as String?)?.trim().isNotEmpty == true ? (s['name'] as String) : 'Senior');

              final guardianId = ((s['guardianId'] as String?) ?? (s['createdByGuardianId'] as String?) ?? '').trim();

              final argsBase = <String, dynamic>{
                'seniorId': _seniorId,
                'seniorName': name,
                'guardianId': guardianId,
              };

              return ListView(
                padding: const EdgeInsets.all(16),
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
                          radius: 26,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.elderly, color: _themeColor, size: 28),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hello, $name',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Today: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: _statusStream,
                          builder: (context, snap) {
                            String subtitle = 'No check-in yet';
                            if (snap.hasData && snap.data!.data() != null) {
                              final d = snap.data!.data()!;
                              final lastCheckIn = d['lastCheckIn'] as Timestamp?;
                              final lastMood = (d['lastMood'] as String?) ?? '-';
                              if (lastCheckIn != null) {
                                subtitle = 'Last: ${_fmtTime(context, lastCheckIn)}\nMood: $lastMood';
                              }
                            }

                            return _actionTile(
                              icon: Icons.favorite_outline,
                              title: 'Check-in',
                              subtitle: subtitle,
                              onTap: () => _open('/seniorCheckin', args: {'seniorId': _seniorId}),
                              color: Colors.pink,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Medications tile: show NEXT time
                      Expanded(
                        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: _medicationsStream,
                          builder: (context, snap) {
                            if (!snap.hasData) {
                              return _actionTile(
                                icon: Icons.medication_outlined,
                                title: 'Medications',
                                subtitle: 'Loading...',
                                onTap: () => _open('/seniorMedications', args: argsBase),
                              );
                            }

                            final now = DateTime.now();

                            final valid = snap.data!.docs
                                .map((d) => d.data())
                                .where((d) => _isMedValidNow(d, now))
                                .toList();

                            if (valid.isEmpty) {
                              return _actionTile(
                                icon: Icons.medication_outlined,
                                title: 'Medications',
                                subtitle: 'No meds today',
                                onTap: () => _open('/seniorMedications', args: argsBase),
                              );
                            }

                            DateTime? bestTime;
                            String bestName = '';

                            for (final d in valid) {
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
                                ? '${valid.length} meds'
                                : 'Next: ${TimeOfDay.fromDateTime(bestTime!).format(context)}\n$bestName';

                            return _actionTile(
                              icon: Icons.medication_outlined,
                              title: 'Medications',
                              subtitle: subtitle,
                              onTap: () => _open('/seniorMedications', args: argsBase),
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  _actionTile(
                    icon: Icons.sos,
                    title: 'Emergency SOS',
                    subtitle: 'Send an alert to your guardian',
                    color: Colors.redAccent,
                    onTap: () => _open('/seniorEmergency', args: argsBase),
                  ),

                  const SizedBox(height: 12),

                  // Latest alert (if any)
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _alertsStream,
                    builder: (context, snap) {
                      if (!snap.hasData || snap.data!.docs.isEmpty) return const SizedBox.shrink();
                      final a = snap.data!.docs.first.data();
                      final type = (a['type'] as String?) ?? 'ALERT';
                      final message = (a['message'] as String?) ?? 'New alert';

                      return Card(
                        elevation: 1.5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        color: Colors.orange.shade50,
                        child: ListTile(
                          leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                          title: Text('Latest alert: $type', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(message),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Build reminders from Firestore meds and store in local cache.
/// (Web: used by ReminderRunner to show in-app reminders.)
Future<void> syncRemindersOnce({
  required String seniorId,
  required ReminderCache cache,
}) async {
  final snap = await FirebaseFirestore.instance
      .collection('seniors')
      .doc(seniorId)
      .collection('medications')
      .where('isActive', isEqualTo: true)
      .get();

  final now = DateTime.now();

  bool validNow(Map<String, dynamic> d) {
    final sd = d['startDate'];
    final ed = d['endDate'];
    final start = (sd is Timestamp) ? sd.toDate() : null;
    final end = (ed is Timestamp) ? ed.toDate() : null;
    if (start != null && now.isBefore(start)) return false;
    if (end != null && now.isAfter(end)) return false;
    return true;
  }

  final next = <String, Map<String, dynamic>>{};

  for (final doc in snap.docs) {
    final d = doc.data();
    if (!validNow(d)) continue;

    final medName = (d['name'] as String?) ?? 'Medication';
    final times = ((d['times'] ?? []) as List).map((e) => e.toString()).toList();

    for (final t in times) {
      final key = '$seniorId|${doc.id}|$t';
      next[key] = {
        'seniorId': seniorId,
        'medId': doc.id,
        'name': medName,
        'time': t, // "08:00"
        'enabled': true,
      };
    }
  }

  cache.setAll(next);
  await cache.save();
}
