part of '../../main.dart';

String? _firstProfileString(
  Map<Object?, Object?> profile,
  Iterable<String> keys,
) {
  for (final key in keys) {
    final value = profile[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

String _usernameFromProfile(
  Map<Object?, Object?> profile,
  String fallbackName,
) {
  final stored = _firstProfileString(profile, const [
    'username',
    'nickname',
    'nickName',
    'displayName',
  ]);
  if (stored != null) return stored.replaceFirst(RegExp(r'^@+'), '');
  final generated = fallbackName.replaceAll(RegExp(r'\s+'), '').toLowerCase();
  return generated.isEmpty ? 'member' : generated;
}

class AuthSession {
  const AuthSession({required this.uid, required this.email, this.displayName});

  final String uid;
  final String email;
  final String? displayName;
}

abstract class AuthService {
  Stream<AuthSession?> authStateChanges();

  Future<UserAccount> loadAccount(AuthSession session);

  Future<UserAccount> signIn({required String email, required String password});

  Future<UserAccount> createAccount({
    required String name,
    required String username,
    required String email,
    required String password,
  });

  Future<void> sendPasswordResetEmail(String email);

  Future<void> signOut();
}

class FirebaseAuthService implements AuthService {
  FirebaseAuthService({
    firebase_auth.FirebaseAuth? auth,
    FirebaseDatabase? database,
  }) : _auth = auth ?? firebase_auth.FirebaseAuth.instance,
       _database =
           database ??
           FirebaseDatabase.instanceFor(
             app: Firebase.app(),
             databaseURL: firebaseDatabaseUrl,
           );

  final firebase_auth.FirebaseAuth _auth;
  final FirebaseDatabase _database;

  Future<void> _markOnline(String uid, UserAccount account) async {
    if (!firebasePresenceEnabled) return;
    // Presence belongs to the signed-in user's profile. The database rules
    // already allow members to update their own `users/$uid` branch, while a
    // separate top-level `presence` branch is rejected with permission-denied.
    final presence = _database.ref('users/$uid/presence');
    try {
      // Register this before publishing the online state so an unexpected app
      // or network disconnect cannot leave the member stuck online.
      await presence
          .onDisconnect()
          .update({'online': false, 'lastSeen': ServerValue.timestamp})
          .timeout(const Duration(seconds: 5));
    } on Exception {
      // The normal presence write below may still succeed even if registering
      // the disconnect handler temporarily fails.
    }
    try {
      await presence
          .update({
            'online': true,
            'name': account.name,
            'username': account.username,
            'lastSeen': ServerValue.timestamp,
            'client': 'memberApp',
          })
          .timeout(const Duration(seconds: 5));
    } on Exception {
      // Authentication remains usable while presence is temporarily offline.
    }
  }

  Future<void> _markOffline(String uid) async {
    if (!firebasePresenceEnabled) return;
    final presence = _database.ref('users/$uid/presence');
    try {
      // This must run while Firebase Auth still has the member identity.
      await presence
          .update({'online': false, 'lastSeen': ServerValue.timestamp})
          .timeout(const Duration(seconds: 5));
      await presence.onDisconnect().cancel().timeout(
        const Duration(seconds: 5),
      );
    } on Exception {
      // Never trap the member in the app if the presence service is offline.
      // The registered onDisconnect handler remains the fallback.
    }
  }

  @override
  Stream<AuthSession?> authStateChanges() {
    return _auth.authStateChanges().map((user) {
      if (user == null) return null;
      return AuthSession(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName,
      );
    });
  }

  @override
  Future<UserAccount> loadAccount(AuthSession session) async {
    var profile = <Object?, Object?>{};
    try {
      final snapshot = await _database
          .ref('users/${session.uid}')
          .get()
          .timeout(const Duration(seconds: 10));
      if (snapshot.value is Map) {
        profile = Map<Object?, Object?>.from(snapshot.value! as Map);
      }
    } on Exception {
      // Authentication remains valid while profile data is temporarily
      // unavailable. The app can retry database reads on later screens.
    }

    final email = session.email;
    final emailName = email.split('@').first;
    final storedName = _firstProfileString(profile, const [
      'name',
      'fullName',
      'displayName',
      'nickname',
      'nickName',
    ]);
    final authDisplayName = session.displayName?.trim();
    final fallbackName =
        storedName ??
        (authDisplayName?.isNotEmpty == true ? authDisplayName! : emailName);
    final account = UserAccount(
      name: fallbackName,
      username: _usernameFromProfile(profile, fallbackName),
      email: email,
      profileAvatarIndex: (profile['profileAvatarIndex'] as num?)?.toInt() ?? 0,
      organizationName: profile['organizationName'] as String?,
      organizationDetails: profile['organizationDetails'] as String?,
      isAdmin:
          profile['isAdmin'] == true || isDesignatedAdminEmail(session.email),
    );
    await _markOnline(session.uid, account);
    return account;
  }

  @override
  Future<UserAccount> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth
        .signInWithEmailAndPassword(email: email, password: password)
        .timeout(const Duration(seconds: 20));
    final user = credential.user!;
    final session = AuthSession(
      uid: user.uid,
      email: user.email ?? email,
      displayName: user.displayName,
    );
    final account = await loadAccount(session);

    try {
      await _database.ref('users/${user.uid}').update({
        'email': account.email,
        'lastLoginAt': ServerValue.timestamp,
        if (account.isAdmin) 'isAdmin': true,
      });
    } on Exception {
      // A profile sync failure must not invalidate successful authentication.
    }
    return account;
  }

  @override
  Future<UserAccount> createAccount({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user!;
    await user.updateDisplayName(name);
    final account = UserAccount(
      name: name,
      username: username,
      email: email,
      isAdmin: isDesignatedAdminEmail(email),
    );
    try {
      await _database.ref('users/${user.uid}').set({
        'name': name,
        'username': username,
        'email': email,
        'isAdmin': account.isAdmin,
        'createdAt': ServerValue.timestamp,
      });
    } on Exception {
      // Authentication is authoritative. AuthGate can admit the user with
      // fallback profile data while the database connection recovers.
    }
    await _markOnline(user.uid, account);
    return account;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  @override
  Future<void> signOut() async {
    final uid = _auth.currentUser?.uid;
    try {
      if (uid != null) await _markOffline(uid);
    } finally {
      await _auth.signOut();
    }
  }
}
