import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FailingAuthService implements AuthService {
  _FailingAuthService({
    this.signInCode,
    this.createAccountCode,
    this.resetCode,
  });

  final String? signInCode;
  final String? createAccountCode;
  final String? resetCode;
  var createAccountCalls = 0;

  @override
  Stream<AuthSession?> authStateChanges() => Stream.value(null);

  @override
  Future<UserAccount> signIn({
    required String email,
    required String password,
  }) async {
    throw FirebaseAuthException(code: signInCode ?? 'invalid-credential');
  }

  @override
  Future<UserAccount> createAccount({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    createAccountCalls++;
    throw FirebaseAuthException(
      code: createAccountCode ?? 'email-already-in-use',
    );
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    if (resetCode != null) throw FirebaseAuthException(code: resetCode!);
  }

  @override
  Future<UserAccount> loadAccount(AuthSession session) =>
      throw UnimplementedError();

  @override
  Future<void> signOut() async {}
}

Future<void> _pumpSignedOut(
  WidgetTester tester,
  _FailingAuthService service,
) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(MyApp(authService: service));
  await tester.pumpAndSettle();
}

Future<void> _fillValidSignup(WidgetTester tester) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), 'Humania Member');
  await tester.enterText(fields.at(1), 'member');
  await tester.enterText(fields.at(2), 'member@example.com');
  await tester.enterText(fields.at(3), 'Humania8');
  await tester.enterText(fields.at(4), 'Humania8');
  await tester.pump();
}

void main() {
  testWidgets('wrong login credentials produce a neutral message', (
    tester,
  ) async {
    await _pumpSignedOut(
      tester,
      _FailingAuthService(signInCode: 'wrong-password'),
    );
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'member@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'incorrect');
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    expect(find.text('The email or password is incorrect.'), findsOneWidget);
  });

  testWidgets('offline login remains recoverable', (tester) async {
    await _pumpSignedOut(
      tester,
      _FailingAuthService(signInCode: 'network-request-failed'),
    );
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'member@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Check your connection and try again.'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
  });

  testWidgets('duplicate account creation displays a clear action', (
    tester,
  ) async {
    final service = _FailingAuthService(
      createAccountCode: 'email-already-in-use',
    );
    await _pumpSignedOut(tester, service);
    await tester.tap(find.text('New here? Create an account'));
    await tester.pumpAndSettle();
    await _fillValidSignup(tester);

    final button = find.widgetWithText(FilledButton, 'Create account');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(service.createAccountCalls, 1);
    expect(
      find.text(
        'An account already uses this email address. Try logging in instead.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('offline account creation remains on Sign Up', (tester) async {
    final service = _FailingAuthService(
      createAccountCode: 'network-request-failed',
    );
    await _pumpSignedOut(tester, service);
    await tester.tap(find.text('New here? Create an account'));
    await tester.pumpAndSettle();
    await _fillValidSignup(tester);

    final button = find.widgetWithText(FilledButton, 'Create account');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(service.createAccountCalls, 1);
    expect(find.text('Check your connection and try again.'), findsOneWidget);
    expect(find.text('Create account'), findsWidgets);
  });

  testWidgets('unknown reset accounts receive the neutral confirmation', (
    tester,
  ) async {
    await _pumpSignedOut(
      tester,
      _FailingAuthService(resetCode: 'user-not-found'),
    );
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'missing@example.com');
    await tester.tap(
      find.widgetWithText(FilledButton, 'Send reset instructions'),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'If an account matches that email, reset instructions will be sent.',
      ),
      findsOneWidget,
    );
  });
}
