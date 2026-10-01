import 'package:flutter_application_1/auth/auth_flow.dart';
import 'package:flutter_application_1/auth/validation/auth_validators.dart';
import 'package:flutter_application_1/auth/validation/password_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 0 auth flow', () {
    test('starts signed-out users at login', () {
      expect(AuthFlow.initialScreen, AuthScreen.login);
      expect(AuthFlow.signedOutDestination, AuthDestination.authentication);
    });

    test('returns secondary auth screens to login', () {
      expect(AuthFlow.cancelDestination(AuthScreen.signUp), AuthScreen.login);
      expect(
        AuthFlow.cancelDestination(AuthScreen.forgotPassword),
        AuthScreen.login,
      );
    });
  });

  group('Phase 0 validation contract', () {
    test('login accepts legacy passwords without applying creation rules', () {
      expect(AuthValidators.loginPassword('old'), isNull);
      expect(AuthValidators.loginPassword(''), 'Password is required');
    });

    test('new passwords follow the documented policy', () {
      expect(PasswordPolicy.isSatisfiedBy('Humania8'), isTrue);
      expect(PasswordPolicy.isSatisfiedBy('humania8'), isFalse);
      expect(AuthValidators.newPassword('Humania8'), isNull);
    });

    test('confirmation must match', () {
      expect(AuthValidators.confirmPassword('Humania8', 'Humania8'), isNull);
      expect(
        AuthValidators.confirmPassword('Humania9', 'Humania8'),
        'Passwords do not match',
      );
    });

    test('email validation is shared by auth screens', () {
      expect(AuthValidators.email('person@example.com'), isNull);
      expect(AuthValidators.email('person'), 'Enter a valid email address');
    });
  });
}
