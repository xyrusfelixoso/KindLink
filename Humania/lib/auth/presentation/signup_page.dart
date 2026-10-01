part of '../../main.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key, required this.authService});
  final AuthService authService;
  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  bool _submitting = false;
  String? _error;

  bool get _canSubmit =>
      _name.text.trim().isNotEmpty &&
      _username.text.trim().isNotEmpty &&
      AuthValidators.email(_email.text) == null &&
      PasswordPolicy.isSatisfiedBy(_password.text) &&
      _confirmPassword.text == _password.text;

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _name,
      _username,
      _email,
      _password,
      _confirmPassword,
    ]) {
      controller.addListener(_refreshFormState);
    }
  }

  void _refreshFormState() {
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.authService.createAccount(
        name: _name.text.trim(),
        username: _username.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
      );
      TextInput.finishAutofillContext();
      if (mounted) {
        // Return to the root without choosing the signed-in destination.
        // AuthGate observes the Firebase session and owns that routing.
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on firebase_auth.FirebaseAuthException catch (error) {
      if (mounted) {
        setState(
          () => _error = AuthErrorMapper.message(
            operation: AuthOperation.createAccount,
            code: error.code,
          ),
        );
      }
    } on Exception {
      if (mounted) setState(() => _error = 'Unable to create the account.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthTheme.pageBackground,
      appBar: AppBar(
        backgroundColor: AuthTheme.pageBackground,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              constraints: const BoxConstraints(
                maxWidth: AuthTheme.contentMaxWidth,
              ),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AuthTheme.cardRadius),
              ),
              child: FocusTraversalGroup(
                policy: WidgetOrderTraversalPolicy(),
                child: AutofillGroup(
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const KindLinkLogo(height: 112),
                        const SizedBox(height: 12),
                        const Text(
                          'Create account',
                          style: AuthTheme.titleStyle,
                        ),
                        const SizedBox(height: 20),
                        AuthTextField(
                          controller: _name,
                          label: 'Full name',
                          hintText: 'Enter your full name',
                          icon: Icons.badge_outlined,
                          validator: (value) =>
                              AuthValidators.required(value, 'Name'),
                          enabled: !_submitting,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: AuthTheme.fieldSpacing),
                        AuthTextField(
                          controller: _username,
                          label: 'Username',
                          hintText: 'Choose a username',
                          icon: Icons.account_circle_outlined,
                          validator: (value) =>
                              AuthValidators.required(value, 'Username'),
                          enabled: !_submitting,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: AuthTheme.fieldSpacing),
                        AuthTextField(
                          controller: _email,
                          label: 'Email address',
                          hintText: 'you@example.com',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          validator: AuthValidators.email,
                          enabled: !_submitting,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: AuthTheme.fieldSpacing),
                        PasswordField(
                          controller: _password,
                          obscureText: _obscurePassword,
                          onVisibilityChanged: (value) =>
                              setState(() => _obscurePassword = value),
                          validator: AuthValidators.newPassword,
                          autofillHints: const [AutofillHints.newPassword],
                          textInputAction: TextInputAction.next,
                          enabled: !_submitting,
                        ),
                        const SizedBox(height: 12),
                        PasswordStrengthIndicator(password: _password.text),
                        const SizedBox(height: 16),
                        PasswordRequirements(password: _password.text),
                        const SizedBox(height: AuthTheme.fieldSpacing),
                        PasswordField(
                          controller: _confirmPassword,
                          label: 'Confirm password',
                          hintText: 'Enter your password again',
                          obscureText: _obscureConfirmation,
                          onVisibilityChanged: (value) =>
                              setState(() => _obscureConfirmation = value),
                          validator: (value) => AuthValidators.confirmPassword(
                            value,
                            _password.text,
                          ),
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.newPassword],
                          enabled: !_submitting,
                          onFieldSubmitted: (_) {
                            if (_canSubmit) _submit();
                          },
                        ),
                        if (_confirmPassword.text.isNotEmpty &&
                            _confirmPassword.text == _password.text) ...[
                          const SizedBox(height: 8),
                          const Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: AuthTheme.primaryAction,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Passwords match',
                                style: TextStyle(
                                  color: AuthTheme.primaryAction,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                        AnimatedSize(
                          duration: const Duration(milliseconds: 180),
                          child: _error == null
                              ? const SizedBox.shrink()
                              : Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: AuthStatusMessage(message: _error!),
                                ),
                        ),
                        const SizedBox(height: 24),
                        AuthSubmitButton(
                          label: 'Create account',
                          onPressed: _canSubmit ? _submit : null,
                          isLoading: _submitting,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
