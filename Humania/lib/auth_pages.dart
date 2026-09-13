part of 'main.dart';

class RolePage extends StatelessWidget {
  const RolePage({
    super.key,
    required this.onRoleSelected,
    this.showAdmin = false,
  });

  final ValueChanged<String> onRoleSelected;
  final bool showAdmin;

  @override
  Widget build(BuildContext context) {
    const green = Color(0xff2d7355);
    return Scaffold(
      backgroundColor: const Color(0xfff5f8f6),
      appBar: AppBar(
        backgroundColor: const Color(0xffd9f4df),
        title: const Text(
          'Your Role',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xffd9f4df),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text('🥦  🍞  🧸  👕', style: TextStyle(fontSize: 44)),
                ),
                SizedBox(height: 24),
                Text(
                  'Share food & items with those who need them',
                  style: TextStyle(
                    color: Color(0xff194c3b),
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Humania connects generous donors with families and shelters nearby - in minutes.',
                  style: TextStyle(color: Color(0xff527d6d), fontSize: 15),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          _RoleButton(
            label: 'I WANT TO DONATE',
            icon: Icons.volunteer_activism_outlined,
            color: green,
            onPressed: () => onRoleSelected('Donor'),
          ),
          _RoleButton(
            label: 'I NEED HELP!',
            icon: Icons.pan_tool_alt_outlined,
            color: green,
            onPressed: () => onRoleSelected('Recipient'),
          ),
          _RoleButton(
            label: 'I AM AN ORGANIZATION',
            icon: Icons.apartment_outlined,
            color: green,
            onPressed: () => onRoleSelected('Organization'),
          ),
          if (showAdmin)
            _RoleButton(
              label: 'ADMIN VERIFICATION',
              icon: Icons.admin_panel_settings_outlined,
              color: green,
              onPressed: () => onRoleSelected('Admin'),
            ),
        ],
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  const _RoleButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          minimumSize: const Size.fromHeight(62),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onSignedIn});

  final ValueChanged<UserAccount> onSignedIn;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRegistering = false;
  bool _hidePassword = true;
  bool _submitting = false;
  bool _rememberMe = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadRememberedLogin();
  }

  Future<void> _loadRememberedLogin() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _rememberMe = preferences.getBool('remember_me') ?? false;
      if (_rememberMe) {
        _usernameController.text =
            preferences.getString('remember_email') ?? '';
        _passwordController.text =
            preferences.getString('remember_password') ?? '';
      }
    });
  }

  Future<void> _saveRememberedLogin() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('remember_me', _rememberMe);
    if (_rememberMe) {
      await preferences.setString(
        'remember_email',
        _usernameController.text.trim(),
      );
      await preferences.setString(
        'remember_password',
        _passwordController.text,
      );
    } else {
      await preferences.remove('remember_email');
      await preferences.remove('remember_password');
    }
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label is required';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    final loginIdentifier = _usernameController.text.trim();
    final password = _passwordController.text;
    if (!_isRegistering) await _saveRememberedLogin();

    if (_isRegistering) {
      final account = UserAccount(
        name: _nameController.text.trim(),
        username: loginIdentifier,
        email: _emailController.text.trim(),
        password: password,
        isAdmin: isDesignatedAdminEmail(_emailController.text),
      );
      try {
        final credential = await firebase_auth.FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: account.email,
              password: password,
            );
        await credential.user?.updateDisplayName(account.name);
        await database.ref('users/${credential.user!.uid}').set({
          'name': account.name,
          'username': account.username,
          'email': account.email,
          'isAdmin': account.isAdmin,
          'createdAt': ServerValue.timestamp,
        });
        if (mounted) widget.onSignedIn(account);
      } on firebase_auth.FirebaseAuthException catch (error) {
        if (mounted) {
          setState(() {
            _errorMessage = error.message ?? 'Unable to create the account.';
          });
        }
      } on Exception {
        if (mounted) {
          setState(() {
            _errorMessage =
                'Account created, but the member profile could not be saved.';
          });
        }
      } finally {
        if (mounted) setState(() => _submitting = false);
      }
      return;
    }

    try {
      final credential = await firebase_auth.FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: loginIdentifier,
            password: password,
          )
          .timeout(const Duration(seconds: 20));
      var profile = <Object?, Object?>{};
      try {
        final snapshot = await database
            .ref('users/${credential.user!.uid}')
            .get()
            .timeout(const Duration(seconds: 10));
        if (snapshot.value is Map) {
          profile = Map<Object?, Object?>.from(snapshot.value! as Map);
        }
      } on Exception {
        // Authentication is enough to enter the app. Profile data can load
        // again later when the database connection recovers.
      }
      final fallbackName =
          credential.user!.displayName ?? loginIdentifier.split('@').first;
      try {
        await database.ref('users/${credential.user!.uid}').update({
          if (profile.isEmpty) 'name': fallbackName,
          if (profile.isEmpty) 'username': loginIdentifier.split('@').first,
          'email': credential.user!.email ?? loginIdentifier,
          if (profile.isEmpty)
            'isAdmin': isDesignatedAdminEmail(credential.user!.email),
          'lastLoginAt': ServerValue.timestamp,
        });
      } on Exception {
        // Login can continue using the authenticated Firebase identity.
      }
      widget.onSignedIn(
        UserAccount(
          name: profile['name'] as String? ?? fallbackName,
          username: profile['username'] as String? ?? loginIdentifier,
          email: credential.user!.email ?? loginIdentifier,
          password: password,
          profileAvatarIndex:
              (profile['profileAvatarIndex'] as num?)?.toInt() ?? 0,
          organizationName: profile['organizationName'] as String?,
          organizationDetails: profile['organizationDetails'] as String?,
          isAdmin:
              profile['isAdmin'] == true ||
              isDesignatedAdminEmail(credential.user!.email),
        ),
      );
      if (isDesignatedAdminEmail(credential.user!.email) &&
          profile['isAdmin'] != true) {
        try {
          await database.ref('users/${credential.user!.uid}').update({
            'isAdmin': true,
          });
        } on Exception {
          // The designated account still receives the local admin interface.
        }
      }
    } on firebase_auth.FirebaseAuthException catch (error) {
      if (mounted) {
        if (_isRegistering &&
            (error.code == 'network-request-failed' ||
                error.code == 'internal' ||
                error.code == 'unknown')) {
          final account = UserAccount(
            name: _nameController.text.trim(),
            username: loginIdentifier,
            email: _emailController.text.trim(),
            password: password,
          );
          widget.onSignedIn(account);
        } else {
          setState(() {
            _errorMessage = error.message ?? 'Authentication failed.';
          });
        }
      }
    } on Exception {
      if (mounted) {
        setState(() => _errorMessage = 'Unable to connect to Firebase.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _toggleMode() {
    setState(() {
      _isRegistering = !_isRegistering;
      _errorMessage = null;
      _formKey.currentState?.reset();
    });
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    final hint = switch (label) {
      'Full name' => 'Enter your full name',
      'Username' => 'Choose a username',
      'Email' || 'Email address' => 'you@example.com',
      'Password' => 'Enter your password',
      _ => label,
    };
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xffdceee3), width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xff4dbb8c), width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff1c6349),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) {
            final compact = viewport.maxWidth < 420;
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 12 : 22,
                  vertical: compact ? 12 : 22,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Container(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 18 : 30,
                      compact ? 20 : 24,
                      compact ? 18 : 30,
                      20,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _isRegistering
                                  ? 'Create account'
                                  : 'Welcome back',
                              style: const TextStyle(
                                color: Color(0xff194c3b),
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _isRegistering
                                  ? 'Join us in helping your community'
                                  : 'Sign in to continue helping your community',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 24),
                            if (_isRegistering) ...[
                              TextFormField(
                                controller: _nameController,
                                decoration: _inputDecoration(
                                  'Full name',
                                  Icons.badge_outlined,
                                ),
                                validator: (value) => _required(value, 'Name'),
                              ),
                              const SizedBox(height: 16),
                            ],
                            TextFormField(
                              controller: _usernameController,
                              keyboardType: _isRegistering
                                  ? TextInputType.text
                                  : TextInputType.emailAddress,
                              decoration: _inputDecoration(
                                _isRegistering ? 'Username' : 'Email address',
                                _isRegistering
                                    ? Icons.account_circle_outlined
                                    : Icons.mail_outline,
                              ),
                              validator: (value) => _required(
                                value,
                                _isRegistering ? 'Username' : 'Email address',
                              ),
                            ),
                            if (_isRegistering) ...[
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: _inputDecoration(
                                  'Email',
                                  Icons.email_outlined,
                                ),
                                validator: (value) => _required(value, 'Email'),
                              ),
                            ],
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _hidePassword,
                              decoration:
                                  _inputDecoration(
                                    'Password',
                                    Icons.lock_outline,
                                  ).copyWith(
                                    suffixIcon: IconButton(
                                      onPressed: () => setState(
                                        () => _hidePassword = !_hidePassword,
                                      ),
                                      icon: Icon(
                                        _hidePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                    ),
                                  ),
                              validator: (value) =>
                                  _required(value, 'Password'),
                            ),
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: _submitting ? null : _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xff2d7355),
                                minimumSize: const Size.fromHeight(58),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _submitting
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(_isRegistering ? 'Sign up' : 'Log in'),
                            ),
                            if (!_isRegistering)
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Checkbox(
                                        value: _rememberMe,
                                        onChanged: (value) => setState(
                                          () => _rememberMe = value ?? false,
                                        ),
                                      ),
                                      const Text('Remember me'),
                                    ],
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      final email = _usernameController.text
                                          .trim();
                                      if (email.isEmpty) return;
                                      await firebase_auth.FirebaseAuth.instance
                                          .sendPasswordResetEmail(email: email);
                                      if (!mounted) return;
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Password reset email sent.',
                                              ),
                                            ),
                                          );
                                    },
                                    child: const Text('Forgot password?'),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 14),
                            if (compact)
                              Center(
                                child: Text(
                                  'or continue with',
                                  style: TextStyle(color: Colors.grey.shade500),
                                ),
                              )
                            else
                              Row(
                                children: [
                                  const Expanded(child: Divider()),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    child: Text(
                                      'or continue with',
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ),
                                  const Expanded(child: Divider()),
                                ],
                              ),
                            const SizedBox(height: 14),
                            if (!_isRegistering)
                              LayoutBuilder(
                                builder: (context, socialConstraints) {
                                  final stackButtons =
                                      socialConstraints.maxWidth < 320;
                                  final buttonWidth = stackButtons
                                      ? socialConstraints.maxWidth
                                      : (socialConstraints.maxWidth - 14) / 2;
                                  return Wrap(
                                    spacing: 14,
                                    runSpacing: 10,
                                    children: [
                                      SizedBox(
                                        width: buttonWidth,
                                        child: OutlinedButton.icon(
                                          onPressed: () {},
                                          icon: const Text(
                                            'G',
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          label: const Text('Google'),
                                        ),
                                      ),
                                      SizedBox(
                                        width: buttonWidth,
                                        child: OutlinedButton.icon(
                                          onPressed: () {},
                                          icon: const Text(
                                            'f',
                                            style: TextStyle(
                                              color: Colors.blue,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          label: const Text('Facebook'),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            TextButton(
                              onPressed: _toggleMode,
                              child: Text(
                                _isRegistering
                                    ? 'Already have an account? Log in'
                                    : 'New here? Create an account',
                              ),
                            ),
                          ],
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
