import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// HomePage shows features based on the signed-in user's profile.
///
/// Flutter Web note:
/// Cache the Firestore stream once (instead of creating it inside build)
/// to avoid rapid re-subscriptions that can trigger Firestore JS watch
/// assertion failures on Chrome.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  User? _authUser;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _userDocStream;

  @override
  void initState() {
    super.initState();
    _authUser = FirebaseAuth.instance.currentUser;
    if (_authUser != null) {
      _userDocStream = FirebaseFirestore.instance
          .collection('users')
          .doc(_authUser!.uid)
          .snapshots();
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    // If somehow no user is logged in, send back to login
    if (_authUser == null || _userDocStream == null) {
      // schedule navigation after first frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _userDocStream,
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

        final fullName = (data['fullName'] as String?) ?? _authUser!.email ?? 'User';
        final role = (data['role'] as String?) ?? 'guardian';
        final isAdmin = (data['isAdmin'] as bool?) ?? false;

        final isGuardian = role == 'guardian';
        final isSenior = role == 'senior';
        final isCaregiver = role == 'caregiver';

        final roleLabel = role.isNotEmpty
            ? '${role[0].toUpperCase()}${role.substring(1)}'
            : 'User';

        return Scaffold(
          appBar: AppBar(
            title: const Text('Senior Care Home'),
            actions: [
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
                onPressed: _signOut,
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
                Text('Role: $roleLabel', style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 24),
                const Text(
                  'Available features',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                if (isGuardian)
                  ListTile(
                    leading: const Icon(Icons.dashboard),
                    title: const Text('Guardian dashboard'),
                    subtitle: const Text('Monitor check-ins, medications, alerts and visits'),
                    onTap: () => Navigator.pushNamed(context, '/guardianDashboard'),
                  ),

                if (isSenior)
                  ListTile(
                    leading: const Icon(Icons.dashboard_customize),
                    title: const Text('Senior dashboard'),
                    subtitle: const Text('View your schedule, reminders and caregiver bookings'),
                    onTap: () => Navigator.pushNamed(context, '/seniorDashboard'),
                  ),

                if (isGuardian || isSenior || isAdmin)
                  ListTile(
                    leading: const Icon(Icons.search),
                    title: const Text('Caregiver search by city'),
                    subtitle: const Text('Browse caregivers filtered by location and experience'),
                    onTap: () => Navigator.pushNamed(context, '/caregivers'),
                  ),

                if (isGuardian || isAdmin)
                  ListTile(
                    leading: const Icon(Icons.person_add),
                    title: const Text('Register a caregiver'),
                    subtitle: const Text(
                      'Add a new caregiver profile (address & NIC stored for admin use)',
                    ),
                    onTap: () => Navigator.pushNamed(context, '/register-caregiver'),
                  ),

                if (isGuardian || isSenior)
                  const ListTile(
                    leading: Icon(Icons.medication),
                    title: Text('Medication reminders'),
                    subtitle: Text('Manage or view medication schedules for the senior'),
                  ),

                if (isGuardian || isSenior)
                  const ListTile(
                    leading: Icon(Icons.sos),
                    title: Text('Emergency contacts'),
                    subtitle: Text('Store emergency contact details for quick access'),
                  ),

                if (isCaregiver)
                  ListTile(
                    leading: const Icon(Icons.assignment_ind),
                    title: const Text('My caregiver dashboard'),
                    subtitle: const Text('View status, complete profile, upload verification'),
                    onTap: () => Navigator.pushNamed(context, '/caregiverDashboard'),
                  ),

                if (isAdmin)
                  const ListTile(
                    leading: Icon(Icons.admin_panel_settings),
                    title: Text('Admin tools'),
                    subtitle: Text('Developer-only view to manage full caregiver data'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
