import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'widgets/action_pill.dart';
import 'widgets/activity_row.dart';
import 'widgets/dashboard_tile.dart';

// ✅ This screen must exist (the CRUD screen we added earlier)
import 'guardian_medications_screen.dart';

class GuardianDashboardContent extends StatelessWidget {
  const GuardianDashboardContent({super.key, required this.seniorId});

  final String seniorId;

  static const Color themeColor = Colors.teal;

  void _openNamed(BuildContext context, String route) {
    Navigator.pushNamed(context, route, arguments: {'seniorId': seniorId});
  }

  void _openMedications(BuildContext context, String seniorName) {
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

  @override
  Widget build(BuildContext context) {
    final seniorRef =
    FirebaseFirestore.instance.collection('seniors').doc(seniorId);

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

    // ✅ Get senior name once here
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: seniorRef.snapshots(),
      builder: (context, seniorSnap) {
        final seniorData = seniorSnap.data?.data() ?? {};
        final seniorName = (seniorData['fullName'] as String?) ??
            (seniorData['name'] as String?) ??
            'Senior';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -------------------------
            // Latest alert
            // -------------------------
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: alertsQuery.snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const SizedBox.shrink();
                }

                final alert = snapshot.data!.docs.first.data();
                final type = (alert['type'] as String?) ?? 'ALERT';
                final message = (alert['message'] as String?) ?? 'New alert';

                return Card(
                  elevation: 1.5,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                  color: Colors.red.shade50,
                  child: ListTile(
                    leading: const Icon(Icons.warning_amber_rounded,
                        color: Colors.redAccent),
                    title: Text(
                      'Latest alert: $type',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(message),
                    onTap: () => _openNamed(context, '/guardianAlerts'),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            const Text('Summary',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            // -------------------------
            // Summary tiles
            // -------------------------
            LayoutBuilder(
              builder: (context, c) {
                final isWide = c.maxWidth > 520;
                return GridView.count(
                  crossAxisCount: isWide ? 3 : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: isWide ? 2.35 : 1.95,
                  children: [
                    // Check-in tile
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: statusRef.snapshots(),
                      builder: (context, snapshot) {
                        String subtitle = 'No data';
                        if (snapshot.hasData && snapshot.data!.data() != null) {
                          final d = snapshot.data!.data()!;
                          final lastCheckIn = d['lastCheckIn'] as Timestamp?;
                          final lastMood = d['lastMood'] as String?;
                          if (lastCheckIn != null) {
                            final t =
                            TimeOfDay.fromDateTime(lastCheckIn.toDate());
                            subtitle =
                            'Last: ${t.format(context)}\nMood: ${lastMood ?? '-'}';
                          }
                        }

                        return DashboardTile(
                          title: 'Check-in',
                          subtitle: subtitle,
                          icon: Icons.favorite_outline,
                          themeColor: themeColor,
                          onTap: () => _openNamed(context, '/guardianCheckins'),
                        );
                      },
                    ),

                    // Medications tile -> open CRUD screen
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: medStatsRef.snapshots(),
                      builder: (context, snapshot) {
                        String subtitle = 'No meds today';
                        if (snapshot.hasData && snapshot.data!.data() != null) {
                          final d = snapshot.data!.data()!;
                          final taken = d['taken'] ?? 0;
                          final total = d['total'] ?? 0;
                          subtitle = '$taken / $total taken';
                        }

                        return DashboardTile(
                          title: 'Medications',
                          subtitle: subtitle,
                          icon: Icons.medication_outlined,
                          themeColor: themeColor,
                          onTap: () => _openMedications(context, seniorName),
                        );
                      },
                    ),

                    // Next visit tile
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: appointmentsQuery.snapshots(),
                      builder: (context, snapshot) {
                        String subtitle = 'None';
                        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                          final appt = snapshot.data!.docs.first.data();
                          final title =
                              (appt['title'] as String?) ?? 'Appointment';
                          final time = (appt['time'] as Timestamp).toDate();
                          subtitle =
                          '$title\n${time.day}/${time.month} • ${TimeOfDay.fromDateTime(time).format(context)}';
                        }

                        return DashboardTile(
                          title: 'Next Visit',
                          subtitle: subtitle,
                          icon: Icons.event,
                          themeColor: themeColor,
                          onTap: () => _openNamed(context, '/guardianAppointments'),
                        );
                      },
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 16),

            const Text("Today's Activity",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            Card(
              elevation: 1.5,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: activityQuery.snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(14),
                      child: Text('No activity logged yet today.'),
                    );
                  }

                  final docs = snapshot.data!.docs;

                  return Column(
                    children: [
                      for (int i = 0; i < docs.length; i++) ...[
                        ActivityRow(data: docs[i].data()),
                        if (i != docs.length - 1) const Divider(height: 1),
                      ],
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            const Text('Quick Actions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                // Alerts
                ActionPill(
                  icon: Icons.warning,
                  label: 'Alerts',
                  themeColor: themeColor,
                  onTap: () => _openNamed(context, '/guardianAlerts'),
                ),

                // Medications (CRUD)
                ActionPill(
                  icon: Icons.medication,
                  label: 'Medications',
                  themeColor: themeColor,
                  onTap: () => _openMedications(context, seniorName),
                ),

                // Reminders (guardian adds reminders later for senior+caregiver)
                ActionPill(
                  icon: Icons.alarm,
                  label: 'Reminders',
                  themeColor: themeColor,
                  onTap: () => _openNamed(context, '/guardianReminders'),
                ),

                // Appointments
                ActionPill(
                  icon: Icons.event,
                  label: 'Appointments',
                  themeColor: themeColor,
                  onTap: () => _openNamed(context, '/guardianAppointments'),
                ),

                // Emergency contacts
                ActionPill(
                  icon: Icons.contact_phone,
                  label: 'Emergency',
                  themeColor: themeColor,
                  onTap: () => _openNamed(context, '/guardianEmergency'),
                ),

                // Caregiver search
                ActionPill(
                  icon: Icons.search,
                  label: 'Caregivers',
                  themeColor: themeColor,
                  onTap: () => _openNamed(context, '/caregivers'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
