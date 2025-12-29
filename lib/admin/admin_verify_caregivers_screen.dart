import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_caregiver_request_detail_screen.dart';

class AdminVerifyCaregiversScreen extends StatefulWidget {
  const AdminVerifyCaregiversScreen({super.key});

  @override
  State<AdminVerifyCaregiversScreen> createState() => _AdminVerifyCaregiversScreenState();
}

class _AdminVerifyCaregiversScreenState extends State<AdminVerifyCaregiversScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _approve(String caregiverId) async {
    final adminId = FirebaseAuth.instance.currentUser?.uid;
    if (adminId == null) return;

    await FirebaseFirestore.instance.collection('caregivers').doc(caregiverId).set({
      'status': 'VERIFIED',
      'isVerified': true, // backward compatibility
      'statusReason': '',
      'isActive': false, // keep off until caregiver enables it
      'verifiedAt': FieldValue.serverTimestamp(),
      'verifiedBy': adminId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _reject(String caregiverId) async {
    final adminId = FirebaseAuth.instance.currentUser?.uid;
    if (adminId == null) return;

    final reason = await _askReasonDialog(title: 'Reject caregiver', hint: 'Reason (required)');
    if (reason == null || reason.trim().isEmpty) return;

    await FirebaseFirestore.instance.collection('caregivers').doc(caregiverId).set({
      'status': 'REJECTED',
      'isVerified': false,
      'isActive': false,
      'statusReason': reason.trim(),
      'rejectedAt': FieldValue.serverTimestamp(),
      'rejectedBy': adminId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _block(String caregiverId) async {
    final adminId = FirebaseAuth.instance.currentUser?.uid;
    if (adminId == null) return;

    final reason = await _askReasonDialog(title: 'Block caregiver', hint: 'Reason (required)');
    if (reason == null || reason.trim().isEmpty) return;

    await FirebaseFirestore.instance.collection('caregivers').doc(caregiverId).set({
      'status': 'BLOCKED',
      'isVerified': false,
      'isActive': false,
      'statusReason': reason.trim(),
      'blockedAt': FieldValue.serverTimestamp(),
      'blockedBy': adminId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _unblock(String caregiverId) async {
    final adminId = FirebaseAuth.instance.currentUser?.uid;
    if (adminId == null) return;

    await FirebaseFirestore.instance.collection('caregivers').doc(caregiverId).set({
      'status': 'PENDING_VERIFICATION',
      'isVerified': false,
      'isActive': false,
      'statusReason': '',
      'unblockedAt': FieldValue.serverTimestamp(),
      'unblockedBy': adminId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String?> _askReasonDialog({required String title, required String hint}) async {
    final controller = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hint),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final pendingQuery = FirebaseFirestore.instance
        .collection('caregivers')
        .where('status', isEqualTo: 'PENDING_VERIFICATION');

    final verifiedQuery = FirebaseFirestore.instance
        .collection('caregivers')
        .where('status', isEqualTo: 'VERIFIED');

    final blockedQuery = FirebaseFirestore.instance
        .collection('caregivers')
        .where('status', isEqualTo: 'BLOCKED');

    final rejectedQuery = FirebaseFirestore.instance
        .collection('caregivers')
        .where('status', isEqualTo: 'REJECTED');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Caregiver Verification'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Verified'),
            Tab(text: 'Rejected'),
            Tab(text: 'Blocked'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _CaregiverList(
            query: pendingQuery,
            trailingBuilder: (id, data) => Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () => _approve(id),
                  child: const Text('Approve'),
                ),
                OutlinedButton(onPressed: () => _reject(id), child: const Text('Reject')),
                OutlinedButton(onPressed: () => _block(id), child: const Text('Block')),
              ],
            ),
          ),
          _CaregiverList(
            query: verifiedQuery,
            trailingBuilder: (id, data) => OutlinedButton(
              onPressed: () => _block(id),
              child: const Text('Block'),
            ),
          ),
          _CaregiverList(
            query: rejectedQuery,
            trailingBuilder: (id, data) => Wrap(
              spacing: 8,
              children: [
                ElevatedButton(onPressed: () => _approve(id), child: const Text('Approve')),
                OutlinedButton(onPressed: () => _block(id), child: const Text('Block')),
              ],
            ),
          ),
          _CaregiverList(
            query: blockedQuery,
            trailingBuilder: (id, data) => ElevatedButton(
              onPressed: () => _unblock(id),
              child: const Text('Unblock'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CaregiverList extends StatelessWidget {
  final Query<Map<String, dynamic>> query;
  final Widget Function(String caregiverId, Map<String, dynamic> data) trailingBuilder;

  const _CaregiverList({
    required this.query,
    required this.trailingBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snap.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No records'));

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final doc = docs[i];
            final data = doc.data();

            final name = (data['fullName'] as String?) ?? 'Unknown';
            final email = (data['email'] as String?) ?? '';
            final city = (data['city'] as String?) ?? '';
            final exp = data['experienceYears'];
            final reason = (data['statusReason'] as String?) ?? '';

            return InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminCaregiverRequestDetailScreen(caregiverId: doc.id),
                  ),
                );
              },
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      if (email.isNotEmpty) Text(email),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (city.isNotEmpty) Chip(label: Text(city)),
                          const SizedBox(width: 8),
                          if (exp != null) Chip(label: Text('Exp: $exp')),
                        ],
                      ),
                      if (reason.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text('Reason: $reason', style: const TextStyle(color: Colors.red)),
                      ],
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: trailingBuilder(doc.id, data),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
