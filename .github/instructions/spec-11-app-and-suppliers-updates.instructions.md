---
description: 'Use when working on app self-update (APK install, Windows installer, Linux link) or supplier library install/update/hot-swap, update checks. Mandatory.'
applyTo: 'lib/features/updates/**, lib/features/suppliers/**'
---

# Spec 11 — App self-update and supplier library install/update (MANDATORY)

Both mechanisms are **mandatory**: the app is distributed outside app stores (GitHub/Codeberg releases, APK
side-loading on Android/Android TV), so without them users get stuck on old versions and have no content.
Both use the shared download manager (spec-08) but **do not count** toward the content-download concurrency
limit and are never queued behind content downloads.

## 11.1 Supplier library — install, update, hot reload

Format and file naming are defined in [spec-02-content-suppliers-ffi.instructions.md](spec-02-content-suppliers-ffi.instructions.md). This section defines the
required user flows.

### First install (startup guard) — MUST
- On startup, if no bundle is installed, the file is missing, or `version.major != 4`, the app shows a
  full-screen **install** prompt instead of the shell (except when `FFI_SUPPLIER_LIBS_DIR` is defined — dev bypass).
- The prompt fetches latest info from `FFI_LIB_VERSION_CHECK_URL`, shows the version and an **Install** button
  (autofocused for TV), progress bar, and on error a localized message + **Retry**.
- After a successful install the shell appears without restarting the app.

### Update — MUST
- Check for a newer bundle on startup (non-blocking, at most once per 12 h, plus manual check in Settings).
- If `latest.version > installed.version` and `latest.version.major == 4`: show a non-blocking notice
  (badge on the account/settings entry + snackbar once per version) and an **Update** action in Settings.
- If the latest bundle has a **different major**: do not offer it; show "app update required" pointing to §11.2.
- Update flow:
  1. Download to `<appSupport>/ffi/<fileName>.part`, then atomically rename to the final name.
  2. Load the new bundle in-process. On load failure: delete the new file, keep the old bundle active, show error.
  3. On success: swap the active bundle in the supplier registry, persist `ffi_supplier_bundle_info`,
     invalidate all supplier-dependent providers (home, search, details caches, supplier settings), then unload the
     previous library and delete older files with the same `name`.
- **Hot reload, no app restart.** If the player or a download is using the old bundle, finish swapping only after
  the current operation re-resolves through the registry (never `dlclose` a library with in-flight calls —
  defer unloading of the old library until the next app start if needed).
- Android ABI selection order: `x86_64` → `android-x86_64`, `arm64-v8a`, `armeabi-v7a`.

## 11.2 App self-update — MUST

### Release metadata
`APP_VERSION_CHECK_URL` returns a GitHub-releases-"latest"-compatible JSON (keep this format):

```json
{
  "name": "v1.32.0",
  "assets": [
    { "name": "app-release.apk",        "browser_download_url": "https://.../app-release.apk" },
    { "name": "strumok-linux.tar.gz",   "browser_download_url": "https://.../strumok-linux.tar.gz" },
    { "name": "StrumokSetup.exe",       "browser_download_url": "https://.../StrumokSetup.exe" }
  ]
}
```

- Latest version = semver parsed from `name` (leading `v` allowed). Current version = app package version
  (`pubspec.yaml` `version`, via platform package info).
- Ignore unknown fields; if parsing fails, treat as "no update" and log.

### Checking — MUST
- On startup (non-blocking, at most once per 12 h) and on demand from Settings → "Check for update".
- If newer: badge on the account/settings entry, a one-time-per-version dialog/snackbar ("New version X available"
  with **Update** / **Later**), and the Settings version section shows current → latest with an **Update** button.
- Never install without explicit user action.

### Installing per platform — MUST

| Platform | Asset match | Flow |
|----------|-------------|------|
| Android (phone/tablet/TV) | name contains `app-release.apk` | Download to `<cacheDir>/install/<version>.apk` (delete other files in that dir first) with progress → invoke native installer. |
| Windows | name ends with `.exe` | Download installer to temp dir with progress → launch it (`Process.start`, detached) → exit the app so files can be replaced. |
| Linux | name contains `linux` | Open `browser_download_url` in the system browser (installation methods vary: tarball, distro packages). Show the release notes link. |

Android native installer contract (keep names for continuity):
- MethodChannel **`install_apk`**, method **`installApk`** with argument `{ "filePath": "<abs path>" }` → returns `bool`.
- Native side: `Intent.ACTION_VIEW` with `FileProvider` URI, authority `${applicationId}.fileProvider`,
  MIME `application/vnd.android.package-archive`, flags `NEW_TASK | GRANT_READ_URI_PERMISSION`.
- `res/xml/provider_paths.xml`: `<cache-path name="install" path="install/"/>`.
- Manifest: `REQUEST_INSTALL_PACKAGES` permission and the `androidx.core.content.FileProvider` provider.
- Before launching, if `PackageManager.canRequestPackageInstalls()` is false, open
  `Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES` for the app and resume the install after the user returns.
- Every APK must keep `applicationId app.strumok` and be signed with the same key as the installed one,
  otherwise Android rejects the update. (Self-update cannot migrate users from the legacy `app.cloud_hook`.)

### UX
- Progress (percentage), cancel, localized errors (`appUpdateFailed`, …) with **Retry**; all focusable on TV.
- Update check failures are silent on startup (logged), visible only when the user checks manually.

## 11.3 Tests
- Semver parsing/comparison (`v` prefix, missing parts).
- Asset selection per platform, bundle URL selection per ABI.
- Supplier update state machine: success, download failure, load failure (old bundle stays active), incompatible major.
- Update-check throttling (fake clock).
