# Humania authentication architecture

Phase 0 fixes the authentication UX contract before further Firebase work.

## Screen flow

- Signed-out app start opens Login.
- Login can open Sign Up or Forgot Password.
- Cancelling Sign Up or Forgot Password returns to Login.
- Successful authentication opens role selection.
- Selecting a role opens the main dashboard.
- Signing out returns to Login.
- Every asynchronous action keeps the user on its screen when it fails and shows a recoverable, user-readable error.

## Validation responsibilities

- Login validates a non-empty, well-formed email and a non-empty password only. It never shows password-creation rules.
- Sign Up validates required profile fields, a well-formed email, the current password policy, and a matching confirmation.
- Forgot Password validates a well-formed email and uses a neutral success response.
- Firebase remains the authority for authentication outcomes. Client validation exists to improve usability.

## Password policy

New passwords require at least eight characters, one uppercase letter, one lowercase letter, and one number. Symbols are allowed but are not required. Password guidance belongs on Sign Up and future create/reset-password screens, not Login.

## Reusable presentation structure

The auth feature is organized around these reusable components as later phases build the screens:

- `AuthTheme`: colors, spacing, radii, typography, field decoration, and responsive constraints.
- `AuthValidators`: separate login, email, new-password, and confirmation validation.
- `PasswordPolicy`: the single source of truth for password rules.
- `AuthFlow`: screen and destination contracts.
- Planned widgets: `AuthTextField`, `PasswordField`, `PasswordRequirements`, `PasswordStrengthIndicator`, and `AuthSubmitButton`.

UI widgets own transient form state and display results. Validators evaluate input. `AuthService` owns Firebase calls, while `AuthGate` owns session routing.

## Phase 1 implementation

- `FirebaseAuthService` now owns account creation, sign-in, sign-out, reset-email requests, profile loading, and Firebase authentication-state observation.
- `AuthGate` listens to Firebase session changes and routes signed-out users to Login or restores signed-in users at role selection.
- The authenticated application subtree is keyed by Firebase user ID, so sign-out or account changes clear role-specific navigation state.
- Login delegates authentication work to `AuthService`; Firebase calls are no longer embedded in the mobile login form.

## Phase 2 implementation

- Login is now a dedicated screen containing only email and password authentication.
- `AuthTextField`, `PasswordField`, and `AuthSubmitButton` provide reusable form behavior and consistent styling.
- Email and password fields include the correct keyboard actions and autofill hints, while password paste remains enabled.
- The visibility control has explicit show/hide semantics.
- Login validation checks email format and non-empty credentials without applying new-password rules.
- A stable loading state prevents duplicate submissions, and Firebase failures are translated into concise login messages.
- Forgot Password and Sign Up are separate navigation destinations rather than alternate states inside Login.

## Phase 3 implementation

- Sign Up now includes email, password, and confirm-password fields with new-password autofill support.
- Password requirements update immediately for minimum length, uppercase, lowercase, and number rules.
- A four-segment strength indicator provides Weak, Fair, Good, and Strong guidance without replacing the acceptance policy.
- Password and confirmation have independent show/hide controls, and paste remains enabled.
- Confirmation mismatch appears during form interaction, while a positive match message confirms success.
- Create Account remains disabled until profile fields, email, password policy, and confirmation are all valid.
- Submission remains guarded while loading so repeated taps cannot create duplicate requests.

## Phase 4 implementation

- Login and Sign Up both call Firebase exclusively through `AuthService`.
- `AuthErrorMapper` converts Firebase codes into concise, recoverable messages and avoids displaying raw exception details.
- Wrong-password and unknown-account responses use the same neutral login message.
- Successful account creation returns to the root route; `AuthGate` observes the Firebase session and selects the authenticated destination.
- Authentication success remains valid if profile synchronization is temporarily unavailable, allowing the session gate to use safe fallback profile data.
- Loading guards continue to prevent duplicate sign-in and account-creation requests.

## Phase 5 implementation

- Forgot Password validates the email, delegates reset delivery to `AuthService`, prevents repeated submissions, and displays a neutral confirmation after success.
- Unknown-account reset responses use the same neutral confirmation to avoid unnecessary account discovery.
- Firebase authentication-state persistence restores valid signed-in sessions through `AuthGate` after application rebuilds or restarts.
- Sign-out emits a signed-out session, clears the authenticated subtree and selected role, and returns the user to Login.

## Phase 6 implementation

- Authentication forms use explicit widget-order focus traversal and Next/Done keyboard actions.
- Loading labels and progress indicators transition without changing button height or shifting the form layout.
- Password requirements and strength segments animate subtly as validation state changes.
- Visibility controls and live feedback expose descriptive semantics for assistive technologies.
- Error, success, and informational feedback includes an icon and semantic prefix, so meaning never depends on color alone.
- Login, Sign Up, and Forgot Password remain scrollable and constrained for small displays and enlarged text.

## Phase 7 implementation

- `UserAccount` no longer contains a password property; authenticated domain models cannot retain plaintext credentials.
- Older locally saved password values are deleted during Login initialization, while optional remembered email behavior remains.
- Passwords exist only in transient form controllers and are passed directly to Firebase Authentication operations.
- Account settings leave the new-password field empty by default and update a password only when the user explicitly enters a valid replacement.
- Mobile, recovery, profile, and administrator authentication errors avoid raw backend exception details and use neutral credential messages where appropriate.
- `AuthGate` remains the protected-route boundary, and sign-out removes the authenticated application subtree.
- Protected user data continues to require Firebase backend authorization rules; UI validation is treated only as usability guidance.

## Phase 8 implementation

- Automated coverage includes successful contracts, invalid input, wrong credentials, duplicate accounts, weak passwords, mismatch, repeated taps, visibility controls, autofill, session restoration, sign-out, password reset, offline failures, accessibility, and responsive layouts.
- Release verification requires a clean analyzer run, complete test pass, and successful Android packaging.
- `docs/auth_release_checklist.md` separates automated evidence from Firebase-console and physical-device checks that must be completed in the target environment.
