import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthService implements AuthService {
  final _sessions = StreamController<AuthSession?>.broadcast();
  AuthSession? currentSession;
  var signOutCalls = 0;

  void emit(AuthSession? session) {
    currentSession = session;
    _sessions.add(session);
  }

  @override
  Stream<AuthSession?> authStateChanges() async* {
    yield currentSession;
    yield* _sessions.stream;
  }

  @override
  Future<UserAccount> loadAccount(AuthSession session) async {
    return UserAccount(
      name: 'Humania Member',
      username: 'member',
      email: session.email,
    );
  }

  @override
  Future<UserAccount> createAccount({
    required String name,
    required String username,
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<UserAccount> signIn({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<void> signOut() async {
    signOutCalls++;
    emit(null);
  }

  Future<void> dispose() => _sessions.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AuthGate routes a signed-out session to Login', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = _FakeAuthService();
    addTearDown(service.dispose);

    await tester.pumpWidget(MyApp(authService: service));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('AuthGate restores a signed-in session at role selection', (
    tester,
  ) async {
    final service = _FakeAuthService()
      ..currentSession = const AuthSession(
        uid: 'member-1',
        email: 'member@example.com',
      );
    addTearDown(service.dispose);

    await tester.pumpWidget(MyApp(authService: service));
    await tester.pumpAndSettle();

    expect(find.text('Your Role'), findsNothing);
    expect(find.byKey(const Key('role-background-image')), findsOneWidget);
    expect(find.text('I WANT TO DONATE'), findsOneWidget);
  });

  testWidgets('a restored session survives an application rebuild', (
    tester,
  ) async {
    final service = _FakeAuthService()
      ..currentSession = const AuthSession(
        uid: 'member-1',
        email: 'member@example.com',
      );
    addTearDown(service.dispose);

    await tester.pumpWidget(MyApp(authService: service));
    await tester.pumpAndSettle();
    expect(find.text('Your Role'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(MyApp(authService: service));
    await tester.pumpAndSettle();

    expect(find.text('Your Role'), findsNothing);
  });

  testWidgets('a signed-out session change returns to Login', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = _FakeAuthService()
      ..currentSession = const AuthSession(
        uid: 'member-1',
        email: 'member@example.com',
      );
    addTearDown(service.dispose);

    await tester.pumpWidget(MyApp(authService: service));
    await tester.pumpAndSettle();
    expect(find.text('Your Role'), findsNothing);

    await service.signOut();
    await tester.pumpAndSettle();

    expect(service.signOutCalls, 1);
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
