import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_application_1/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _LoginAuthService implements AuthService {
  final signInCompleter = Completer<UserAccount>();
  var signInCalls = 0;

  @override
  Stream<AuthSession?> authStateChanges() => Stream.value(null);

  @override
  Future<UserAccount> signIn({
    required String email,
    required String password,
  }) {
    signInCalls++;
    return signInCompleter.future;
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
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> signOut() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Login exposes the required Phase 2 actions', (tester) async {
    final service = _LoginAuthService();
    await tester.pumpWidget(MyApp(authService: service));
    await tester.pumpAndSettle();

    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('New here? Create an account'), findsOneWidget);
  });

  testWidgets('Login removes passwords saved by older application builds', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'remember_me': true,
      'remember_email': 'member@example.com',
      'remember_password': 'legacy-plaintext-password',
    });
    final service = _LoginAuthService();

    await tester.pumpWidget(MyApp(authService: service));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('remember_password'), isNull);
    expect(preferences.getString('remember_email'), 'member@example.com');
  });

  testWidgets('visibility control reveals and hides the password', (
    tester,
  ) async {
    final service = _LoginAuthService();
    await tester.pumpWidget(MyApp(authService: service));
    await tester.pumpAndSettle();

    EditableText passwordField() =>
        tester.widget<EditableText>(find.byType(EditableText).at(1));

    await tester.tap(find.byType(TextFormField).at(1));
    await tester.enterText(find.byType(TextFormField).at(1), 'before');
    expect(passwordField().obscureText, isTrue);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pumpAndSettle();
    expect(passwordField().obscureText, isFalse);
    expect(passwordField().focusNode.hasFocus, isTrue);
    expect(find.byTooltip('Hide password'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(1), 'after');
    expect(passwordField().controller.text, 'after');
  });

  testWidgets('empty login displays validation without submitting', (
    tester,
  ) async {
    final service = _LoginAuthService();
    await tester.pumpWidget(MyApp(authService: service));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log in'));
    await tester.pump();

    expect(find.text('Email address is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    expect(service.signInCalls, 0);
  });

  testWidgets('loading state prevents duplicate login requests', (
    tester,
  ) async {
    final service = _LoginAuthService();
    await tester.pumpWidget(MyApp(authService: service));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'member@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.tap(find.text('Log in'));
    await tester.tap(find.text('Log in'), warnIfMissed: false);
    await tester.pump();

    expect(service.signInCalls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField).at(1)).enabled,
      isTrue,
    );

    service.signInCompleter.complete(
      UserAccount(
        name: 'Member',
        username: 'member',
        email: 'member@example.com',
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('password can be replaced after a failed login', (tester) async {
    final service = _LoginAuthService();
    await tester.pumpWidget(MyApp(authService: service));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'member@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'wrong-password');
    await tester.tap(find.text('Log in'));
    await tester.pump();

    service.signInCompleter.completeError(
      firebase_auth.FirebaseAuthException(code: 'wrong-password'),
    );
    await tester.pumpAndSettle();

    expect(find.text('The email or password is incorrect.'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField).at(1)).enabled,
      isTrue,
    );
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText).at(1))
          .focusNode
          .hasFocus,
      isTrue,
    );

    await tester.enterText(find.byType(TextFormField).at(1), 'new-password');
    await tester.pump();

    expect(find.text('The email or password is incorrect.'), findsNothing);
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText).at(1))
          .controller
          .text,
      'new-password',
    );
  });

  testWidgets('Login navigates to Sign Up and Forgot Password', (tester) async {
    final service = _LoginAuthService();
    await tester.pumpWidget(MyApp(authService: service));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New here? Create an account'));
    await tester.pumpAndSettle();
    expect(find.text('Create account'), findsWidgets);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.text('Reset your password'), findsOneWidget);
  });
}
