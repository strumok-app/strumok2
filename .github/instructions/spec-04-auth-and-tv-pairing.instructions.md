---
description: 'Use when working on Google sign-in, Firebase auth, account menu, TV pairing code (generatecode, exchangecodefortoken cloud functions). Compatibility contract.'
applyTo: 'lib/features/auth/**'
---

# Spec 04 — Authentication and TV pairing (COMPATIBILITY CONTRACT)

## 4.1 Firebase project

- Same Firebase project as the legacy app. Options come from `--dart-define=FIREBASE=<json>` (FirebaseOptions map).
- Firebase local persistence directory: `<applicationSupportDirectory>/firebase` (per profile sub-dir, see spec-05).
- Auth must work on Android, Linux and Windows (FlutterFire lacks Linux → the legacy app used `firebase_dart`).

## 4.2 Google sign-in

Scopes: `https://www.googleapis.com/auth/userinfo.profile`, `https://www.googleapis.com/auth/userinfo.email`.

| Platform | Flow |
|----------|------|
| Android phone/tablet | Native Google Sign-In → `GoogleAuthProvider.credential(accessToken, idToken)` → `FirebaseAuth.signInWithCredential`. |
| Desktop | OAuth installed-app consent in the system browser with loopback redirect (client id/secret JSON from `--dart-define=GOOGLE_AUTH=<json>`) → same Firebase credential exchange. |
| Android TV | **No Google sign-in UI.** TV logs in only via pairing code (§4.3). |

The Firebase user `uid` is the key of `/collection/{uid}`. User display: `displayName`, `photoURL`.
Sign-out: Firebase sign-out + platform sign-out (Android: disconnect).

## 4.3 TV pairing with code — MUST use existing cloud functions unchanged

Endpoint URL builder: `https://{functionName.toLowerCase()}-{CLOUD_FUN_DOMAIN}` where `CLOUD_FUN_DOMAIN`
comes from `--dart-define`. (E.g. `generatecode` → `https://generatecode-<domain>`.)

### Generate code (on an already signed-in device: phone/tablet/desktop)
```
POST https://generatecode-{CLOUD_FUN_DOMAIN}
Authorization: Bearer <Firebase ID token of current user>
(no body)
→ 200 {"code": "AB12CD"}
→ ≥400 on error
```
UI: Settings → "TV" section, item "Connect TV" (signed in, not on TV) → shows the 6-char code in large text with a dismiss button.

### Exchange code (on the TV, or any signed-out device)
```
POST https://exchangecodefortoken-{CLOUD_FUN_DOMAIN}
Content-Type: application/x-www-form-urlencoded
code=AB12CD
→ 200 {"token": "<Firebase custom token>"}
→ ≥400 invalid/expired code
```
Then `FirebaseAuth.signInWithCustomToken(token)`.

Input rules: exactly **6** characters, `[a-zA-Z0-9]`, upper-cased before sending. TV UI: focusable text
field (on-screen keyboard), submit on enter/OK, check button, cancel button; back key moves focus to the
accept button instead of discarding input. Show "invalid code" snackbar on error.

## 4.4 Account UI (account menu)
- Signed out: "Sign in with Google" (not on TV), "Enter TV code" (pairing), offline-mode toggle, Settings.
- Signed in: avatar + name with a "Sign out" icon button right of it, offline-mode toggle, Settings.
  "Connect TV" lives in Settings (spec-09).
- With profiles enabled: current profile on top; "Switch profile" lives in Settings (spec-05).
