enum AuthOperation { signIn, createAccount, passwordReset }

abstract final class AuthErrorMapper {
  static const passwordResetConfirmation =
      'If an account matches that email, reset instructions will be sent.';

  static String message({
    required AuthOperation operation,
    required String code,
  }) {
    if (code == 'network-request-failed') {
      return 'Check your connection and try again.';
    }
    if (code == 'too-many-requests') {
      return 'Too many attempts. Please wait and try again.';
    }
    return switch (operation) {
      AuthOperation.signIn => _signInMessage(code),
      AuthOperation.createAccount => _createAccountMessage(code),
      AuthOperation.passwordReset => _passwordResetMessage(code),
    };
  }

  static String _signInMessage(String code) => switch (code) {
    'invalid-email' => 'Enter a valid email address.',
    'invalid-credential' ||
    'user-not-found' ||
    'wrong-password' => 'The email or password is incorrect.',
    'user-disabled' => 'This account has been disabled.',
    _ => 'Unable to sign in. Please try again.',
  };

  static String _createAccountMessage(String code) => switch (code) {
    'email-already-in-use' =>
      'An account already uses this email address. Try logging in instead.',
    'invalid-email' => 'Enter a valid email address.',
    'weak-password' => 'Choose a stronger password and try again.',
    'operation-not-allowed' => 'Account creation is temporarily unavailable.',
    _ => 'Unable to create the account. Please try again.',
  };

  static String _passwordResetMessage(String code) => switch (code) {
    'invalid-email' => 'Enter a valid email address.',
    'user-not-found' => passwordResetConfirmation,
    _ => 'Unable to send reset instructions. Please try again.',
  };
}
