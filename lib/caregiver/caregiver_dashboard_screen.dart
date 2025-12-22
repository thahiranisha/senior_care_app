import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import ' caregiver_status.dart';
import ' caregiver_theme.dart';

class CaregiverDashboardScreen extends StatelessWidget {
  const CaregiverDashboardScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Do you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Logout')),
        ],
      ),
    );

    if (ok != true) return;

    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    }
  }

  Color _statusColor(CaregiverStatus s) {
    switch (s) {
      case CaregiverStatus.pendingVerification:
        return Colors.orange;
      case CaregiverStatus.verified:
        return Colors.green;
      case CaregiverStatus.blocked:
        return Colors.red;
    }
  }

  String _statusLabel(CaregiverStatus s) {
    switch (s) {
      case CaregiverStatus.pendingVerification:
        return 'Pending verification';
      case CaregiverStatus.verified:
        return 'Verified';
      case CaregiverStatus.blocked:
        return 'Blocked';
    }
  }

  Map<String, dynamic> _completeness(Map<String, dynamic> caregiver) {
    final requiredFields = <String, dynamic>{
      'phone': caregiver['phone'],
      'city': caregiver['city'],
      'experienceYears': caregiver['experienceYears'],
      'hourlyRate': caregiver['hourlyRate'],
      'bio': caregiver['bio'],
      'languages': caregiver['languages'],
      'specialties': caregiver['specialties'],
    };

    final missing = <String>[];

    bool isEmptyValue(dynamic v) {
      if (v == null) return true;
      if (v is String) return v.trim().isEmpty;
      if (v is num) return false; // 0 is allowed, you can change if needed
      if (v is List) return v.isEmpty;
      return false;
    }

    requiredFields.forEach((k, v) {
      if (isEmptyValue(v)) missing.add(k);
    });

    final total = requiredFields.length;
    final filled = total - missing.length;

    return {
      'total': total,
      'filled': filled,
      'missing': missing,
      'progress': total == 0 ? 0.0 : (filled / total),
    };
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    final uid = user.uid;

    final userDocStream =
    FirebaseFirestore.instance.collection('users').doc(uid).snapshots();

    return Scaffold(
      backgroundColor: CaregiverTheme.background,
      appBar: AppBar(
        backgroundColor: CaregiverTheme.primary,
        foregroundColor: Colors.white,
        title: const Text('Caregiver Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: userDocStream,
        builder: (context, userSnap) {
          if (userSnap.hasError) return Center(child: Text('Error: ${userSnap.error}'));
          if (!userSnap.hasData) return const Center(child: CircularProgressIndicator());

          final userData = userSnap.data!.data() ?? {};
          final role = (userData['role'] as String?) ?? '';
          if (role != 'caregiver') {
            return const Center(child: Text('Access denied (caregiver only).'));
          }

          final caregiversDocStream =
          FirebaseFirestore.instance.collection('caregivers').doc(uid).snapshots();

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: caregiversDocStream,
            builder: (context, careSnap) {
              if (careSnap.hasError) return Center(child: Text('Error: ${careSnap.error}'));
              if (!careSnap.hasData) return const Center(child: CircularProgressIndicator());

              final caregiver = careSnap.data!.data() ?? {};
              final fullName = (caregiver['fullName'] as String?) ??
                  (userData['fullName'] as String?) ??
                  'Caregiver';

              final status = caregiverStatusFromDoc(caregiver);
              final isVerified = caregiverIsVerified(status);

              final isActive = (caregiver['isActive'] as bool?) ?? false;
              final statusReason = (caregiver['statusReason'] as String?) ?? '';

              final comp = _completeness(caregiver);
              final progress = comp['progress'] as double;
              final missing = (comp['missing'] as List).cast<String>();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello, $fullName',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Chip(
                                label: Text(_statusLabel(status)),
                                backgroundColor: _statusColor(status).withOpacity(0.15),
                                labelStyle: TextStyle(
                                  color: _statusColor(status),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 10),
                              if (status == CaregiverStatus.blocked && statusReason.isNotEmpty)
                                Expanded(
                                  child: Text(
                                    statusReason,
                                    style: const TextStyle(color: Colors.red),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text('Profile completeness: ${(progress * 100).round()}%'),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: LinearProgressIndicator(value: progress, minHeight: 10),
                          ),
                          const SizedBox(height: 10),
                          if (missing.isNotEmpty) ...[
                            const Text('Missing fields:', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: missing
                                  .map((m) => Chip(
                                label: Text(m),
                                backgroundColor: Colors.grey.shade200,
                              ))
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('Active (visible to guardians)'),
                          subtitle: Text(
                            isVerified
                                ? 'Turn on to appear in caregiver search'
                                : 'You can activate only after verification',
                          ),
                          value: isActive,
                          onChanged: !isVerified
                              ? null
                              : (v) async {
                            await FirebaseFirestore.instance
                                .collection('caregivers')
                                .doc(uid)
                                .set(
                              {
                                'isActive': v,
                                'updatedAt': FieldValue.serverTimestamp(),
                              },
                              SetOptions(merge: true),
                            );
                          },
                        ),
                        const Divider(height: 0),
                        ListTile(
                          leading: const Icon(Icons.edit),
                          title: const Text('Edit profile'),
                          subtitle: const Text('Update city, rates, experience, skills'),
                          onTap: () => Navigator.pushNamed(context, '/caregiverProfileEdit'),
                        ),
                        const Divider(height: 0),
                        ListTile(
                          leading: const Icon(Icons.badge),
                          title: const Text('Verification documents'),
                          subtitle: const Text('Upload NIC and certificates'),
                          onTap: () => Navigator.pushNamed(context, '/caregiverDocuments'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
