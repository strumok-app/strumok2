/// Compile-time configuration from `--dart-define-from-file=secrets.env` (spec-10).
abstract final class AppConfig {
  static const ffiLibVersionCheckUrl = String.fromEnvironment('FFI_LIB_VERSION_CHECK_URL');
  static const appVersionCheckUrl = String.fromEnvironment('APP_VERSION_CHECK_URL');

  /// Dev only: load a local supplier lib and bypass the startup guard (spec-02 §2.4).
  static const ffiSupplierLibsDir = String.fromEnvironment('FFI_SUPPLIER_LIBS_DIR');
  static const ffiSupplierLibName = String.fromEnvironment(
    'FFI_SUPPLIER_LIB_NAME',
    defaultValue: 'content_suppliers_rust',
  );

  static bool get hasDevSupplierLib => ffiSupplierLibsDir.isNotEmpty;

  /// FirebaseOptions JSON map (spec-04 §4.1). Empty disables accounts and sync.
  static const firebaseOptions = String.fromEnvironment('FIREBASE');

  /// Desktop OAuth installed-app client JSON (`identifier`, `secret`) for Google sign-in (spec-04 §4.2).
  static const googleAuthClient = String.fromEnvironment('GOOGLE_AUTH');

  /// Cloud functions domain suffix for TV pairing (spec-04 §4.3).
  static const cloudFunDomain = String.fromEnvironment('CLOUD_FUN_DOMAIN');
}
