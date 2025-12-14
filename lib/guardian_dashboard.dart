// lib/guardian_dashboard.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class GuardianDashboardScreen extends StatefulWidget {
  const GuardianDashboardScreen({super.key});

  @override
  State<GuardianDashboardScreen> createState() =>
      _GuardianDashboardScreenState();
}

class _GuardianDashboardScreenState extends State<GuardianDashboardScreen> {
  String? _selectedSeniorId;

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in')),
      );
    }

    final guardianDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .withConverter<Map<String, dynamic>>(
      fromFirestore: (snap, _) => snap.data() ?? {},
      toFirestore: (data, _) => data,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Guardian Dashboard'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: guardianDoc.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() ?? {};
          final List<dynamic> linkedSeniorIds = data['linkedSeniorIds'] ?? [];

          if (linkedSeniorIds.isEmpty) {
            return const Center(
              child: Text('No seniors linked to this account yet.'),
            );
          }

          // default selection
          _selectedSeniorId ??= linkedSeniorIds.first as String;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // senior selector
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: DropdownButtonFormField<String>(
                  value: _selectedSeniorId,
                  decoration: const InputDecoration(
                    labelText: 'Select Senior',
                    border: OutlineInputBorder(),
                  ),
                  items: linkedSeniorIds
                      .map(
                        (id) => DropdownMenuItem<String>(
                      value: id as String,
                      child: FutureBuilder<
                          DocumentSnapshot<Map<String, dynamic>>>(
                        future: FirebaseFirestore.instance
                            .collection('seniors')
                            .doc(id as String)
                            .get(),
                        builder: (context, snap) {
                          final name =
                              snap.data?.data()?['name'] as String? ??
                                  'Senior';
                          return Text(name);
                        },
                      ),
                    ),
                  )
                      .toList(),
                  onChanged: (value) {
                    setState(() => _selectedSeniorId = value);
                  },
                ),
              ),

              if (_selectedSeniorId != null)
                Expanded(
                  // 👇 THIS is the widget that was missing
                  child: GuardianDashboardContent(
                    seniorId: _selectedSeniorId!,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ----------------------------------------------------------------------
// DASHBOARD CONTENT FOR ONE SENIOR
// ----------------------------------------------------------------------

class GuardianDashboardContent extends StatelessWidget {
  final String seniorId;

  const GuardianDashboardContent({
    super.key,
    required this.seniorId,
  });

  @override
  Widget build(BuildContext context) {
    final statusRef =
    FirebaseFirestore.instance.collection('senior_status').doc(seniorId);
    final medStatsRef =
    FirebaseFirestore.instance.collection('med_stats_today').doc(seniorId);
    final alertsQuery = FirebaseFirestore.instance
        .collection('alerts')
        .where('seniorId', isEqualTo: seniorId)
        .orderBy('createdAt', descending: true)
        .limit(1);
    final appointmentsQuery = FirebaseFirestore.instance
        .collection('appointments')
        .where('seniorId', isEqualTo: seniorId)
        .orderBy('time')
        .limit(1);
    final activityQuery = FirebaseFirestore.instance
        .collection('activity_logs_today')
        .where('seniorId', isEqualTo: seniorId)
        .orderBy('time', descending: true)
        .limit(5);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // latest alert banner
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: alertsQuery.snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const SizedBox.shrink();
              }
              final alert = snapshot.data!.docs.first.data();
              final type = alert['type'] as String? ?? 'ALERT';
              final message = alert['message'] as String? ?? 'New alert';
              return Card(
                color: Colors.red.shade100,
                child: ListTile(
                  leading: const Icon(Icons.warning_amber_rounded),
                  title: Text('Latest alert: $type'),
                  subtitle: Text(message),
                  onTap: () {
                    // TODO: navigate to full alerts screen
                  },
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          // summary cards
          Row(
            children: [
              Expanded(
                child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: statusRef.snapshots(),
                  builder: (context, snapshot) {
                    String subtitle = 'No data';
                    if (snapshot.hasData && snapshot.data!.data() != null) {
                      final data = snapshot.data!.data()!;
                      final lastCheckIn = data['lastCheckIn'] as Timestamp?;
                      final lastMood = data['lastMood'] as String?;
                      if (lastCheckIn != null) {
                        final time =
                        TimeOfDay.fromDateTime(lastCheckIn.toDate());
                        subtitle =
                        'Last: ${time.format(context)} • Mood: ${lastMood ?? '-'}';
                      }
                    }
                    return _DashboardCard(
                      title: 'Check-in',
                      subtitle: subtitle,
                      icon: Icons.favorite_outline,
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: medStatsRef.snapshots(),
                  builder: (context, snapshot) {
                    String subtitle = 'No meds today';
                    if (snapshot.hasData && snapshot.data!.data() != null) {
                      final data = snapshot.data!.data()!;
                      final taken = data['taken'] ?? 0;
                      final total = data['total'] ?? 0;
                      subtitle = '$taken / $total taken';
                    }
                    return _DashboardCard(
                      title: 'Medications',
                      subtitle: subtitle,
                      icon: Icons.medication_outlined,
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: appointmentsQuery.snapshots(),
                  builder: (context, snapshot) {
                    String subtitle = 'None';
                    if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                      final appt = snapshot.data!.docs.first.data();
                      final title = appt['title'] as String? ?? 'Appointment';
                      final time = (appt['time'] as Timestamp).toDate();
                      final timeText =
                          '${time.day}/${time.month} • ${TimeOfDay.fromDateTime(time).format(context)}';
                      subtitle = '$title\n$timeText';
                    }
                    return _DashboardCard(
                      title: 'Next Visit',
                      subtitle: subtitle,
                      icon: Icons.event,
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          const Text(
            "Today's Activity",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: activityQuery.snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Text('No activity logged yet today.');
              }
              final docs = snapshot.data!.docs;
              return Column(
                children: docs.map((doc) {
                  final data = doc.data();
                  final type = data['type'] as String? ?? 'INFO';
                  final desc = data['description'] as String? ?? '';
                  final time = (data['time'] as Timestamp).toDate();
                  final timeText =
                  TimeOfDay.fromDateTime(time).format(context);
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.chevron_right),
                    title: Text(desc),
                    subtitle: Text('$type • $timeText'),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 16),

          const Text(
            'Quick Actions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _QuickActionButton(
                icon: Icons.call,
                label: 'Call Senior',
                onTap: () {
                  // TODO: fetch senior phone and launch dialer
                },
              ),
              _QuickActionButton(
                icon: Icons.medication,
                label: 'View Meds',
                onTap: () {
                  // TODO: navigate to medication screen
                },
              ),
              _QuickActionButton(
                icon: Icons.warning,
                label: 'View Alerts',
                onTap: () {
                  // TODO: navigate to alerts screen
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------
// SMALL REUSABLE WIDGETS
// ----------------------------------------------------------------------

class _DashboardCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _DashboardCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}
