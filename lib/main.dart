import 'package:device_preview/device_preview.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'caregiver/ caregiver_documents_screen.dart';
import 'caregiver/caregiver_dashboard_screen.dart';
import 'caregiver/caregiver_profile_edit_screen.dart';
import 'firebase_options.dart';
import 'guardian_dashboard.dart';
import 'login.dart';
import 'register.dart';
import 'home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Check if user already logged in
  final user = FirebaseAuth.instance.currentUser;

  runApp(
    DevicePreview(
      enabled: !kReleaseMode,
      builder: (context) => MyApp(
        isLoggedIn: user != null,
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      useInheritedMediaQuery: true, // required for DevicePreview
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
        '/caregiverDashboard': (context) => const CaregiverDashboardScreen(),
        '/caregiverProfileEdit': (context) => const CaregiverProfileEditScreen(),
        '/caregiverDocuments': (context) => const CaregiverDocumentsScreen(),


      },
    );
  }
}
