import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ResetAuthService implements AuthService {
  final resetCompleter = Completer<void>();
  var resetCalls = 0;
  String? submittedEmail;

  @override
  Stream<AuthSession?> authStateChanges() => Stream.value(null);

  @override
  Future<void> sendPasswordResetEmail(String email) {
    resetCalls++;
    submittedEmail = email;
    return resetCompleter.future;
  }

  @override
  Future<UserAccount> createAccount({
    required String name,
    required String username,
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<UserAccount> loadAccount(AuthSession session) =>
      throw UnimplementedError();

  @override
  Future<UserAccount> signIn({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<void> signOut() async {}
}

Future<void> _openForgotPassword(
  WidgetTester tester,
  _ResetAuthService service,
) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(MyApp(authService: service));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Forgot password?'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Forgot Password validates the email before submission', (
    tester,
  ) async {
    final service = _ResetAuthService();
    await _openForgotPassword(tester, service);

    await tester.tap(
      find.widgetWithText(FilledButton, 'Send reset instructions'),
    );
    await tester.pump();

    expect(find.text('Email address is required'), findsOneWidget);
    expect(service.resetCalls, 0);
  });

  testWidgets('Forgot Password sends a neutral confirmation', (tester) async {
    final service = _ResetAuthService();
    await _openForgotPassword(tester, service);

    await tester.enterText(find.byType(TextFormField), 'member@example.com');
    await tester.tap(
      find.widgetWithText(FilledButton, 'Send reset instructions'),
    );
    await tester.pump();

    expect(service.resetCalls, 1);
    expect(service.submittedEmail, 'member@example.com');
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    service.resetCompleter.complete();
    await tester.pumpAndSettle();

    expect(
      find.text(
        'If an account matches that email, reset instructions will be sent.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Forgot Password blocks repeated submissions while loading', (
    tester,
  ) async {
    final service = _ResetAuthService();
    await _openForgotPassword(tester, service);

    await tester.enterText(find.byType(TextFormField), 'member@example.com');
    final button = find.widgetWithText(FilledButton, 'Send reset instructions');
    await tester.tap(button);
    await tester.tap(button, warnIfMissed: false);
    await tester.pump();

    expect(service.resetCalls, 1);
    service.resetCompleter.complete();
    await tester.pumpAndSettle();
  });
}
