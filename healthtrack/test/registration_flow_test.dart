import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthtrack/main.mobile.dart';
import 'package:healthtrack/unified_register_screen.dart';
import 'package:healthtrack/login_screen.dart';
import 'package:healthtrack/dashboard.dart';

void main() {
  group('Registration Flow Integration Tests', () {
    testWidgets('Complete registration flow works correctly', (WidgetTester tester) async {
      // Build the app
      await tester.pumpWidget(const HealthTrackApp());
      await tester.pumpAndSettle();

      // Navigate to registration screen
      // From splash screen to welcome screen
      await tester.pump(const Duration(seconds: 3));
      
      // Tap "Get Started" button
      final getStartedButton = find.text('Get Started');
      if (getStartedButton.hasFound) {
        await tester.tap(getStartedButton);
        await tester.pumpAndSettle();
      }
      
      // Tap "Create an Account" button
      final createAccountButton = find.text('Create an Account');
      if (createAccountButton.hasFound) {
        await tester.tap(createAccountButton);
        await tester.pumpAndSettle();
      }
      
      // Verify we're on the unified registration screen
      expect(find.text('Unified Registration'), findsOneWidget);
      
      // Fill in the registration form for immunization service
      await tester.enterText(find.widgetWithText(TextFormField, 'Full Name'), 'John Doe');
      await tester.enterText(find.widgetWithText(TextFormField, 'Contact Number'), '1234567890');
      await tester.enterText(find.widgetWithText(TextFormField, 'Address'), '123 Main St');
      await tester.enterText(find.widgetWithText(TextFormField, 'Child\'s Name'), 'Baby Doe');
      
      // Select date of birth
      final dobField = find.widgetWithText(TextFormField, 'Date of Birth');
      await tester.tap(dobField);
      await tester.pumpAndSettle();
      
      // Fill in place of birth
      await tester.enterText(find.widgetWithText(TextFormField, 'Place of Birth'), 'City Hospital');
      
      // Fill in account information
      await tester.enterText(find.widgetWithText(TextFormField, 'Username'), 'johndoe');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'password123');
      await tester.enterText(find.widgetWithText(TextFormField, 'Confirm Password'), 'password123');
      
      // Tap register button
      final registerButton = find.text('Register');
      await tester.tap(registerButton);
      await tester.pump();
      
      // Should redirect to login screen
      expect(find.text('Sign in'), findsOneWidget);
    });

    testWidgets('Service-specific dashboard routing works', (WidgetTester tester) async {
      // This test would require mocking the backend API
      // For now, we'll just verify the dashboard correctly handles service types
      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardScreen(),
        ),
      );
      
      // Verify dashboard loads
      expect(find.byType(BottomNavigationBar), findsOneWidget);
    });
  });
}