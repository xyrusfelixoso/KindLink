import 'package:flutter/material.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _AccessibilityAuthService implements AuthService {
  @override
  Stream<AuthSession?> authStateChanges() => Stream.value(null);

  @override
  Future<UserAccount> signIn({
    required String email,
    required String password,
  }) => throw Exception('Internal server detail that must not be displayed');

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

  testWidgets('auth screens fit a small display with enlarged text', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(MyApp(authService: _AccessibilityAuthService()));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);

    final signupLink = find.text('New here? Create an account');
    await tester.ensureVisible(signupLink);
    await tester.tap(signupLink);
    await tester.pumpAndSettle();
    expect(find.text('Your password needs:'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.text('Reset your password'), findsOneWidget);
  });

  testWidgets('server failures use icon and live semantic feedback', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(MyApp(authService: _AccessibilityAuthService()));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'member@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    const message = 'Unable to sign in. Check your connection and try again.';
    expect(find.text(message), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    final statusSemantics = tester.getSemantics(find.byType(AuthStatusMessage));
    expect(statusSemantics.label, contains('Error: $message'));
    expect(find.textContaining('Internal server detail'), findsNothing);
    semantics.dispose();
  });

  testWidgets('login fields expose logical keyboard actions', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(MyApp(authService: _AccessibilityAuthService()));
    await tester.pumpAndSettle();

    final fields = tester.widgetList<EditableText>(find.byType(EditableText));
    final emailField = fields.elementAt(0);
    final passwordField = fields.elementAt(1);
    expect(emailField.textInputAction, TextInputAction.next);
    expect(passwordField.textInputAction, TextInputAction.done);
    expect(emailField.autofillHints, contains(AutofillHints.email));
    expect(passwordField.autofillHints, contains(AutofillHints.password));
    expect(passwordField.enableInteractiveSelection, isTrue);
    expect(find.byTooltip('Show password'), findsOneWidget);
  });
}
