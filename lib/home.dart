import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();

    // In a StatelessWidget, BuildContext has no `mounted` property,
    // so we just navigate directly after sign-out.
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final authUser = FirebaseAuth.instance.currentUser;

    // If somehow no user is logged in, send back to login
    if (authUser == null) {
      Future.microtask(() {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Listen to this user's profile document in Firestore
    final userDocStream = FirebaseFirestore.instance
        .collection('users')
        .doc(authUser.uid)
        .snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userDocStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                'Error loading profile: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        final data = snapshot.data?.data() ?? {};

        final fullName =
            (data['fullName'] as String?) ?? authUser.email ?? 'User';
        final role = (data['role'] as String?) ?? 'guardian';
        final isAdmin = (data['isAdmin'] as bool?) ?? false;

        final isGuardian = role == 'guardian';
        final isSenior = role == 'senior';
        final isCaregiver = role == 'caregiver';

        // Safe role label
        final roleLabel =
        role.isNotEmpty ? '${role[0].toUpperCase()}${role.substring(1)}' : 'User';

        return Scaffold(
          appBar: AppBar(
            title: const Text('Senior Care Home'),
            actions: [
              // Show role badge
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                    role.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _signOut(context),
                icon: const Icon(Icons.logout),
                tooltip: 'Sign out',
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: ListView(
              children: [
                Text(
                  'Hello, $fullName',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Role: $roleLabel',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 24),

                const Text(
                  'Available features',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                // 👇 GUARDIAN DASHBOARD
                if (isGuardian)
                  ListTile(
                    leading: const Icon(Icons.dashboard),
                    title: const Text('Guardian dashboard'),
                    subtitle: const Text(
                        'Monitor check-ins, medications, alerts and visits'),
                    onTap: () {
                      Navigator.pushNamed(context, '/guardianDashboard');
                    },
                  ),

                // 👇 Caregiver search – guardians, seniors (and admin)
                if (isGuardian || isSenior || isAdmin)
                  ListTile(
                    leading: const Icon(Icons.search),
                    title: const Text('Caregiver search by city'),
                    subtitle: const Text(
                        'Browse caregivers filtered by location and experience'),
                    onTap: () {
                      Navigator.pushNamed(context, '/caregivers');
                    },
                  ),

                // 👇 Register caregiver – guardian & admin
                if (isGuardian || isAdmin)
                  ListTile(
                    leading: const Icon(Icons.person_add),
                    title: const Text('Register a caregiver'),
                    subtitle: const Text(
                        'Add a new caregiver profile (address & NIC stored for admin use)'),
                    onTap: () {
                      Navigator.pushNamed(context, '/register-caregiver');
                    },
                  ),

                // 👇 Medication reminders – guardian & senior
                if (isGuardian || isSenior)
                  const ListTile(
                    leading: Icon(Icons.medication),
                    title: Text('Medication reminders'),
                    subtitle: Text(
                        'Manage or view medication schedules for the senior'),
                    // TODO: navigate to medication reminders screen
                  ),

                // 👇 Emergency contacts – guardian & senior
                if (isGuardian || isSenior)
                  const ListTile(
                    leading: Icon(Icons.sos),
                    title: Text('Emergency contacts'),
                    subtitle: Text(
                        'Store emergency contact details for quick access'),
                    // TODO: navigate to emergency contacts screen
                  ),

                // 👇 Caregiver dashboard – for caregiver accounts
                if (isCaregiver)
                  const ListTile(
                    leading: Icon(Icons.assignment_ind),
                    title: Text('My caregiver profile'),
                    subtitle: Text(
                        'View or update your caregiver details shown to families'),
                    // TODO: navigate to caregiver self-profile screen
                  ),

                // 👇 Hidden admin tools – only for you (set isAdmin: true in Firestore)
                if (isAdmin)
                  const ListTile(
                    leading: Icon(Icons.admin_panel_settings),
                    title: Text('Admin tools'),
                    subtitle: Text(
                        'Developer-only view to manage full caregiver data'),
                    // TODO: navigate to admin management screen
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
