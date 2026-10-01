import 'package:flutter_application_1/auth/data/auth_error_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthErrorMapper', () {
    test('uses a neutral credential message for login failures', () {
      expect(
        AuthErrorMapper.message(
          operation: AuthOperation.signIn,
          code: 'user-not-found',
        ),
        'The email or password is incorrect.',
      );
      expect(
        AuthErrorMapper.message(
          operation: AuthOperation.signIn,
          code: 'wrong-password',
        ),
        'The email or password is incorrect.',
      );
    });

    test('maps duplicate and weak account creation errors', () {
      expect(
        AuthErrorMapper.message(
          operation: AuthOperation.createAccount,
          code: 'email-already-in-use',
        ),
        contains('already uses this email address'),
      );
      expect(
        AuthErrorMapper.message(
          operation: AuthOperation.createAccount,
          code: 'weak-password',
        ),
        'Choose a stronger password and try again.',
      );
    });

    test('shares recoverable network and rate-limit messages', () {
      for (final operation in AuthOperation.values) {
        expect(
          AuthErrorMapper.message(
            operation: operation,
            code: 'network-request-failed',
          ),
          'Check your connection and try again.',
        );
        expect(
          AuthErrorMapper.message(
            operation: operation,
            code: 'too-many-requests',
          ),
          'Too many attempts. Please wait and try again.',
        );
      }
    });

    test('never exposes unknown internal exception text', () {
      expect(
        AuthErrorMapper.message(
          operation: AuthOperation.signIn,
          code: 'internal-error-detail',
        ),
        'Unable to sign in. Please try again.',
      );
    });
  });
}
