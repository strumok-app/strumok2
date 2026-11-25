import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/platform/app_paths.dart';
import '../domain/upscaling.dart';
import 'mpv_shaders.dart';

part 'shader_store.g.dart';

final _log = Logger('ShaderStore');

/// Copies upscaler shaders from the app bundle to real files, which mpv needs (spec-13 §13.4): on first use, into
/// `<support>/shaders/v<version>/<family>/<file>`. A file is written under a temporary name and renamed, so an
/// existing file is always complete; folders of other catalog versions are removed.
class ShaderStore {
  final AssetBundle _bundle;
  final Directory _root;
  final int version;
  final _random = Random();
  Future<void>? _cleanup;

  ShaderStore(this._bundle, Directory support, {this.version = shaderCatalogVersion})
    : _root = Directory(p.join(support.path, 'shaders'));

  Directory get _current => Directory(p.join(_root.path, 'v$version'));

  /// Absolute paths of [upscaler]'s shader files, in hook order.
  Future<List<String>> files(Upscaler upscaler) async {
    await (_cleanup ??= _removeStale());
    return [for (final asset in shaderAssetsOf(upscaler)) await _extract(asset)];
  }

  Future<String> _extract(String asset) async {
    final relative = p.posix.split(p.posix.relative(asset, from: 'assets/shaders'));
    final file = File(p.joinAll([_current.path, ...relative]));
    if (await file.exists()) return file.path;
    await file.parent.create(recursive: true);
    final data = await _bundle.load(asset);
    final temp = File('${file.path}.${_random.nextInt(1 << 32)}.tmp');
    await temp.writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), flush: true);
    try {
      await temp.rename(file.path);
    } on FileSystemException {
      // Another extraction of the same file won the race.
      if (!await file.exists()) rethrow;
      await temp.delete();
    }
    return file.path;
  }

  Future<void> _removeStale() async {
    if (!await _root.exists()) return;
    await for (final entry in _root.list()) {
      try {
        if (entry.path != _current.path) {
          await entry.delete(recursive: true);
        } else if (entry is Directory) {
          await for (final file in entry.list(recursive: true)) {
            if (file is File && file.path.endsWith('.tmp')) await file.delete();
          }
        }
      } on FileSystemException catch (e) {
        _log.warning('Could not remove ${entry.path}', e);
      }
    }
  }
}

@Riverpod(keepAlive: true)
ShaderStore shaderStore(Ref ref) => ShaderStore(rootBundle, ref.watch(appPathsProvider).support);
