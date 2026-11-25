import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:strumok/features/player/data/mpv_shaders.dart';
import 'package:strumok/features/player/data/shader_store.dart';
import 'package:strumok/features/player/domain/upscaling.dart';

class _Bundle extends CachingAssetBundle {
  final loads = <String>[];

  @override
  Future<ByteData> load(String key) async {
    loads.add(key);
    return ByteData.sublistView(Uint8List.fromList(utf8.encode('// $key')));
  }
}

void main() {
  group('upscaleOutputSize', () {
    const video = Size(1280, 720);

    test('fits the video into the view (letterbox and pillarbox)', () {
      expect(upscaleOutputSize(const Size(1920, 1200), video), (width: 1920, height: 1080));
      expect(upscaleOutputSize(const Size(3000, 1440), video), (width: 2560, height: 1440));
    });

    test('native size (null) when the view is not larger than the video', () {
      expect(upscaleOutputSize(const Size(1280, 720), video), isNull);
      expect(upscaleOutputSize(const Size(630, 354), video), isNull, reason: 'floating player');
      expect(upscaleOutputSize(const Size(1920, 1080), Size.zero), isNull, reason: 'size not known yet');
    });

    test('long side is capped', () {
      expect(upscaleOutputSize(const Size(7680, 4320), video), (width: 3840, height: 2160));
      expect(upscaleOutputSize(const Size(7680, 4320), video, maxLongSide: 2560), (width: 2560, height: 1440));
    });
  });

  test('every upscaler maps to bundled shader files; unknown ids are off', () {
    for (final upscaler in upscalers) {
      final assets = shaderAssetsOf(upscaler);
      expect(assets, isNotEmpty, reason: upscaler.id);
      for (final asset in assets) {
        expect(File(asset).existsSync(), isTrue, reason: '${upscaler.id}: $asset');
      }
      expect(upscalerById(upscaler.id), same(upscaler));
    }
    expect(upscalerById('artcnn_c4f16'), isNull, reason: 'dropped preset');
    expect(upscalerById(null), isNull);
    expect(
      upscalerById('custom_detail_cas_grain'),
      same(upscalerById('luma_cas_grain')),
      reason: 'the previously persisted id migrates to the renamed preset',
    );
  });

  test('mpvShaderCommands clears, then appends one file each, keeping Windows paths whole', () {
    expect(mpvShaderCommands(const []), [
      ['change-list', 'glsl-shaders', 'clr', ''],
    ]);
    expect(mpvShaderCommands([r'C:\Users\me\AppData\shaders\a.glsl', '/home/me/b.hook']), [
      ['change-list', 'glsl-shaders', 'clr', ''],
      ['change-list', 'glsl-shaders', 'append', r'C:\Users\me\AppData\shaders\a.glsl'],
      ['change-list', 'glsl-shaders', 'append', '/home/me/b.hook'],
    ]);
  });

  test('isShaderFailureLog: shader errors from the renderer only (lines recorded in U0)', () {
    expect(isShaderFailureLog('libmpv_render', 'error', 'compute shader source:'), isTrue);
    expect(isShaderFailureLog('vo/gpu', 'error', 'fragment shader compile log (status=0):'), isTrue);
    expect(
      isShaderFailureLog('libmpv_render', 'error', 'after creating texture: OpenGL error INVALID_OPERATION.'),
      isFalse,
      reason: 'NVIDIA start-up noise, unrelated to shaders',
    );
    expect(isShaderFailureLog('libmpv_render', 'v', "GL_SHADING_LANGUAGE_VERSION='OpenGL ES GLSL ES 3.20'"), isFalse);
    expect(isShaderFailureLog('ffmpeg', 'error', 'shader'), isFalse);
  });

  group('ShaderStore', () {
    late Directory support;
    late _Bundle bundle;

    setUp(() async {
      support = await Directory.systemTemp.createTemp('shader_store_test');
      addTearDown(() => support.delete(recursive: true));
      bundle = _Bundle();
    });

    Upscaler of(String id) => upscalerById(id)!;

    // Mode A (HQ) is kept in the shader manifest but commented out of the catalog, so it is built directly here.
    const anime4kAHq = Upscaler('anime4k_a_hq', UpscalerCost.heavy);

    test('extracts the files of an upscaler in hook order, once', () async {
      final store = ShaderStore(bundle, support, version: 3);
      final files = await store.files(of('anime4k_a_fast'));

      expect(files.map(p.basename), [
        'Anime4K_Clamp_Highlights.glsl',
        'Anime4K_Restore_CNN_M.glsl',
        'Anime4K_Upscale_CNN_x2_M.glsl',
        'Anime4K_AutoDownscalePre_x2.glsl',
        'Anime4K_AutoDownscalePre_x4.glsl',
        'Anime4K_Upscale_CNN_x2_S.glsl',
      ]);
      expect(files.first, p.join(support.path, 'shaders', 'v3', 'anime4k', 'Anime4K_Clamp_Highlights.glsl'));
      expect(File(files.first).readAsStringSync(), '// assets/shaders/anime4k/Anime4K_Clamp_Highlights.glsl');

      bundle.loads.clear();
      expect(await ShaderStore(bundle, support, version: 3).files(of('anime4k_a_fast')), files);
      final shared = await store.files(anime4kAHq);
      expect(bundle.loads, [
        'assets/shaders/anime4k/Anime4K_Restore_CNN_VL.glsl',
        'assets/shaders/anime4k/Anime4K_Upscale_CNN_x2_VL.glsl',
      ], reason: 'files shared between chains are extracted once');
      expect(shared, hasLength(6));
    });

    test('a new catalog version removes other versions and leftover temp files', () async {
      final old = Directory(p.join(support.path, 'shaders', 'v1'))..createSync(recursive: true);
      final leftover = File(p.join(support.path, 'shaders', 'v2', 'anime4k', 'Anime4K_Clamp_Highlights.glsl.123.tmp'))
        ..createSync(recursive: true);

      final files = await ShaderStore(bundle, support, version: 2).files(of('anime4k_a_fast'));

      expect(old.existsSync(), isFalse);
      expect(leftover.existsSync(), isFalse);
      expect(File(files.first).existsSync(), isTrue);
    });
  });
}
