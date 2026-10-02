part of '../../main.dart';

class PasswordField extends StatelessWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.obscureText,
    required this.onVisibilityChanged,
    this.validator,
    this.textInputAction,
    this.autofillHints,
    this.onFieldSubmitted,
    this.onChanged,
    this.focusNode,
    this.enabled = true,
    this.label = 'Password',
    this.hintText = 'Enter your password',
  });
  final TextEditingController controller;
  final bool obscureText;
  final ValueChanged<bool> onVisibilityChanged;
  final FormFieldValidator<String>? validator;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final bool enabled;
  final String label;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      obscureText: obscureText,
      enableSuggestions: false,
      autocorrect: false,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      onFieldSubmitted: onFieldSubmitted,
      onChanged: onChanged,
      validator: validator,
      decoration:
          AuthTheme.fieldDecoration(
            hintText: hintText,
            icon: Icons.lock_outline,
          ).copyWith(
            labelText: label,
            suffixIcon: ExcludeFocus(
              child: KindLinkPressScale(
                child: IconButton(
                  tooltip: obscureText ? 'Show password' : 'Hide password',
                  onPressed: enabled
                      ? () => onVisibilityChanged(!obscureText)
                      : null,
                  icon: Icon(
                    obscureText
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
          ),
    );
  }
}
