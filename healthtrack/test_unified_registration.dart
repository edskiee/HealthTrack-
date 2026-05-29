import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:healthtrack/unified_register_screen.dart';

void main() {
  group('Unified Registration Screen Tests', () {
    testWidgets('Unified registration screen displays correctly', (WidgetTester tester) async {
      // Build the unified registration screen
      await tester.pumpWidget(
        MaterialApp(
          home: UnifiedRegisterScreen(),
        ),
      );

      // Verify that the screen displays correctly
      expect(find.text('Unified Registration'), findsOneWidget);
      expect(find.text('Select Service Type'), findsOneWidget);
      expect(find.text('General Information'), findsOneWidget);
      expect(find.text('Child Information'), findsOneWidget);
      expect(find.text('Account Setup'), findsOneWidget);
      
      // Verify that the service type dropdown is present
      expect(find.byType(DropdownButtonFormField<String>), findsWidgets);
      
      // Verify that the register button is present
      expect(find.text('Register'), findsOneWidget);
    });

    testWidgets('Service type selection changes form fields', (WidgetTester tester) async {
      // Build the unified registration screen
      await tester.pumpWidget(
        MaterialApp(
          home: UnifiedRegisterScreen(),
        ),
      );

      // Find the service type dropdown
      final dropdown = find.byType(DropdownButtonFormField<String>).first;
      
      // Initially should show immunization fields
      expect(find.text('Immunization Information'), findsOneWidget);
      expect(find.text('Maternal Care Information'), findsNothing);
      
      // Change service type to maternal
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      
      // Select maternal care option
      await tester.tap(find.text('Maternal Care').last);
      await tester.pump();
      
      // Should now show maternal care fields
      expect(find.text('Maternal Care Information'), findsOneWidget);
      expect(find.text('Immunization Information'), findsNothing);
    });

    testWidgets('Form validation works correctly', (WidgetTester tester) async {
      // Build the unified registration screen
      await tester.pumpWidget(
        MaterialApp(
          home: UnifiedRegisterScreen(),
        ),
      );

      // Try to register without filling required fields
      final registerButton = find.text('Register');
      await tester.tap(registerButton);
      await tester.pump();
      
      // Should show validation errors
      expect(find.text('Full name is required'), findsOneWidget);
      expect(find.text('Contact number is required'), findsOneWidget);
      expect(find.text('Address is required'), findsOneWidget);
    });
  });
}