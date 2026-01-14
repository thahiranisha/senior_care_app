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
import 'senior/senior_dashboard_screen.dart';
import 'senior/senior_bookings_screen.dart';
import 'senior/senior_checkin_screen.dart';
import 'senior/senior_emergency_screen.dart';
import 'senior/senior_medications_screen.dart';
import 'senior/senior_profile_screen.dart';
import 'senior/senior_link_code_screen.dart';
import 'senior/senior_login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
        '/seniorLogin': (context) => const SeniorLoginScreen(),
        '/seniorLinkCode': (context) => const SeniorLinkCodeScreen(),
        '/seniorDashboard': (context) => const SeniorDashboardScreen(),
        '/seniorCheckin': (context) {
          final args = (ModalRoute.of(context)?.settings.arguments as Map?) ?? {};
          final seniorId = (args['seniorId'] as String?) ?? '';
          return SeniorCheckinScreen(seniorId: seniorId);
        },
        '/seniorEmergency': (context) {
          final args = (ModalRoute.of(context)?.settings.arguments as Map?) ?? {};
          return SeniorEmergencyScreen(
            seniorId: (args['seniorId'] as String?) ?? '',
            seniorName: (args['seniorName'] as String?) ?? 'Senior',
          );
        },
        '/seniorMedications': (context) {
          final args = (ModalRoute.of(context)?.settings.arguments as Map?) ?? {};
          return SeniorMedicationsScreen(
            seniorId: (args['seniorId'] as String?) ?? '',
            seniorName: (args['seniorName'] as String?) ?? 'Senior',
          );
        },
        '/seniorBookings': (context) {
          final args = (ModalRoute.of(context)?.settings.arguments as Map?) ?? {};
          return SeniorBookingsScreen(
            guardianId: (args['guardianId'] as String?) ?? '',
            seniorName: (args['seniorName'] as String?) ?? '',
          );
        },
        '/seniorProfile': (context) {
          final args = (ModalRoute.of(context)?.settings.arguments as Map?) ?? {};
          return SeniorProfileScreen(seniorId: (args['seniorId'] as String?) ?? '');
        },

        '/guardianDashboard': (context) => const GuardianDashboardScreen(),
        '/adminDashboard': (context) => const AdminDashboardScreen(),
        '/adminVerifyCaregivers': (context) => const AdminVerifyCaregiversScreen(),

        '/caregiverDashboard': (context) => const CaregiverDashboardScreen(),
        '/caregiverProfileEdit': (context) => const CaregiverProfileEditScreen(),
        '/caregiverDocuments': (context) => const CaregiverDocumentsScreen(),
        '/caregivers': (context) {
          final args = ModalRoute.of(context)!.settings.arguments;
          final seniorId = (args is Map) ? (args['seniorId'] as String?) : null;
          return CaregiverSearchScreen(seniorId: seniorId);
        },
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
        '/caregiverBookings': (context) => const CaregiverBookingsScreen(),
        '/caregiverPublicProfile': (context) {
          final args = ModalRoute.of(context)!.settings.arguments;
          String caregiverId = '';
          String? seniorId;
          if (args is String) {
            caregiverId = args;
          } else if (args is Map) {
            caregiverId = (args['caregiverId'] as String?) ?? (args['id'] as String?) ?? '';
            seniorId = args['seniorId'] as String?;
          }
          return CaregiverPublicProfileScreen(caregiverId: caregiverId, seniorId: seniorId);
        },
      },
    );
  }
}
