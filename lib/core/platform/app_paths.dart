import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_paths.g.dart';

class AppPaths {
  final Directory support;
  final Directory cache;
  final Directory temp;

  /// Offline downloads folder unless the user picks another one (desktop only, spec-08 §8.3).
  final Directory defaultDownloads;

  AppPaths({required this.support, required this.cache, required this.temp, Directory? defaultDownloads})
    : defaultDownloads = defaultDownloads ?? Directory(p.join(support.path, 'offline'));

  static Future<AppPaths> resolve() async {
    final (support, cache, temp) = await (
      getApplicationSupportDirectory(),
      getApplicationCacheDirectory(),
      getTemporaryDirectory(),
    ).wait;
    return AppPaths(support: support, cache: cache, temp: temp, defaultDownloads: await _defaultDownloads());
  }

  /// Desktop: `<Downloads>/strumok`; Android: app-specific external storage `/strumok` (no storage permission;
  /// removed with the app), falling back to the app documents folder.
  static Future<Directory> _defaultDownloads() async {
    Directory? base;
    try {
      base = Platform.isAndroid ? await getExternalStorageDirectory() : await getDownloadsDirectory();
    } catch (_) {
      base = null;
    }
    base ??= await getApplicationDocumentsDirectory();
    return Directory(p.join(base.path, 'strumok'));
  }

  /// Supplier bundle install dir (spec-02 §2.4).
  Directory get ffi => Directory(p.join(support.path, 'ffi'));

  /// Android APK download dir; must match `res/xml/provider_paths.xml` (spec-11 §11.2).
  Directory get apkInstall => Directory(p.join(cache.path, 'install'));

  /// Persistent download queue (spec-08 §8.1); shared by the app and the Android download service.
  File get downloadQueue => File(p.join(support.path, 'downloads', 'queue.json'));
}

@Riverpod(keepAlive: true)
AppPaths appPaths(Ref ref) => throw UnimplementedError('appPathsProvider must be overridden in main()');
