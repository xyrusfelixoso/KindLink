part of '../../main.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, required this.authService});
  final AuthService authService;
  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _submitting = false;
  String? _message;
  bool _messageIsError = false;

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await widget.authService.sendPasswordResetEmail(_email.text.trim());
      if (mounted) {
        setState(() {
          _message = AuthErrorMapper.passwordResetConfirmation;
          _messageIsError = false;
        });
      }
    } on firebase_auth.FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() {
          _message = AuthErrorMapper.message(
            operation: AuthOperation.passwordReset,
            code: error.code,
          );
          _messageIsError =
              _message != AuthErrorMapper.passwordResetConfirmation;
        });
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _message = 'Unable to send reset instructions. Please try again.';
          _messageIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot password')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: FocusTraversalGroup(
            policy: WidgetOrderTraversalPolicy(),
            child: Form(
              key: _formKey,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Reset your password',
                      style: AuthTheme.titleStyle,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Enter the email address associated with your KindLink account.',
                    ),
                    const SizedBox(height: 24),
                    AuthTextField(
                      controller: _email,
                      label: 'Email address',
                      hintText: 'you@example.com',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      validator: AuthValidators.email,
                      enabled: !_submitting,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 180),
                      child: _message == null
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: AuthStatusMessage(
                                message: _message!,
                                tone: _messageIsError
                                    ? AuthStatusTone.error
                                    : AuthStatusTone.information,
                              ),
                            ),
                    ),
                    const SizedBox(height: 24),
                    AuthSubmitButton(
                      label: 'Send reset instructions',
                      onPressed: _submit,
                      isLoading: _submitting,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
