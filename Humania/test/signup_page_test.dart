import 'package:flutter/material.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SignupAuthService implements AuthService {
  var createAccountCalls = 0;

  @override
  Stream<AuthSession?> authStateChanges() => Stream.value(null);

  @override
  Future<UserAccount> createAccount({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    createAccountCalls++;
    return UserAccount(name: name, username: username, email: email);
  }

  @override
  Future<UserAccount> loadAccount(AuthSession session) =>
      throw UnimplementedError();

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<UserAccount> signIn({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<void> signOut() async {}
}

Future<void> _openSignup(
  WidgetTester tester,
  _SignupAuthService service,
) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(MyApp(authService: service));
  await tester.pumpAndSettle();
  await tester.tap(find.text('New here? Create an account'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('password requirements and strength update while typing', (
    tester,
  ) async {
    final service = _SignupAuthService();
    await _openSignup(tester, service);

    expect(find.text('At least 8 characters'), findsOneWidget);
    expect(find.text('At least one uppercase letter'), findsOneWidget);
    expect(find.text('At least one lowercase letter'), findsOneWidget);
    expect(find.text('At least one number'), findsOneWidget);
    expect(find.text('Not entered'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(3), 'Humania8');
    await tester.pump();
    expect(find.text('Good'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(3), 'HumaniaSecure8');
    await tester.pump();
    expect(find.text('Strong'), findsOneWidget);
  });

  testWidgets('confirmation mismatch is communicated before submission', (
    tester,
  ) async {
    final service = _SignupAuthService();
    await _openSignup(tester, service);

    await tester.enterText(find.byType(TextFormField).at(3), 'Humania8');
    await tester.enterText(find.byType(TextFormField).at(4), 'Humania9');
    await tester.pump();

    expect(find.text('Passwords do not match'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Create account'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('Create Account enables only when all rules are satisfied', (
    tester,
  ) async {
    final service = _SignupAuthService();
    await _openSignup(tester, service);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Humania Member');
    await tester.enterText(fields.at(1), 'member');
    await tester.enterText(fields.at(2), 'member@example.com');
    await tester.enterText(fields.at(3), 'Humania8');
    await tester.enterText(fields.at(4), 'Humania8');
    await tester.pump();

    expect(find.text('Passwords match'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Create account'),
    );
    expect(button.onPressed, isNotNull);

    final createButton = find.widgetWithText(FilledButton, 'Create account');
    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
    await tester.pumpAndSettle();
    expect(service.createAccountCalls, 1);
  });

  testWidgets('password and confirmation visibility are independent', (
    tester,
  ) async {
    final service = _SignupAuthService();
    await _openSignup(tester, service);

    expect(find.byTooltip('Show password'), findsNWidgets(2));
    await tester.tap(find.byTooltip('Show password').first);
    await tester.pump();

    expect(find.byTooltip('Hide password'), findsOneWidget);
    expect(find.byTooltip('Show password'), findsOneWidget);

    final passwordFields = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .skip(3);
    for (final field in passwordFields) {
      expect(field.autofillHints, contains(AutofillHints.newPassword));
      expect(field.enableInteractiveSelection, isTrue);
    }
  });
}
