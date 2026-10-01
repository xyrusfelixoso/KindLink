/// Screens and destinations agreed during authentication UX planning.
enum AuthScreen { login, signUp, forgotPassword }

enum AuthDestination { authentication, roleSelection, mainApp }

/// The navigation contract for the authentication feature.
abstract final class AuthFlow {
  static const initialScreen = AuthScreen.login;
  static const signedOutDestination = AuthDestination.authentication;
  static const signedInDestination = AuthDestination.roleSelection;
  static const roleSelectedDestination = AuthDestination.mainApp;

  static AuthScreen cancelDestination(AuthScreen screen) => switch (screen) {
    AuthScreen.login => AuthScreen.login,
    AuthScreen.signUp || AuthScreen.forgotPassword => AuthScreen.login,
  };
}
