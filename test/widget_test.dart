import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/phone_entry_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/main.dart'; // Import the main app file

void main() {
  testWidgets('Phone Entry Screen loads', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: PhoneEntryPage()));
    expect(find.text('Enter your phone no.'), findsOneWidget);
  });
}