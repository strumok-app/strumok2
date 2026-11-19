---
description: 'Use when working on build config, dart-define secrets, Android/Linux/Windows targets, application id app.strumok, Firebase/Google registration, CI.'
applyTo: 'pubspec.yaml, android/**, linux/**, windows/**, .github/workflows/**'
---

# Spec 10 — Build configuration and secrets

## Compile-time configuration (`--dart-define-from-file=secrets.env`)

| Key | Content | Used by |
|-----|---------|---------|
| `FIREBASE` | JSON FirebaseOptions map (apiKey, appId, projectId, databaseURL, ...) | Firebase init |
| `GOOGLE_AUTH` | JSON OAuth client (installed app) for desktop sign-in | desktop Google sign-in |
| `CLOUD_FUN_DOMAIN` | domain suffix of cloud functions | TV pairing endpoints |
| `FFI_LIB_VERSION_CHECK_URL` | URL of latest supplier bundle JSON | spec-02, spec-11 |
| `APP_VERSION_CHECK_URL` | URL of latest app release JSON | app self-update (spec-11, mandatory) |
| `FORCE_TV_MODE` | `true` to emulate TV on desktop | dev only |
| `FFI_SUPPLIER_LIB_NAME`, `FFI_SUPPLIER_LIBS_DIR` | load a local supplier lib | dev only |

- `secrets.env` and `android/app/google-services.json`, keystores, `keystore.properties` are **git-ignored**.
  CI receives them base64-encoded as secrets and decodes before build.
- Never log secret values. Never hard-code them as fallbacks.
- Removed from the legacy set: `SENTRY_DNS` (Sentry is out of scope).

## Targets

| Target | Artifact |
|--------|----------|
| Android | universal release APK (`arm64-v8a`, `armeabi-v7a`, `x86_64`). **`applicationId = namespace = "app.strumok"`** (new app; see §Application id below). minSdk ≥ 24 (PiP auto-enter needs 31+, guarded). |
| Linux | release bundle tarball; requires system `libmpv`; `APPLICATION_ID "app.strumok"`; `.desktop` file `app.strumok.desktop` + SVG icon `app.strumok.svg` (+ `app.strumok.png` bundled into `data/` as the window icon) |
| Windows | release bundle + installer `StrumokSetup.exe` (asset name must end with `.exe` for self-update) |

Release asset names are part of the self-update contract (spec-11 §11.2): Android `app-release.apk`,
Linux `strumok-linux.tar.gz`, Windows `StrumokSetup.exe`.

## Application id `app.strumok` (new app)

The rewrite is a **new application** (`app.strumok`), installed side by side with the legacy `app.cloud_hook`.
Consequences the setup MUST handle:

- **Firebase**: register a new Android app `app.strumok` in the **same Firebase project** (the same Realtime
  Database, so collection data is shared — spec-03) and use its new `google-services.json`.
- **Google Sign-In**: add the SHA-1/SHA-256 fingerprints of the release (and debug) signing key for `app.strumok`
  in Firebase / Google Cloud OAuth so an Android OAuth client exists for the new package. Firebase uid stays the same
  for the same Google account, so `/collection/{uid}` keeps working.
- **Signing**: a new keystore is allowed (no in-place upgrade exists anyway); keep it stable from the first release on,
  because the self-update (spec-11) requires every later APK to be signed with the same key.
- **No in-place upgrade from the legacy app**: local data (prefs, local DB, downloaded supplier lib, downloads index)
  of `app.cloud_hook` is not accessible on Android. Users re-sign in (or use TV pairing) to get their collection
  from Firebase. Optionally, the last legacy release can show a "move to the new app" notice — out of scope here.
- FileProvider authority becomes `app.strumok.fileProvider` (`${applicationId}.fileProvider`).

## Commands (to be verified in the new repo and recorded in README)

```bash
flutter pub get
dart run build_runner build -d
flutter gen-l10n
flutter analyze
flutter test
flutter run -d linux   --dart-define-from-file=secrets.env
flutter run -d linux   --dart-define-from-file=secrets.env --dart-define=FORCE_TV_MODE=true
flutter build apk      --release --dart-define-from-file=secrets.env
flutter build linux    --release --dart-define-from-file=secrets.env
flutter build windows  --release --dart-define-from-file=secrets.env
```
