import 'dart:io';

enum AppPlatform {
  android,
  linux,
  windows;

  static AppPlatform get current {
    if (Platform.isAndroid) return android;
    if (Platform.isWindows) return windows;
    if (Platform.isLinux) return linux;
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }
}
