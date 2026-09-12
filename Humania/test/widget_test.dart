import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('user can register and view dashboard', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('New here? Create an account'));
    await tester.pump();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Alex User');
    await tester.enterText(fields.at(1), 'alex');
    await tester.enterText(fields.at(2), 'alex@example.com');
    await tester.enterText(fields.at(3), 'secret');
    await tester.tap(find.text('Sign up'));
    await tester.pump();

    expect(find.text('Your Role'), findsOneWidget);
    await tester.tap(find.text('I WANT TO DONATE'));
    await tester.pump();

    expect(find.text('You are helping as a Donor'), findsOneWidget);
  });
}
