import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class GuardianEmergencyScreen extends StatelessWidget {
  const GuardianEmergencyScreen({super.key, required this.seniorId});

  final String seniorId;

  Stream<QuerySnapshot<Map<String, dynamic>>> _sosStream() {
    return FirebaseFirestore.instance
        .collection('alerts')
        .where('seniorId', isEqualTo: seniorId)
        .where('type', isEqualTo: 'SOS')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _checkinStream() {
    return FirebaseFirestore.instance
        .collection('activity_logs_today')
        .where('seniorId', isEqualTo: seniorId)
        .where('type', isEqualTo: 'CHECKIN')
        .orderBy('time', descending: true)
        .limit(1)
        .snapshots();
  }

  String _fmtTs(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}  ${two(d.hour)}:${two(d.minute)}';
  }

  Widget _card({
    required Color bg,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String timeText,
  }) {
    return Card(
      elevation: 1.2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: bg,
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(subtitle),
            const SizedBox(height: 6),
            Text(timeText, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _sosStream(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _card(
                  bg: Colors.red.shade50,
                  icon: Icons.sos_rounded,
                  iconColor: Colors.redAccent,
                  title: 'SOS',
                  subtitle: 'No SOS alerts',
                  timeText: '',
                );
              }

              final data = snapshot.data!.docs.first.data();
              final msg = (data['message'] as String?) ?? 'SOS alert';
              final ts = data['createdAt'] as Timestamp?;

              return _card(
                bg: Colors.red.shade50,
                icon: Icons.sos_rounded,
                iconColor: Colors.redAccent,
                title: 'SOS',
                subtitle: msg,
                timeText: _fmtTs(ts),
              );
            },
          ),

          const SizedBox(height: 10),

          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _checkinStream(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _card(
                  bg: Colors.orange.shade50,
                  icon: Icons.favorite_rounded,
                  iconColor: Colors.orange,
                  title: 'Check-in',
                  subtitle: 'No check-ins',
                  timeText: '',
                );
              }

              final data = snapshot.data!.docs.first.data();
              final desc = (data['description'] as String?) ?? 'Checked in';
              final ts = data['time'] as Timestamp?;

              return _card(
                bg: Colors.orange.shade50,
                icon: Icons.favorite_rounded,
                iconColor: Colors.orange,
                title: 'Check-in',
                subtitle: desc,
                timeText: _fmtTs(ts),
              );
            },
          ),
        ],
      ),
    );
  }
}
