import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class GuardianAlertsScreen extends StatelessWidget {
  const GuardianAlertsScreen({super.key, required this.seniorId});

  final String seniorId;

  Stream<QuerySnapshot<Map<String, dynamic>>> _alertsStream() {
    return FirebaseFirestore.instance
        .collection('alerts')
        .where('seniorId', isEqualTo: seniorId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  String _fmtTs(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}  ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _alertsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No alerts.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final data = docs[i].data();
              final type = (data['type'] as String?) ?? 'ALERT';
              final message = (data['message'] as String?) ?? '';
              final createdAt = data['createdAt'] as Timestamp?;

              final isSos = type.toUpperCase() == 'SOS';
              final bg = isSos ? Colors.red.shade50 : Colors.orange.shade50;
              final icon = isSos ? Icons.sos_rounded : Icons.warning_amber_rounded;
              final iconColor = isSos ? Colors.redAccent : Colors.orange;

              return Card(
                elevation: 1.2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: bg,
                child: ListTile(
                  leading: Icon(icon, color: iconColor),
                  title: Text(
                    type,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(message),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        _fmtTs(createdAt),
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
