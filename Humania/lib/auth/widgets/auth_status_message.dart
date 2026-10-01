part of '../../main.dart';

enum AuthStatusTone { error, success, information }

class AuthStatusMessage extends StatelessWidget {
  const AuthStatusMessage({
    super.key,
    required this.message,
    this.tone = AuthStatusTone.error,
  });

  final String message;
  final AuthStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final (icon, color, semanticPrefix) = switch (tone) {
      AuthStatusTone.error => (
        Icons.error_outline,
        Theme.of(context).colorScheme.error,
        'Error',
      ),
      AuthStatusTone.success => (
        Icons.check_circle_outline,
        AuthTheme.primaryAction,
        'Success',
      ),
      AuthStatusTone.information => (
        Icons.info_outline,
        Theme.of(context).colorScheme.primary,
        'Information',
      ),
    };

    return Semantics(
      liveRegion: true,
      label: '$semanticPrefix: $message',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }
}
