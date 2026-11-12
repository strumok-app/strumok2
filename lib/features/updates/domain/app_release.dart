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
  final String? htmlUrl;

  const AppRelease({required this.name, required this.version, required this.assets, this.htmlUrl});

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
    final htmlUrl = json['html_url'];
    return AppRelease(name: name, version: version, assets: assets, htmlUrl: htmlUrl is String ? htmlUrl : null);
  }

  Map<String, Object?> toJson() => {
    'name': name,
    'html_url': htmlUrl,
    'assets': [
      for (final a in assets) {'name': a.name, 'browser_download_url': a.downloadUrl},
    ],
  };

  ReleaseAsset? assetFor(AppPlatform platform) {
    bool matches(ReleaseAsset a) => switch (platform) {
      AppPlatform.android => a.name.contains('app-release.apk'),
      AppPlatform.windows => a.name.endsWith('.exe'),
      AppPlatform.linux => a.name.contains('linux'),
    };
    for (final asset in assets) {
      if (matches(asset)) return asset;
    }
    return null;
  }
}
