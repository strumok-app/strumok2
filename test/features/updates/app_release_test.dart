import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/core/platform/app_platform.dart';
import 'package:strumok/core/utils/semver.dart';
import 'package:strumok/features/updates/domain/app_release.dart';

const releaseJson = <String, Object?>{
  'name': 'v1.32.0',
  'html_url': 'https://example.com/releases/v1.32.0',
  'tag_name': 'v1.32.0',
  'assets': [
    {'name': 'app-release.apk', 'browser_download_url': 'https://example.com/app-release.apk', 'size': 1},
    {'name': 'strumok-linux.tar.gz', 'browser_download_url': 'https://example.com/strumok-linux.tar.gz'},
    {'name': 'StrumokSetup.exe', 'browser_download_url': 'https://example.com/StrumokSetup.exe'},
  ],
};

void main() {
  test('parses GitHub latest-release JSON, ignoring unknown fields', () {
    final release = AppRelease.tryParse(releaseJson)!;
    expect(release.version, const SemVer(1, 32, 0));
    expect(release.assets, hasLength(3));
    expect(release.htmlUrl, 'https://example.com/releases/v1.32.0');
  });

  test('invalid metadata yields null', () {
    expect(AppRelease.tryParse({'name': 'nightly'}), isNull);
    expect(AppRelease.tryParse({'assets': <Object>[]}), isNull);
  });

  test('asset selection per platform', () {
    final release = AppRelease.tryParse(releaseJson)!;
    expect(release.assetFor(AppPlatform.android)?.name, 'app-release.apk');
    expect(release.assetFor(AppPlatform.linux)?.name, 'strumok-linux.tar.gz');
    expect(release.assetFor(AppPlatform.windows)?.name, 'StrumokSetup.exe');

    final apkOnly = AppRelease.tryParse({
      'name': '1.0.0',
      'assets': [
        {'name': 'app-release.apk', 'browser_download_url': 'u'},
      ],
    })!;
    expect(apkOnly.assetFor(AppPlatform.windows), isNull);
  });

  test('round-trips through cache JSON', () {
    final release = AppRelease.tryParse(releaseJson)!;
    final again = AppRelease.tryParse(release.toJson())!;
    expect(again.version, release.version);
    expect(again.assetFor(AppPlatform.windows)?.downloadUrl, 'https://example.com/StrumokSetup.exe');
  });
}
