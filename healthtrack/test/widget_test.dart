import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:healthtrack/main.mobile.dart'; // make sure tama yung path mo

void main() {
  testWidgets('Login page loads correctly', (WidgetTester tester) async {
    // Build the Login Page (HealthTrackApp shows login as initial screen)
    await tester.pumpWidget(const HealthTrackApp());

    // Check if "Login" text is found
    expect(find.text('Login'), findsOneWidget);

    // Check if email and password fields exist
    expect(find.byType(TextFormField), findsNWidgets(2));

    // Check if Login button exists
    expect(find.text('Login'), findsWidgets); // findsWidgets kasi may text sa AppBar at sa button
  });
}