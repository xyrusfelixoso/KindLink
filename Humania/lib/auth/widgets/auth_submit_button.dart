part of '../../main.dart';

class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.isLoading,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: isLoading ? '$label in progress' : label,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AuthTheme.primaryAction,
          minimumSize: const Size.fromHeight(AuthTheme.actionHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AuthTheme.fieldRadius),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: isLoading
              ? const SizedBox(
                  key: ValueKey('loading'),
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(label, key: const ValueKey('label')),
        ),
      ),
    );
  }
}
