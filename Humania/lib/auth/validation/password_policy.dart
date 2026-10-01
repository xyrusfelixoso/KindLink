class PasswordRule {
  const PasswordRule({required this.label, required this.isSatisfied});

  final String label;
  final bool Function(String password) isSatisfied;
}

/// Password creation policy shown on Sign Up and password reset flows.
///
/// Login deliberately does not evaluate these rules because an existing
/// account may have been created under an earlier policy.
abstract final class PasswordPolicy {
  static const minimumLength = 8;

  static final rules = <PasswordRule>[
    PasswordRule(
      label: 'At least $minimumLength characters',
      isSatisfied: (password) => password.length >= minimumLength,
    ),
    PasswordRule(
      label: 'At least one uppercase letter',
      isSatisfied: (password) => RegExp(r'[A-Z]').hasMatch(password),
    ),
    PasswordRule(
      label: 'At least one lowercase letter',
      isSatisfied: (password) => RegExp(r'[a-z]').hasMatch(password),
    ),
    PasswordRule(
      label: 'At least one number',
      isSatisfied: (password) => RegExp(r'[0-9]').hasMatch(password),
    ),
  ];

  static bool isSatisfiedBy(String password) =>
      rules.every((rule) => rule.isSatisfied(password));
}
