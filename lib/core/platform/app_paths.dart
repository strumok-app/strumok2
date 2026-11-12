import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_paths.g.dart';

class AppPaths {
  final Directory support;
  final Directory cache;
  final Directory temp;

  const AppPaths({required this.support, required this.cache, required this.temp});

  static Future<AppPaths> resolve() async => AppPaths(
    support: await getApplicationSupportDirectory(),
    cache: await getApplicationCacheDirectory(),
    temp: await getTemporaryDirectory(),
  );

  /// Supplier bundle install dir (spec-02 §2.4).
  Directory get ffi => Directory(p.join(support.path, 'ffi'));

  /// Android APK download dir; must match `res/xml/provider_paths.xml` (spec-11 §11.2).
  Directory get apkInstall => Directory(p.join(cache.path, 'install'));
}

@Riverpod(keepAlive: true)
AppPaths appPaths(Ref ref) => throw UnimplementedError('appPathsProvider must be overridden in main()');
