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

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _alertsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _checkinStream;

  @override
  void initState() {
    super.initState();
    final db = FirebaseFirestore.instance;
    final seniorId = widget.seniorId;

    // latest alert (any type)
    _alertsStream = db
        .collection('alerts')
        .where('seniorId', isEqualTo: seniorId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots();

    // latest check-in (from activity_logs_today)
    _checkinStream = db
        .collection('activity_logs_today')
        .where('seniorId', isEqualTo: seniorId)
        .where('type', isEqualTo: 'CHECKIN')
        .orderBy('time', descending: true)
        .limit(1)
        .snapshots();
  }

  void _openNamed(BuildContext context, String route) {
    Navigator.pushNamed(context, route, arguments: {'seniorId': widget.seniorId});
  }

  String _fmtTs(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}  ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Check-in status (under selected senior)
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _checkinStream,
          builder: (context, snap) {
            if (!snap.hasData || snap.data!.docs.isEmpty) {
              return Card(
                elevation: 1.2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: const ListTile(
                  leading: Icon(Icons.favorite_border, color: Colors.orange),
                  title: Text('Check-in status', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('No check-ins yet'),
                ),
              );
            }

            final data = snap.data!.docs.first.data();
            final desc = (data['description'] as String?) ?? 'Checked in';
            final time = data['time'] as Timestamp?;

            return Card(
              elevation: 1.2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: ListTile(
                leading: const Icon(Icons.favorite, color: Colors.orange),
                title: const Text('Check-in status', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('$desc\n${_fmtTs(time)}'),
              ),
            );
          },
        ),

        const SizedBox(height: 12),

        // Latest alert card (optional)
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
              elevation: 1.2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              color: Colors.blueGrey.shade50,
              child: ListTile(
                leading: const Icon(Icons.notifications_active, color: Colors.blueGrey),
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
