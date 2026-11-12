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
}
