import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_preview/device_preview.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'admin/admin_dashboard_screen.dart';
import 'admin/admin_verify_caregivers_screen.dart';
import 'caregiver/caregiver_dashboard_screen.dart';
import 'caregiver/caregiver_bookings_screen.dart';
import 'caregiver/caregiver_documents_screen.dart';
import 'caregiver/caregiver_profile_edit_screen.dart';
import 'caregiver/caregiver_requests_screen.dart';
import 'common/coming_soon_screen.dart';
import 'firebase_options.dart';
import 'guardian/caregiver_public_profile_screen.dart';
import 'guardian/caregiver_search_screen.dart';
import 'guardian/guardian_profile_edit_screen.dart';
import 'guardian/guardian_requests_screen.dart';
import 'guardian/request_care_screen.dart';
import 'guardian_dashboard.dart';
import 'home.dart';
import 'login.dart';
import 'register.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // For Flutter Web: avoid some persistence issues
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
  );

  final user = FirebaseAuth.instance.currentUser;

  runApp(
    DevicePreview(
      enabled: !kReleaseMode,
      builder: (context) => MyApp(isLoggedIn: user != null),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      useInheritedMediaQuery: true,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      debugShowCheckedModeBanner: false,
      title: 'Senior Care App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 18),
          bodyMedium: TextStyle(fontSize: 16),
        ),
      ),
      initialRoute: isLoggedIn ? '/home' : '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/home': (context) => const HomePage(),

        '/guardianDashboard': (context) => const GuardianDashboardScreen(),
        '/adminDashboard': (context) => const AdminDashboardScreen(),
        '/adminVerifyCaregivers': (context) => const AdminVerifyCaregiversScreen(),

        '/caregiverDashboard': (context) => const CaregiverDashboardScreen(),
        '/caregiverProfileEdit': (context) => const CaregiverProfileEditScreen(),
        '/caregiverDocuments': (context) => const CaregiverDocumentsScreen(),

        // Guardian: Find Caregivers
        '/caregivers': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final seniorId = (args is Map && args['seniorId'] is String)
              ? args['seniorId'] as String
              : null;
          return CaregiverSearchScreen(seniorId: seniorId);
        },

        // Guardian: placeholder features
        '/guardianAlerts': (context) => const ComingSoonScreen(title: 'Alerts'),
        '/guardianCheckins': (context) => const ComingSoonScreen(title: 'Check-ins'),
        '/guardianAppointments': (context) => const ComingSoonScreen(title: 'Appointments'),
        '/guardianReminders': (context) => const ComingSoonScreen(title: 'Reminders'),
        '/requestCare': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map;
          return RequestCareScreen(
            caregiverId: args['caregiverId'],
            caregiverName: args['caregiverName'],
            seniorId: args['seniorId'],
          );
        },
        '/guardianProfileEdit': (_) => const GuardianProfileEditScreen(),

        '/guardianRequests': (context) => const GuardianRequestsScreen(),
        '/caregiverRequests': (context) => const CaregiverRequestsScreen(),

        // Caregiver: bookings tracker (accepted requests)
        '/caregiverBookings': (context) => const CaregiverBookingsScreen(),

        // Public caregiver profile (expects: arguments = caregiverId as String)
        '/caregiverPublicProfile': (context) {
          final args = ModalRoute.of(context)!.settings.arguments;
          if (args is Map) {
            final id = (args['caregiverId'] as String?) ?? '';
            final seniorId = (args['seniorId'] as String?);
            return CaregiverPublicProfileScreen(caregiverId: id, seniorId: seniorId);
          }
          final id = args is String ? args : '';
          return CaregiverPublicProfileScreen(caregiverId: id);
        },
      },
    );
  }
}
