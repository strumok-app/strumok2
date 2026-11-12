import 'dart:io';

import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:content_suppliers_rust/bundle.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../../../core/network/file_downloader.dart';
import '../../../core/platform/app_platform.dart';
import '../domain/ffi_bundle_info.dart';

final _log = Logger('SupplierBundleInstaller');

typedef BundleLoader = Future<ContentSupplierBundle> Function(String directory, String libName);

Future<ContentSupplierBundle> loadRustBundle(String directory, String libName) async {
  final bundle = RustContentSuppliersBundle(directory: directory, libName: libName);
  await bundle.load();
  return bundle;
}

class IncompatibleBundleException implements Exception {
  final FfiBundleInfo info;

  const IncompatibleBundleException(this.info);

  @override
  String toString() => 'Supplier bundle ${info.versionString} is incompatible (major $compatibleBundleMajor required)';
}

class BundleNotAvailableException implements Exception {
  final String? downloadKey;

  const BundleNotAvailableException(this.downloadKey);

  @override
  String toString() => 'No supplier bundle download for "$downloadKey"';
}

/// Downloads and loads supplier bundles in `<appSupport>/ffi` (spec-02 §2.4, spec-11 §11.1).
class SupplierBundleInstaller {
  final http.Client client;
  final Directory directory;
  final AppPlatform platform;
  final String? downloadKey;
  final BundleLoader loader;

  const SupplierBundleInstaller({
    required this.client,
    required this.directory,
    required this.platform,
    required this.downloadKey,
    this.loader = loadRustBundle,
  });

  File fileFor(FfiBundleInfo info) => File(p.join(directory.path, info.fileName(platform)));

  /// Returns the loaded bundle; the downloaded file is removed if loading fails.
  Future<ContentSupplierBundle> install(
    FfiBundleInfo info, {
    DownloadProgressCallback? onProgress,
    DownloadCancelToken? cancelToken,
  }) async {
    if (!info.isCompatible) throw IncompatibleBundleException(info);
    final url = info.downloadUrl[downloadKey];
    if (url == null) throw BundleNotAvailableException(downloadKey);

    final file = fileFor(info);
    await downloadToFile(client, Uri.parse(url), file, onProgress: onProgress, cancelToken: cancelToken);
    try {
      return await loader(directory.path, info.libName);
    } catch (_) {
      await _tryDelete(file);
      rethrow;
    }
  }

  /// Loads an already installed bundle; returns null when its file is missing or it is incompatible.
  Future<ContentSupplierBundle?> loadInstalled(FfiBundleInfo info) async {
    if (!info.isCompatible || !fileFor(info).existsSync()) return null;
    return loader(directory.path, info.libName);
  }

  /// Removes other versions of the same bundle. Files still mapped (Windows) are retried on the next start.
  Future<void> deleteOtherVersions(FfiBundleInfo current) async {
    if (!directory.existsSync()) return;
    final prefix = current.fileNamePrefix(platform);
    final keep = current.fileName(platform);
    await for (final entity in directory.list()) {
      final name = p.basename(entity.path);
      if (entity is File && name.startsWith(prefix) && name != keep) await _tryDelete(entity);
    }
  }

  Future<void> _tryDelete(File file) async {
    try {
      if (file.existsSync()) await file.delete();
    } catch (e) {
      _log.info('Could not delete ${file.path}', e);
    }
  }
}
