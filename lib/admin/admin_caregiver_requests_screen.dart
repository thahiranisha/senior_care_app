import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'admin_caregiver_request_detail_screen.dart';

enum CaregiverRequestFilter { pending, verified, rejected, blocked }

class AdminCaregiverRequestsScreen extends StatelessWidget {
  final CaregiverRequestFilter filter;
  const AdminCaregiverRequestsScreen({super.key, required this.filter});

  Query<Map<String, dynamic>> _query() {
    final col = FirebaseFirestore.instance.collection('caregivers');

    switch (filter) {
      case CaregiverRequestFilter.pending:
      // ✅ supports legacy "PENDING" + new "PENDING_VERIFICATION"
        return col.where('status', whereIn: ['PENDING_VERIFICATION', 'PENDING']);
      case CaregiverRequestFilter.verified:
        return col.where('status', isEqualTo: 'VERIFIED');
      case CaregiverRequestFilter.rejected:
        return col.where('status', isEqualTo: 'REJECTED');
      case CaregiverRequestFilter.blocked:
        return col.where('status', isEqualTo: 'BLOCKED');
    }
  }

  String _title() {
    switch (filter) {
      case CaregiverRequestFilter.pending:
        return 'Pending Requests';
      case CaregiverRequestFilter.verified:
        return 'Verified Caregivers';
      case CaregiverRequestFilter.rejected:
        return 'Rejected Requests';
      case CaregiverRequestFilter.blocked:
        return 'Blocked Caregivers';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title())),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _query().snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No records'));

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data();

              final name = (data['fullName'] as String?) ?? 'Unknown';
              final email = (data['email'] as String?) ?? '';
              final status = (data['status'] as String?) ?? '';

              return ListTile(
                leading: CircleAvatar(child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'C')),
                title: Text(name),
                subtitle: Text(email.isNotEmpty ? '$email • $status' : status),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminCaregiverRequestDetailScreen(caregiverId: d.id),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
