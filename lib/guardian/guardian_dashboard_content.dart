import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'widgets/action_pill.dart';

class GuardianDashboardContent extends StatefulWidget {
  const GuardianDashboardContent({super.key, required this.seniorId});

  final String seniorId;

  @override
  State<GuardianDashboardContent> createState() => _GuardianDashboardContentState();
}

class _GuardianDashboardContentState extends State<GuardianDashboardContent> {
  static const Color themeColor = Colors.teal;

  late Stream<QuerySnapshot<Map<String, dynamic>>> _alertsStream;

  @override
  void initState() {
    super.initState();
    _initStreams();
  }

  void _initStreams() {
    final db = FirebaseFirestore.instance;
    final seniorId = widget.seniorId;

    _alertsStream = db
        .collection('alerts')
        .where('seniorId', isEqualTo: seniorId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots();
  }

  void _openNamed(BuildContext context, String route) {
    Navigator.pushNamed(context, route, arguments: {'seniorId': widget.seniorId});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Latest alert (keep)
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _alertsStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const SizedBox.shrink();
            }

            final alert = snapshot.data!.docs.first.data();
            final type = (alert['type'] as String?) ?? 'ALERT';
            final message = (alert['message'] as String?) ?? 'New alert';

            return Card(
              elevation: 1.5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              color: Colors.red.shade50,
              child: ListTile(
                leading: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                title: Text('Latest alert: $type', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(message),
                onTap: () => _openNamed(context, '/guardianAlerts'),
              ),
            );
          },
        ),

        const SizedBox(height: 16),
        const Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),

        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ActionPill(
              icon: Icons.warning,
              label: 'Alerts',
              themeColor: themeColor,
              onTap: () => _openNamed(context, '/guardianAlerts'),
            ),
            ActionPill(
              icon: Icons.alarm,
              label: 'Reminders',
              themeColor: themeColor,
              onTap: () => _openNamed(context, '/guardianReminders'),
            ),
            ActionPill(
              icon: Icons.event,
              label: 'Appointments',
              themeColor: themeColor,
              onTap: () => _openNamed(context, '/guardianAppointments'),
            ),
            ActionPill(
              icon: Icons.contact_phone,
              label: 'Emergency',
              themeColor: themeColor,
              onTap: () => _openNamed(context, '/guardianEmergency'),
            ),
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
  }
}
