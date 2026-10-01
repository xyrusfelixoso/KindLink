import 'password_policy.dart';

abstract final class AuthValidators {
  static final _emailPattern = RegExp(
    r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$",
  );

  static String? required(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label is required';
    return null;
  }

  /// Login only checks that credentials are present and the email is shaped
  /// correctly. Password creation rules do not belong on the login screen.
  static String? loginPassword(String? value) => required(value, 'Password');

  static String? email(String? value) {
    final requiredError = required(value, 'Email address');
    if (requiredError != null) return requiredError;
    if (!_emailPattern.hasMatch(value!.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? newPassword(String? value) {
    final requiredError = required(value, 'Password');
    if (requiredError != null) return requiredError;
    if (!PasswordPolicy.isSatisfiedBy(value!)) {
      return 'Password does not meet the requirements';
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    final requiredError = required(value, 'Confirm password');
    if (requiredError != null) return requiredError;
    if (value != password) return 'Passwords do not match';
    return null;
  }
}
