import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'caregiver_chat_screen.dart';
import 'caregiver_theme.dart';

class CaregiverBookingsScreen extends StatefulWidget {
  const CaregiverBookingsScreen({super.key});

  @override
  State<CaregiverBookingsScreen> createState() => _CaregiverBookingsScreenState();
}

class _CaregiverBookingsScreenState extends State<CaregiverBookingsScreen> {
  String? _uid;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _reqStream;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _uid = user.uid;
      _reqStream = FirebaseFirestore.instance
          .collection('care_requests')
          .where('caregiverId', isEqualTo: _uid)
          .orderBy('startDate')
          .snapshots();
    }
  }

  bool _isBookingStatus(String? status) {
    return status == 'ACCEPTED' || status == 'IN_PROGRESS' || status == 'COMPLETED';
  }

  bool _isUpcoming(Map<String, dynamic> r) {
    final status = (r['status'] as String?) ?? '';
    if (status != 'ACCEPTED' && status != 'IN_PROGRESS') return false;
    final ts = r['startDate'];
    if (ts is! Timestamp) return false;
    return ts.toDate().isAfter(DateTime.now());
  }

  String _fmtDate(dynamic ts) {
    if (ts is! Timestamp) return '-';
    final d = ts.toDate();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}  ${two(d.hour)}:${two(d.minute)}';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'ACCEPTED':
        return Colors.green;
      case 'IN_PROGRESS':
        return Colors.blue;
      case 'COMPLETED':
        return Colors.grey;
      case 'CANCELLED':
        return Colors.red;
      case 'REJECTED':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  Future<void> _launchTel(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open dialer')),
      );
    }
  }

  Future<void> _launchSms(String phone) async {
    final uri = Uri(scheme: 'sms', path: phone);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open SMS app')),
      );
    }
  }

  void _openContactSheet({
    required String requestId,
    required String guardianName,
    required String? guardianPhone,
  }) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(guardianName),
                  subtitle: Text(guardianPhone ?? 'Phone not available'),
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.chat_bubble_outline),
                  title: const Text('Message in app'),
                  subtitle: const Text('Chat with this guardian about the booking'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CaregiverChatScreen(requestId: requestId),
                      ),
                    );
                  },
                ),
                if (guardianPhone != null) ...[
                  ListTile(
                    leading: const Icon(Icons.copy),
                    title: const Text('Copy phone number'),
                    onTap: () {
                      Navigator.pop(context);
                      _copyToClipboard(guardianPhone);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.call),
                    title: const Text('Call'),
                    onTap: () {
                      Navigator.pop(context);
                      _launchTel(guardianPhone);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.sms_outlined),
                    title: const Text('SMS'),
                    onTap: () {
                      Navigator.pop(context);
                      _launchSms(guardianPhone);
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _bookingCard(String requestId, Map<String, dynamic> r) {
    final status = (r['status'] as String?) ?? 'UNKNOWN';

    final patientName = (r['patientName'] as String?) ?? 'Patient';
    final patientAge = r['patientAge'];
    final patientGender = (r['patientGender'] as String?) ?? '';
    final city = (r['city'] as String?) ?? '';
    final start = _fmtDate(r['startDate']);

    // ✅ READ guardian info DIRECTLY from care_requests (no extra reads, no permissions issue)
    final guardianName = ((r['guardianName'] as String?) ?? 'Guardian').trim();
    final rawPhone = (r['guardianPhone'] as String?)?.trim() ?? '';
    final guardianPhone = rawPhone.isEmpty ? null : rawPhone;

    String patientLine() {
      final ageStr = patientAge is num ? patientAge.toString() : '';
      final bits = <String>[];
      if (ageStr.isNotEmpty) bits.add('Age: $ageStr');
      if (patientGender.trim().isNotEmpty) bits.add(patientGender.trim());
      return bits.isEmpty ? patientName : '$patientName (${bits.join(', ')})';
    }

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
                    patientLine(),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
            Text('Start: $start'),
            if (city.isNotEmpty) Text('City: $city'),
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
                          title: const Text('Booking details'),
                          content: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Patient: ${patientLine()}'),
                                const SizedBox(height: 6),
                                Text('Start: $start'),
                                const SizedBox(height: 6),
                                Text('Duration (hours): ${r['durationHours'] ?? '-'}'),
                                const SizedBox(height: 6),
                                Text('Frequency: ${r['frequency'] ?? '-'}'),
                                const SizedBox(height: 6),
                                Text('City: ${r['city'] ?? '-'}'),
                                const SizedBox(height: 6),
                                Text('Address: ${r['address'] ?? '-'}'),
                                const SizedBox(height: 6),
                                Text('Notes: ${(r['notes'] as String?) ?? '-'}'),
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
                    icon: const Icon(Icons.contact_phone),
                    label: const Text('Contact'),
                    onPressed: () {
                      _openContactSheet(
                        requestId: requestId,
                        guardianName: guardianName.isEmpty ? 'Guardian' : guardianName,
                        guardianPhone: guardianPhone,
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null || _reqStream == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: CaregiverTheme.background,
        appBar: AppBar(
          backgroundColor: CaregiverTheme.primary,
          foregroundColor: Colors.white,
          title: const Text('Bookings'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Upcoming'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _reqStream,
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(child: Text('Error: ${snap.error}'));
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snap.data!.docs;
            final bookings = docs
                .map((d) => {'id': d.id, ...d.data()})
                .where((m) => _isBookingStatus(m['status'] as String?))
                .toList();

            final upcoming = bookings.where((m) => _isUpcoming(m)).toList();
            final history = bookings.where((m) => !_isUpcoming(m)).toList();

            history.sort((a, b) {
              final at = a['startDate'];
              final bt = b['startDate'];
              final ad = at is Timestamp ? at.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
              final bd = bt is Timestamp ? bt.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
              return bd.compareTo(ad);
            });

            Widget listFor(List<Map<String, dynamic>> items, {required String emptyText}) {
              if (items.isEmpty) return Center(child: Text(emptyText));
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final r = items[i];
                  final id = r['id'] as String;
                  return _bookingCard(id, r);
                },
              );
            }

            return TabBarView(
              children: [
                listFor(upcoming, emptyText: 'No upcoming bookings yet.'),
                listFor(history, emptyText: 'No history yet.'),
              ],
            );
          },
        ),
      ),
    );
  }
}
