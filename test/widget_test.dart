import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:senior_care_app/main.dart';

void main() {
  testWidgets('Shows login screen when user is logged out',
          (WidgetTester tester) async {
        // Build the app with logged-out state
        await tester.pumpWidget(const MyApp(isLoggedIn: false));
        await tester.pumpAndSettle();

        // Check that the login screen is shown
        expect(find.text('Senior Care'), findsOneWidget);
        expect(find.text('Welcome back! Please sign in.'), findsOneWidget);
        expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
      });

  testWidgets('Can navigate from Login to Register screen',
          (WidgetTester tester) async {
        // Start from login
        await tester.pumpWidget(const MyApp(isLoggedIn: false));
        await tester.pumpAndSettle();

        // Tap "Don't have an account? Register"
        await tester.tap(find.text("Don't have an account? Register"));
        await tester.pumpAndSettle();

        // Verify that the Register screen is shown
        expect(find.text('Create Account'), findsOneWidget);
        expect(find.widgetWithText(ElevatedButton, 'Register'), findsOneWidget);
      });
}
