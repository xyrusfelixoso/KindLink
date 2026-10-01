part of '../../main.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.authService});
  final AuthService authService;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  bool _obscurePassword = true;
  bool _submitting = false;
  bool _rememberEmail = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
  }

  Future<void> _loadRememberedEmail() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('remember_password');
    if (!mounted) return;
    setState(() {
      _rememberEmail = preferences.getBool('remember_me') ?? false;
      if (_rememberEmail) {
        _emailController.text = preferences.getString('remember_email') ?? '';
      }
    });
  }

  Future<void> _saveRememberedEmail() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('remember_me', _rememberEmail);
    await preferences.remove('remember_password');
    if (_rememberEmail) {
      await preferences.setString(
        'remember_email',
        _emailController.text.trim(),
      );
    } else {
      await preferences.remove('remember_email');
    }
  }

  void _togglePasswordVisibility(bool obscurePassword) {
    final selection = _passwordController.selection;
    setState(() => _obscurePassword = obscurePassword);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _passwordFocusNode.requestFocus();
      if (selection.isValid) {
        _passwordController.selection = selection;
      }
    });
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    var refocusPassword = false;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    await _saveRememberedEmail();
    try {
      await widget.authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      TextInput.finishAutofillContext();
    } on firebase_auth.FirebaseAuthException catch (error) {
      if (mounted) {
        _passwordController.clear();
        refocusPassword = true;
        setState(
          () => _errorMessage = AuthErrorMapper.message(
            operation: AuthOperation.signIn,
            code: error.code,
          ),
        );
      }
    } on TimeoutException {
      if (mounted) {
        setState(
          () => _errorMessage = 'The request timed out. Please try again.',
        );
      }
    } on Exception {
      if (mounted) {
        setState(
          () => _errorMessage =
              'Unable to sign in. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
    if (mounted && refocusPassword) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _passwordFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthTheme.pageBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) {
            final compact = viewport.maxWidth < AuthTheme.compactBreakpoint;
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 12 : 22,
                  vertical: compact ? 12 : 22,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AuthTheme.contentMaxWidth,
                  ),
                  child: Container(
                    padding: EdgeInsets.all(compact ? 18 : 30),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AuthTheme.cardRadius),
                    ),
                    child: FocusTraversalGroup(
                      policy: WidgetOrderTraversalPolicy(),
                      child: AutofillGroup(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const KindLinkLogo(height: 112),
                              const SizedBox(height: 12),
                              const Text(
                                'Welcome back',
                                style: AuthTheme.titleStyle,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Sign in to continue helping your community',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 24),
                              AuthTextField(
                                controller: _emailController,
                                label: 'Email address',
                                hintText: 'you@example.com',
                                icon: Icons.mail_outline,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.email],
                                validator: AuthValidators.email,
                              ),
                              const SizedBox(height: AuthTheme.fieldSpacing),
                              PasswordField(
                                controller: _passwordController,
                                focusNode: _passwordFocusNode,
                                obscureText: _obscurePassword,
                                onVisibilityChanged: _togglePasswordVisibility,
                                validator: AuthValidators.loginPassword,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.password],
                                onFieldSubmitted: (_) => _submit(),
                                onChanged: (_) {
                                  if (_errorMessage != null) {
                                    setState(() => _errorMessage = null);
                                  }
                                },
                              ),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 180),
                                child: _errorMessage == null
                                    ? const SizedBox.shrink()
                                    : Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: AuthStatusMessage(
                                          message: _errorMessage!,
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Checkbox(
                                        value: _rememberEmail,
                                        onChanged: _submitting
                                            ? null
                                            : (value) => setState(
                                                () => _rememberEmail =
                                                    value ?? false,
                                              ),
                                      ),
                                      const Flexible(
                                        child: Text('Remember email'),
                                      ),
                                    ],
                                  ),
                                  TextButton(
                                    onPressed: _submitting
                                        ? null
                                        : () => Navigator.of(context).push(
                                            MaterialPageRoute<void>(
                                              builder: (_) =>
                                                  ForgotPasswordPage(
                                                    authService:
                                                        widget.authService,
                                                  ),
                                            ),
                                          ),
                                    child: const Text('Forgot password?'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              AuthSubmitButton(
                                label: 'Log in',
                                onPressed: _submit,
                                isLoading: _submitting,
                              ),
                              const SizedBox(height: 10),
                              TextButton(
                                onPressed: _submitting
                                    ? null
                                    : () => Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => SignupPage(
                                            authService: widget.authService,
                                          ),
                                        ),
                                      ),
                                child: const Text(
                                  'New here? Create an account',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
