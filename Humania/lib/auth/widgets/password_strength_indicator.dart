part of '../../main.dart';

enum PasswordStrength { empty, weak, fair, good, strong }

PasswordStrength passwordStrength(String password) {
  if (password.isEmpty) return PasswordStrength.empty;
  final satisfiedRules = PasswordPolicy.rules
      .where((rule) => rule.isSatisfied(password))
      .length;
  if (satisfiedRules <= 1) return PasswordStrength.weak;
  if (satisfiedRules == 2) return PasswordStrength.fair;
  if (satisfiedRules == 3) return PasswordStrength.good;
  return password.length >= 12
      ? PasswordStrength.strong
      : PasswordStrength.good;
}

class PasswordStrengthIndicator extends StatelessWidget {
  const PasswordStrengthIndicator({super.key, required this.password});
  final String password;

  @override
  Widget build(BuildContext context) {
    final strength = passwordStrength(password);
    final activeSegments = switch (strength) {
      PasswordStrength.empty => 0,
      PasswordStrength.weak => 1,
      PasswordStrength.fair => 2,
      PasswordStrength.good => 3,
      PasswordStrength.strong => 4,
    };
    final color = switch (strength) {
      PasswordStrength.empty => Theme.of(context).colorScheme.outlineVariant,
      PasswordStrength.weak => Theme.of(context).colorScheme.error,
      PasswordStrength.fair => const Color(0xffff9800),
      PasswordStrength.good => const Color(0xff65a30d),
      PasswordStrength.strong => AuthTheme.primaryAction,
    };
    final label = switch (strength) {
      PasswordStrength.empty => 'Not entered',
      PasswordStrength.weak => 'Weak',
      PasswordStrength.fair => 'Fair',
      PasswordStrength.good => 'Good',
      PasswordStrength.strong => 'Strong',
    };

    return Semantics(
      liveRegion: true,
      label: 'Password strength: $label',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            children: [
              const Text(
                'Password strength',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var index = 0; index < 4; index++) ...[
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 6,
                    decoration: BoxDecoration(
                      color: index < activeSegments
                          ? color
                          : Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                if (index < 3) const SizedBox(width: 6),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
