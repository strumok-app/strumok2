import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/core/platform/app_platform.dart';
import 'package:strumok/core/utils/semver.dart';
import 'package:strumok/features/updates/domain/app_release.dart';

const releaseJson = <String, Object?>{
  'name': 'v1.32.0',
  'html_url': 'https://example.com/releases/v1.32.0',
  'tag_name': 'v1.32.0',
  'body': '## What\'s Changed\r\n* Faster startup\r\n',
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
    expect(release.notes, "## What's Changed\n* Faster startup");
    expect(AppRelease.tryParse({...releaseJson, 'body': '  '})!.notes, isNull);
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

  test('selects versioned release assets and prefers them over legacy names', () {
    final release = AppRelease.tryParse({
      'name': 'v2.4.3',
      'assets': [
        {'name': 'app-release.apk', 'browser_download_url': 'legacy-apk'},
        {'name': 'strumok-linux.tar.gz', 'browser_download_url': 'legacy-linux'},
        {'name': 'StrumokSetup.exe', 'browser_download_url': 'legacy-windows'},
        {'name': 'strumok-2.4.3.apk', 'browser_download_url': 'apk'},
        {'name': 'strumok-2.4.3.tar.gz', 'browser_download_url': 'linux'},
        {'name': 'strumok-2.4.3.exe', 'browser_download_url': 'windows'},
      ],
    })!;

    expect(release.assetFor(AppPlatform.android)?.downloadUrl, 'apk');
    expect(release.assetFor(AppPlatform.linux)?.downloadUrl, 'linux');
    expect(release.assetFor(AppPlatform.windows)?.downloadUrl, 'windows');
  });

  test('does not select unrelated assets with matching extensions', () {
    final release = AppRelease.tryParse({
      'name': '2.0.0',
      'assets': [
        {'name': 'checksums.apk.sha256', 'browser_download_url': 'checksum'},
        {'name': 'other.tar.gz', 'browser_download_url': 'archive'},
        {'name': 'uninstaller.exe', 'browser_download_url': 'exe'},
      ],
    })!;

    expect(release.assetFor(AppPlatform.android), isNull);
    expect(release.assetFor(AppPlatform.linux), isNull);
    expect(release.assetFor(AppPlatform.windows), isNull);
  });

  test('round-trips through cache JSON', () {
    final release = AppRelease.tryParse(releaseJson)!;
    final again = AppRelease.tryParse(release.toJson())!;
    expect(again.version, release.version);
    expect(again.notes, release.notes);
    expect(again.assetFor(AppPlatform.windows)?.downloadUrl, 'https://example.com/StrumokSetup.exe');
  });
}
