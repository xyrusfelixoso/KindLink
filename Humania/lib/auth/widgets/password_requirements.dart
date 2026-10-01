part of '../../main.dart';

class PasswordRequirements extends StatelessWidget {
  const PasswordRequirements({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Password requirements',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your password needs:',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          for (final rule in PasswordPolicy.rules)
            _PasswordRequirementRow(
              label: rule.label,
              isSatisfied: rule.isSatisfied(password),
            ),
        ],
      ),
    );
  }
}

class _PasswordRequirementRow extends StatelessWidget {
  const _PasswordRequirementRow({
    required this.label,
    required this.isSatisfied,
  });
  final String label;
  final bool isSatisfied;

  @override
  Widget build(BuildContext context) {
    final color = isSatisfied
        ? AuthTheme.primaryAction
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Icon(
              isSatisfied ? Icons.check_circle : Icons.radio_button_unchecked,
              key: ValueKey(isSatisfied),
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }
}
