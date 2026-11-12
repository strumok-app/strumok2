import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/file_downloader.dart';
import '../../../core/network/http_client.dart';
import '../../../core/platform/app_paths.dart';
import '../../../core/platform/app_platform.dart';
import '../domain/app_release.dart';

part 'app_installer.g.dart';

final _log = Logger('AppInstaller');

class AppInstallFailedException implements Exception {
  final String reason;

  const AppInstallFailedException(this.reason);

  @override
  String toString() => 'App install failed: $reason';
}

class NoReleaseAssetException implements Exception {
  const NoReleaseAssetException();

  @override
  String toString() => 'Release has no asset for this platform';
}

/// Platform-specific self-update flow (spec-11 §11.2).
abstract interface class AppInstaller {
  /// Whether [install] downloads a file (progress/cancel are meaningful).
  bool get downloads;

  Future<void> install(
    AppRelease release,
    ReleaseAsset asset, {
    DownloadProgressCallback? onProgress,
    DownloadCancelToken? cancelToken,
  });
}

class AndroidApkInstaller implements AppInstaller {
  static const channel = MethodChannel('install_apk');

  final http.Client client;
  final Directory installDir;

  const AndroidApkInstaller(this.client, this.installDir);

  @override
  bool get downloads => true;

  @override
  Future<void> install(
    AppRelease release,
    ReleaseAsset asset, {
    DownloadProgressCallback? onProgress,
    DownloadCancelToken? cancelToken,
  }) async {
    if (installDir.existsSync()) await installDir.delete(recursive: true);
    final apk = File(p.join(installDir.path, '${release.version}.apk'));
    await downloadToFile(client, Uri.parse(asset.downloadUrl), apk, onProgress: onProgress, cancelToken: cancelToken);
    final launched = await channel.invokeMethod<bool>('installApk', {'filePath': apk.path});
    if (launched != true) throw const AppInstallFailedException('installer was not launched');
  }
}

class WindowsSetupInstaller implements AppInstaller {
  final http.Client client;
  final Directory tempDir;

  const WindowsSetupInstaller(this.client, this.tempDir);

  @override
  bool get downloads => true;

  @override
  Future<void> install(
    AppRelease release,
    ReleaseAsset asset, {
    DownloadProgressCallback? onProgress,
    DownloadCancelToken? cancelToken,
  }) async {
    final setup = File(p.join(tempDir.path, 'strumok_update', 'StrumokSetup-${release.version}.exe'));
    await downloadToFile(client, Uri.parse(asset.downloadUrl), setup, onProgress: onProgress, cancelToken: cancelToken);
    await Process.start(setup.path, const [], mode: ProcessStartMode.detached);
    _log.info('Installer started, exiting so files can be replaced');
    exit(0);
  }
}

class LinuxLinkInstaller implements AppInstaller {
  const LinuxLinkInstaller();

  @override
  bool get downloads => false;

  @override
  Future<void> install(
    AppRelease release,
    ReleaseAsset asset, {
    DownloadProgressCallback? onProgress,
    DownloadCancelToken? cancelToken,
  }) async {
    final opened = await launchUrl(Uri.parse(asset.downloadUrl), mode: LaunchMode.externalApplication);
    if (!opened) throw const AppInstallFailedException('could not open the download link');
  }
}

@Riverpod(keepAlive: true)
AppInstaller appInstaller(Ref ref) => switch (AppPlatform.current) {
  AppPlatform.android => AndroidApkInstaller(ref.watch(httpClientProvider), ref.watch(appPathsProvider).apkInstall),
  AppPlatform.windows => WindowsSetupInstaller(ref.watch(httpClientProvider), ref.watch(appPathsProvider).temp),
  AppPlatform.linux => const LinuxLinkInstaller(),
};
