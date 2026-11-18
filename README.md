# Strumok

Ad-free media app for movies, series, anime and manga on Android (phone, tablet, TV), Linux and Windows.

## Setup

Flutter is pinned via [fvm](https://fvm.app) (`.fvmrc`); prefix commands with `fvm` if Flutter is not global.
Copy `secrets.env.example` to `secrets.env` (git-ignored) and fill in values.

```bash
flutter pub get
dart run build_runner build -d
flutter gen-l10n
dart format lib test && flutter analyze && flutter test
flutter run -d linux --dart-define-from-file=secrets.env [--dart-define=FORCE_TV_MODE=true]
flutter build apk --release --dart-define-from-file=secrets.env
flutter build linux --release --dart-define-from-file=secrets.env
flutter build windows --release --dart-define-from-file=secrets.env
```

Linux requires system `libmpv`. Android release signing reads `android/keystore.properties`
(`storeFile`, `storePassword`, `keyAlias`, `keyPassword`; git-ignored).

Accounts and collection sync need `FIREBASE` (FirebaseOptions JSON) and `CLOUD_FUN_DOMAIN` (TV pairing);
desktop Google sign-in needs `GOOGLE_AUTH` (`{"identifier": ..., "secret": ...}` installed-app OAuth client).
Without them the app runs with local-only collections. Android Google sign-in additionally needs
`android/app/google-services.json` for `app.strumok` (git-ignored; the build skips the Google Services plugin
when it is missing). The SHA-1/SHA-256 of every signing key (debug keystore and release
`strumok-release.jks`) must be registered on the `app.strumok` Firebase Android app, then the JSON re-downloaded;
otherwise sign-in fails with `UNREGISTERED_ON_API_CONSOLE` / `Account reauth failed` in logcat:
`firebase apps:android:sha:create <appId> <sha> --project cloud-hook-b1106`.
Each profile keeps its own Firebase session under `<appSupport>/firebase/<profileId>`. On desktop only one app
instance runs at a time (lock in `<appSupport>/instance.lock`); starting another brings the running window to the
front.

Downloads go to `<Downloads>/strumok` on desktop (changeable in Settings) and to app-specific storage
(`Android/data/app.strumok/files/strumok`, removed with the app) on Android; the queue is kept in
`<appSupport>/downloads/queue.json`. On Android they run in a `dataSync` foreground service
(`flutter_foreground_task`) with its own Dart isolate, so they continue after the app is closed.

## Supplier bridge (FFI)

`packages/content_suppliers_rust` holds the FRB contract crate and generated Dart bindings
(codegen `2.12.0`, content hash `-1122641696`, API major `4`). Do not edit them.
Smoke test against the dummy supplier:

```bash
cd packages/content_suppliers_rust
(cd rust && cargo build --release)
dart test
```
