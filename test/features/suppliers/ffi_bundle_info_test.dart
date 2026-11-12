import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/core/platform/app_platform.dart';
import 'package:strumok/core/utils/semver.dart';
import 'package:strumok/features/suppliers/domain/ffi_bundle_info.dart';

FfiBundleInfo loadFixture() => FfiBundleInfo.fromJson(
  (jsonDecode(File('test/fixtures/ffi_bundle_info.json').readAsStringSync()) as Map).cast<String, Object?>(),
);

void main() {
  test('fixture parses and round-trips', () {
    final info = loadFixture();
    expect(info.name, 'strumok_suppliers');
    expect(info.version, const SemVer(4, 3, 0));
    expect(info.isCompatible, isTrue);
    expect(info.downloadUrl, hasLength(5));

    final again = FfiBundleInfo.fromJson(jsonDecode(jsonEncode(info.toJson())) as Map<String, Object?>);
    expect(again.toJson(), info.toJson());
  });

  test('file naming per platform (spec-02 §2.4)', () {
    final info = loadFixture();
    expect(info.libName, 'strumok_suppliers_4.3.0');
    expect(info.fileName(AppPlatform.linux), 'libstrumok_suppliers_4.3.0.so');
    expect(info.fileName(AppPlatform.android), 'libstrumok_suppliers_4.3.0.so');
    expect(info.fileName(AppPlatform.windows), 'strumok_suppliers_4.3.0.dll');
  });

  test('leading v is kept in the file name but ignored for the version', () {
    final info = FfiBundleInfo.fromJson({'name': 'n', 'version': 'v5.0.1', 'downloadUrl': <String, Object?>{}});
    expect(info.libName, 'n_v5.0.1');
    expect(info.version, const SemVer(5, 0, 1));
    expect(info.isCompatible, isFalse);
  });

  group('download key', () {
    test('desktop', () {
      expect(selectBundleDownloadKey(AppPlatform.linux), 'linux');
      expect(selectBundleDownloadKey(AppPlatform.windows), 'windows');
    });

    test('android ABI order: x86_64, arm64-v8a, armeabi-v7a', () {
      expect(
        selectBundleDownloadKey(AppPlatform.android, androidAbis: ['arm64-v8a', 'x86_64', 'armeabi-v7a']),
        'android-x86_64',
      );
      expect(selectBundleDownloadKey(AppPlatform.android, androidAbis: ['armeabi-v7a', 'arm64-v8a']), 'arm64-v8a');
      expect(selectBundleDownloadKey(AppPlatform.android, androidAbis: ['armeabi-v7a', 'armeabi']), 'armeabi-v7a');
      expect(selectBundleDownloadKey(AppPlatform.android, androidAbis: ['mips']), isNull);
    });
  });
}
