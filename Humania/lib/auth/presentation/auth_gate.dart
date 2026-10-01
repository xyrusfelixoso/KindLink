part of '../../main.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.authService});

  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthSession?>(
      stream: authService.authStateChanges(),
      builder: (context, sessionSnapshot) {
        if (sessionSnapshot.connectionState == ConnectionState.waiting) {
          return const _AuthLoadingScreen();
        }
        final session = sessionSnapshot.data;
        if (session == null) {
          return LoginPage(authService: authService);
        }
        return FutureBuilder<UserAccount>(
          future: authService.loadAccount(session),
          builder: (context, accountSnapshot) {
            if (accountSnapshot.connectionState != ConnectionState.done) {
              return const _AuthLoadingScreen();
            }
            if (accountSnapshot.hasError || !accountSnapshot.hasData) {
              return _AuthProfileError(
                onRetry: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (_) => AuthGate(authService: authService),
                  ),
                ),
                onSignOut: authService.signOut,
              );
            }
            final account = accountSnapshot.data!;
            return _AuthenticatedHome(
              key: ValueKey(session.uid),
              user: account,
              authService: authService,
            );
          },
        );
      },
    );
  }
}

class _AuthenticatedHome extends StatefulWidget {
  const _AuthenticatedHome({
    super.key,
    required this.user,
    required this.authService,
  });

  final UserAccount user;
  final AuthService authService;

  @override
  State<_AuthenticatedHome> createState() => _AuthenticatedHomeState();
}

class _AuthenticatedHomeState extends State<_AuthenticatedHome> {
  String? _role;

  @override
  Widget build(BuildContext context) {
    if (_role == null) {
      return RolePage(
        showAdmin: widget.user.isAdmin,
        onRoleSelected: (role) => setState(() => _role = role),
      );
    }
    return DashboardPage(
      user: widget.user,
      onSignOut: widget.authService.signOut,
      role: _role!,
    );
  }
}

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _AuthProfileError extends StatelessWidget {
  const _AuthProfileError({required this.onRetry, required this.onSignOut});

  final VoidCallback onRetry;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('We could not load your member profile.'),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
              TextButton(onPressed: onSignOut, child: const Text('Sign out')),
            ],
          ),
        ),
      ),
    );
  }
}
