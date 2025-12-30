import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CaregiverRequestsScreen extends StatefulWidget {
  const CaregiverRequestsScreen({super.key});

  @override
  State<CaregiverRequestsScreen> createState() => _CaregiverRequestsScreenState();
}

class _CaregiverRequestsScreenState extends State<CaregiverRequestsScreen> {
  Stream<QuerySnapshot<Map<String, dynamic>>>? _stream;
  User? _user;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    if (_user != null) {
      _stream = FirebaseFirestore.instance
          .collection('care_requests')
          .where('caregiverId', isEqualTo: _user!.uid)
          .orderBy('createdAt', descending: true)
          .snapshots();
    }
  }

  Future<String?> _askReason(BuildContext context, String title) async {
    final c = TextEditingController();
    final res = await showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Reason (required)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('Submit')),
        ],
      ),
    );
    c.dispose();
    return res;
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null || _stream == null) {
      return const Scaffold(body: Center(child: Text('Please login.')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Care Requests')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No requests.'));

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final d = docs[i];
              final m = d.data();

              final status = (m['status'] as String?) ?? 'PENDING';
              final patient = (m['patientName'] as String?) ?? '-';
              final city = (m['city'] as String?) ?? '';
              final address = (m['address'] as String?) ?? '';
              final notes = (m['notes'] as String?) ?? '';
              final freq = (m['frequency'] as String?) ?? '-';
              final duration = m['durationHours'] ?? '-';

              final ts = m['startDate'];
              final start = (ts is Timestamp) ? ts.toDate() : null;
              final startText = start == null
                  ? '-'
                  : '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')} '
                      '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';

              Future<void> accept() async {
                await d.reference.set({
                  'status': 'ACCEPTED',
                  'statusReason': '',
                  'updatedAt': FieldValue.serverTimestamp(),
                  'acceptedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
              }

              Future<void> reject() async {
                final r = await _askReason(context, 'Reject Request');
                if (r == null || r.isEmpty) return;

                await d.reference.set({
                  'status': 'REJECTED',
                  'statusReason': r,
                  'updatedAt': FieldValue.serverTimestamp(),
                  'rejectedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
              }

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Patient: $patient', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text('Start: $startText'),
                      Text('Duration: $duration hours   |   Frequency: $freq'),
                      if (city.isNotEmpty) Text('City: $city'),
                      if (address.isNotEmpty) Text('Address: $address'),
                      if (notes.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text('Notes: $notes'),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Chip(label: Text(status)),
                          const Spacer(),
                          if (status == 'PENDING') ...[
                            ElevatedButton(onPressed: accept, child: const Text('Accept')),
                            const SizedBox(width: 10),
                            OutlinedButton(onPressed: reject, child: const Text('Reject')),
                          ],
                        ],
                      ),
                      if ((m['statusReason'] as String?)?.trim().isNotEmpty == true)
                        Text('Reason: ${m['statusReason']}', style: const TextStyle(color: Colors.red)),
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
