import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: userRef.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final data = snap.data!.data() ?? {};
          final isAdmin = data['isAdmin'] == true;
          if (!isAdmin) {
            return const Center(child: Text('Access denied (admin only).'));
          }

          final pendingQuery = FirebaseFirestore.instance
              .collection('caregivers')
              .where('status', whereIn: ['PENDING_VERIFICATION', 'PENDING']);

          final verifiedQuery = FirebaseFirestore.instance
              .collection('caregivers')
              .where('status', isEqualTo: 'VERIFIED');

          final blockedQuery = FirebaseFirestore.instance
              .collection('caregivers')
              .where('status', isEqualTo: 'BLOCKED');

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: ListTile(
                  leading: const Icon(Icons.verified_user),
                  title: const Text('Verify Caregivers'),
                  subtitle: const Text('Approve / Block caregiver profiles'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pushNamed(context, '/adminVerifyCaregivers'),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _CountCard(
                      title: 'Pending',
                      query: pendingQuery,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _CountCard(
                      title: 'Verified',
                      query: verifiedQuery,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _CountCard(
                      title: 'Blocked',
                      query: blockedQuery,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: const ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('Admin Settings'),
                  subtitle: Text('Coming soon'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  final String title;
  final Query<Map<String, dynamic>> query;
  final Color color;

  const _CountCard({
    required this.title,
    required this.query,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snap) {
        final count = snap.data?.docs.length ?? 0;
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('$count', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      },
    );
  }
}
