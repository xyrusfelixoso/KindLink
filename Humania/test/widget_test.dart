import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SignedOutAuthService implements AuthService {
  @override
  Stream<AuthSession?> authStateChanges() => Stream.value(null);

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
  Future<UserAccount> signIn({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<void> signOut() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const phoneSizes = <Size>[Size(320, 568), Size(360, 640), Size(412, 915)];

  for (final size in phoneSizes) {
    testWidgets('login fits ${size.width.toInt()}x${size.height.toInt()}', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(MyApp(authService: _SignedOutAuthService()));
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget);
    });
  }
}
