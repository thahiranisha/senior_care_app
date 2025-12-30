import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'guardian_chat_screen.dart';

class GuardianBookingsScreen extends StatefulWidget {
  const GuardianBookingsScreen({super.key});

  @override
  State<GuardianBookingsScreen> createState() => _GuardianBookingsScreenState();
}

class _GuardianBookingsScreenState extends State<GuardianBookingsScreen> {
  String? _uid;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _stream;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _uid = user.uid;
      _stream = FirebaseFirestore.instance
          .collection('care_requests')
          .where('guardianId', isEqualTo: _uid)
          .orderBy('startDate', descending: false)
          .snapshots();
    }
  }

  bool _isUpcoming(Map<String, dynamic> r) {
    final status = (r['status'] as String?) ?? '';
    if (status != 'ACCEPTED' && status != 'IN_PROGRESS') return false;
    final ts = r['startDate'];
    if (ts is! Timestamp) return false;
    return ts.toDate().isAfter(DateTime.now());
  }

  bool _isHistory(Map<String, dynamic> r) {
    final status = (r['status'] as String?) ?? '';
    if (status == 'COMPLETED' || status == 'CANCELLED' || status == 'REJECTED') return true;
    // accepted/in_progress but already started -> treat as history
    final ts = r['startDate'];
    if (ts is! Timestamp) return false;
    return ts.toDate().isBefore(DateTime.now());
  }

  bool _isPending(Map<String, dynamic> r) {
    final status = (r['status'] as String?) ?? '';
    return status == 'PENDING';
  }

  String _fmtDate(dynamic ts) {
    if (ts is! Timestamp) return '-';
    final d = ts.toDate();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}  ${two(d.hour)}:${two(d.minute)}';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'PENDING':
        return Colors.orange;
      case 'ACCEPTED':
        return Colors.green;
      case 'IN_PROGRESS':
        return Colors.blue;
      case 'COMPLETED':
        return Colors.grey;
      case 'CANCELLED':
        return Colors.red;
      case 'REJECTED':
        return Colors.deepOrange;
      default:
        return Colors.blueGrey;
    }
  }

  bool _chatAllowed(String status) {
    // Your rules currently allow only ACCEPTED/COMPLETED.
    // If you update rules to include IN_PROGRESS, add it here too.
    return status == 'ACCEPTED' || status == 'COMPLETED' || status == 'IN_PROGRESS';
  }

  Widget _requestCard(String requestId, Map<String, dynamic> r) {
    final status = (r['status'] as String?) ?? 'UNKNOWN';
    final caregiverName = (r['caregiverName'] as String?) ?? 'Caregiver';
    final patientName = (r['patientName'] as String?) ?? 'Patient';
    final city = (r['city'] as String?) ?? '';
    final start = _fmtDate(r['startDate']);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    caregiverName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(color: _statusColor(status), fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('Patient: $patientName'),
            const SizedBox(height: 6),
            Text('Start: $start'),
            if (city.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('City: $city'),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.info_outline),
                    label: const Text('Details'),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Request details'),
                          content: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Caregiver: $caregiverName'),
                                const SizedBox(height: 6),
                                Text('Patient: $patientName'),
                                const SizedBox(height: 6),
                                Text('Status: $status'),
                                const SizedBox(height: 6),
                                Text('Start: $start'),
                                const SizedBox(height: 6),
                                Text('Duration: ${r['durationHours'] ?? '-'} hours'),
                                const SizedBox(height: 6),
                                Text('Frequency: ${r['frequency'] ?? '-'}'),
                                const SizedBox(height: 6),
                                Text('City: ${r['city'] ?? '-'}'),
                                const SizedBox(height: 6),
                                Text('Address: ${r['address'] ?? '-'}'),
                                const SizedBox(height: 6),
                                Text('Notes: ${(r['notes'] as String?) ?? '-'}'),
                                if ((r['statusReason'] as String?)?.trim().isNotEmpty ?? false) ...[
                                  const SizedBox(height: 6),
                                  Text('Reason: ${(r['statusReason'] as String?) ?? ''}'),
                                ],
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Chat'),
                    onPressed: _chatAllowed(status)
                        ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GuardianChatScreen(requestId: requestId),
                        ),
                      );
                    }
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _listFor(List<Map<String, dynamic>> items, {required String emptyText}) {
    if (items.isEmpty) return Center(child: Text(emptyText));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final r = items[i];
        final id = r['id'] as String;
        return _requestCard(id, r);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null || _stream == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Bookings'),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pending'),
              Tab(text: 'Upcoming'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _stream,
          builder: (context, snap) {
            if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());

            final items = snap.data!.docs.map((d) => {'id': d.id, ...d.data()}).toList();

            final pending = items.where(_isPending).toList();
            final upcoming = items.where(_isUpcoming).toList();
            final history = items.where(_isHistory).toList();

            // History: latest first
            history.sort((a, b) {
              final at = a['startDate'];
              final bt = b['startDate'];
              final ad = at is Timestamp ? at.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
              final bd = bt is Timestamp ? bt.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
              return bd.compareTo(ad);
            });

            return TabBarView(
              children: [
                _listFor(pending, emptyText: 'No pending requests.'),
                _listFor(upcoming, emptyText: 'No upcoming bookings.'),
                _listFor(history, emptyText: 'No history yet.'),
              ],
            );
          },
        ),
      ),
    );
  }
}
