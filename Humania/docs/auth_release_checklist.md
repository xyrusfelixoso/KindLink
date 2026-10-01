# Authentication release checklist

## Automated verification

- [x] Login succeeds through the authentication service contract.
- [x] Account creation succeeds through the authentication service contract.
- [x] Empty and invalid email fields are rejected before network requests.
- [x] Wrong credentials use a neutral message.
- [x] Duplicate email, weak password, mismatch, network failure, and rate limiting have recoverable messages.
- [x] Rapid repeated submissions issue only one request.
- [x] Password reveal and hide controls operate independently.
- [x] Password fields permit interactive selection and paste.
- [x] Login and new-password autofill hints are configured.
- [x] Signed-in sessions restore through AuthGate after an application rebuild.
- [x] Signed-out session events return to Login.
- [x] Password reset validates email and uses a neutral confirmation.
- [x] Login, Sign Up, and Forgot Password fit a 320 by 568 display at 150 percent text scale.
- [x] Static analysis reports no issues.
- [x] Android debug packaging completes successfully.

## Security verification

- [x] UserAccount does not store passwords.
- [x] Legacy locally stored passwords are deleted.
- [x] Authentication screens do not display raw Firebase exception details.
- [x] AuthGate protects the signed-in application subtree.
- [ ] Review and deploy Firebase Authentication settings, Realtime Database rules, and Firestore rules in the Firebase project console.

## Device and service checks before production

- [ ] Test login, account creation, password reset, restart, and logout against the production Firebase project.
- [ ] Verify reset-email templates, sender identity, and authorized domains.
- [ ] Test password-manager generated-password behavior on a physical Android device.
- [ ] Test offline recovery and slow-network behavior on a physical Android device.
- [ ] Confirm administrator permissions with both authorized and unauthorized accounts.
