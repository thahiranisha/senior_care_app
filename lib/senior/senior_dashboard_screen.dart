import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Senior Dashboard
///
/// Assumptions (MVP):
/// - users/{uid} contains: role='senior', seniorId
/// - seniors/{seniorId} contains: fullName/name, guardianId, city/address
/// - Optional collections used for summary:
///   - senior_status/{seniorId} (lastCheckIn, lastMood)
///   - med_stats_today/{seniorId} (taken,total)
///   - alerts (where seniorId, createdAt)
///   - activity_logs_today (where seniorId, time)
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
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _medStatsStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _alertsStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _activityStream;

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _uid = user.uid;
      _userDocStream = FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots();
    }
  }

  void _initSeniorStreams(String seniorId) {
    final db = FirebaseFirestore.instance;
    _seniorId = seniorId;
    _seniorDocStream = db.collection('seniors').doc(seniorId).snapshots();
    _statusStream = db.collection('senior_status').doc(seniorId).snapshots();
    _medStatsStream = db.collection('med_stats_today').doc(seniorId).snapshots();
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

          // Not linked yet -> force link flow.
          if (role != 'senior' || seniorId == null || seniorId.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              Navigator.pushNamedAndRemoveUntil(context, '/seniorLinkCode', (_) => false);
            });
            return const Center(child: CircularProgressIndicator());
          }

          // Init streams once per seniorId
          if (_seniorId != seniorId || _seniorDocStream == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() => _initSeniorStreams(seniorId));
            });
            return const Center(child: CircularProgressIndicator());
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

              String line(String label, Object? value) {
                final v = (value == null) ? '' : value.toString().trim();
                return v.isEmpty ? '' : '$label: $v';
              }

              final profileLines = <String>[
                line('City', s['city']),
                line('Address', s['address']),
              ].where((e) => e.isNotEmpty).toList();

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

                  // Summary tiles (Check-in / Meds)
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
                      Expanded(
                        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: _medStatsStream,
                          builder: (context, snap) {
                            String subtitle = 'No meds today';
                            if (snap.hasData && snap.data!.data() != null) {
                              final d = snap.data!.data()!;
                              final taken = d['taken'] ?? 0;
                              final total = d['total'] ?? 0;
                              subtitle = '$taken / $total taken';
                            }

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

                  _actionTile(
                    icon: Icons.person,
                    title: 'My Profile',
                    subtitle: 'View your details',
                    onTap: () => _open('/seniorProfile', args: {'seniorId': _seniorId}),
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

                  const SizedBox(height: 10),
                  const Text("Today's Activity", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 1.5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _activityStream,
                      builder: (context, snap) {
                        if (!snap.hasData || snap.data!.docs.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(14),
                            child: Text('No activity logged yet today.'),
                          );
                        }

                        final docs = snap.data!.docs;
                        return Column(
                          children: [
                            for (int i = 0; i < docs.length; i++) ...[
                              ListTile(
                                dense: true,
                                leading: const Icon(Icons.chevron_right),
                                title: Text((docs[i].data()['description'] as String?) ?? ''),
                                subtitle: _buildActivitySubtitle(context, docs[i].data()),
                              ),
                              if (i != docs.length - 1) const Divider(height: 1),
                            ],
                          ],
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),
                  Card(
                    elevation: 1.2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Quick Info', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          if (guardianId.isNotEmpty)
                            Text('Guardian ID: $guardianId', style: const TextStyle(fontSize: 16)),
                          if (profileLines.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ...profileLines.map((t) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(t, style: const TextStyle(fontSize: 16)),
                                )),
                          ],
                          if (guardianId.isEmpty && profileLines.isEmpty)
                            const Text('Your details will appear here.', style: TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildActivitySubtitle(BuildContext context, Map<String, dynamic> data) {
    final type = (data['type'] as String?) ?? 'INFO';
    final ts = data['time'] as Timestamp?;
    final timeText = ts == null ? '-' : TimeOfDay.fromDateTime(ts.toDate()).format(context);
    return Text('$type • $timeText');
  }
}
