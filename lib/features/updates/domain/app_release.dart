import '../../../core/platform/app_platform.dart';
import '../../../core/utils/semver.dart';

final class ReleaseAsset {
  final String name;
  final String downloadUrl;

  const ReleaseAsset({required this.name, required this.downloadUrl});
}

/// GitHub "latest release"-compatible metadata from `APP_VERSION_CHECK_URL` (spec-11 §11.2).
final class AppRelease {
  final String name;
  final SemVer version;
  final List<ReleaseAsset> assets;

  /// Release description (GitHub `body`), shown as "what's new".
  final String? notes;

  const AppRelease({required this.name, required this.version, required this.assets, this.notes});

  /// Returns null when the JSON is not a valid release; unknown fields are ignored.
  static AppRelease? tryParse(Map<String, Object?> json) {
    final name = json['name'];
    if (name is! String) return null;
    final version = SemVer.tryParse(name);
    if (version == null) return null;

    final assets = <ReleaseAsset>[
      for (final asset in json['assets'] as List? ?? const [])
        if (asset is Map && asset['name'] is String && asset['browser_download_url'] is String)
          ReleaseAsset(name: asset['name'] as String, downloadUrl: asset['browser_download_url'] as String),
    ];
    final body = json['body'];
    final notes = body is String ? body.replaceAll('\r\n', '\n').trim() : '';
    return AppRelease(name: name, version: version, assets: assets, notes: notes.isEmpty ? null : notes);
  }

  Map<String, Object?> toJson() => {
    'name': name,
    'body': notes,
    'assets': [
      for (final a in assets) {'name': a.name, 'browser_download_url': a.downloadUrl},
    ],
  };

  ReleaseAsset? assetFor(AppPlatform platform) {
    final versionedName = RegExp(
      r'^strumok-\d+\.\d+\.\d+(?:-[0-9a-z.-]+)?(?:\+[0-9a-z.-]+)?\.(?:apk|tar\.gz|exe)$',
      caseSensitive: false,
    );

    bool matches(ReleaseAsset asset) {
      final name = asset.name.toLowerCase();
      final isVersioned = versionedName.hasMatch(name);
      return switch (platform) {
        AppPlatform.android => isVersioned && name.endsWith('.apk') || name == 'app-release.apk',
        AppPlatform.linux =>
          isVersioned && name.endsWith('.tar.gz') || name.contains('linux') && name.endsWith('.tar.gz'),
        AppPlatform.windows => isVersioned && name.endsWith('.exe') || name == 'strumoksetup.exe',
      };
    }

    bool isPreferred(ReleaseAsset asset) {
      final name = asset.name.toLowerCase();
      return switch (platform) {
        AppPlatform.android => name == 'strumok-$version.apk',
        AppPlatform.linux => name == 'strumok-$version.tar.gz',
        AppPlatform.windows => name == 'strumok-$version.exe',
      };
    }

    for (final asset in assets) {
      if (matches(asset) && isPreferred(asset)) return asset;
    }
    for (final asset in assets) {
      if (matches(asset)) return asset;
    }
    return null;
  }
}
