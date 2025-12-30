import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class GuardianRequestsScreen extends StatefulWidget {
  const GuardianRequestsScreen({super.key});

  @override
  State<GuardianRequestsScreen> createState() => _GuardianRequestsScreenState();
}

class _GuardianRequestsScreenState extends State<GuardianRequestsScreen> {
  User? _user;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _stream;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    if (_user != null) {
      _stream = FirebaseFirestore.instance
          .collection('care_requests')
          .where('guardianId', isEqualTo: _user!.uid)
          .orderBy('createdAt', descending: true)
          .snapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null || _stream == null) {
      return const Scaffold(body: Center(child: Text('Please login.')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Care Requests')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No requests yet.'));

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final d = docs[i];
              final m = d.data();

              final caregiverName = (m['caregiverName'] as String?) ?? 'Caregiver';
              final status = (m['status'] as String?) ?? 'PENDING';
              final patient = (m['patientName'] as String?) ?? '-';
              final patientAge = m['patientAge'];
              final patientGender = (m['patientGender'] as String?)?.trim();
              final freq = (m['frequency'] as String?) ?? '-';
              final duration = m['durationHours'] ?? '-';

              final ts = m['startDate'];
              final start = (ts is Timestamp) ? ts.toDate() : null;
              final startText = start == null
                  ? '-'
                  : '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')} '
                      '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(caregiverName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(
                        'Patient: $patient'
                        '${(patientAge != null || (patientGender?.isNotEmpty ?? false)) ? ' (' : ''}'
                        '${patientAge != null ? 'Age: $patientAge' : ''}'
                        '${(patientAge != null && (patientGender?.isNotEmpty ?? false)) ? ', ' : ''}'
                        '${(patientGender?.isNotEmpty ?? false) ? patientGender : ''}'
                        '${(patientAge != null || (patientGender?.isNotEmpty ?? false)) ? ')' : ''}',
                      ),
                      Text('Start: $startText'),
                      Text('Duration: $duration hours   |   Frequency: $freq'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Chip(label: Text(status)),
                          const Spacer(),
                          if (status == 'PENDING')
                            OutlinedButton(
                              onPressed: () async {
                                await d.reference.set({
                                  'status': 'CANCELLED',
                                  'updatedAt': FieldValue.serverTimestamp(),
                                }, SetOptions(merge: true));
                              },
                              child: const Text('Cancel'),
                            ),
                        ],
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
