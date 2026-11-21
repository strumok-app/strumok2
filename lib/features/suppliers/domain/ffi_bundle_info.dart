import '../../../core/platform/app_platform.dart';
import '../../../core/utils/semver.dart';

/// Only bundles with this major are loadable (spec-02 §2.1).
const compatibleBundleMajor = 5;

/// Supplier bundle metadata (spec-02 §2.4). Persisted as JSON in `ffi_supplier_bundle_info`.
final class FfiBundleInfo {
  final String name;

  /// Raw version string as published; part of the file name.
  final String versionString;
  final SemVer version;
  final String? metadataUrl;
  final Map<String, String> downloadUrl;

  const FfiBundleInfo({
    required this.name,
    required this.versionString,
    required this.version,
    required this.downloadUrl,
    this.metadataUrl,
  });

  factory FfiBundleInfo.fromJson(Map<String, Object?> json) {
    final versionString = json['version'] as String;
    return FfiBundleInfo(
      name: json['name'] as String,
      versionString: versionString,
      version: SemVer.parse(versionString),
      metadataUrl: json['metadataUrl'] as String?,
      downloadUrl: (json['downloadUrl'] as Map? ?? const {}).map((k, v) => MapEntry(k as String, v as String)),
    );
  }

  Map<String, Object?> toJson() => {
    'name': name,
    'version': versionString,
    'metadataUrl': metadataUrl,
    'downloadUrl': downloadUrl,
  };

  bool get isCompatible => version.major == compatibleBundleMajor;

  String get libName => '${name}_$versionString';

  String fileName(AppPlatform platform) => platform == AppPlatform.windows ? '$libName.dll' : 'lib$libName.so';

  /// Prefix shared by every version of this bundle on [platform], used to clean up older files.
  String fileNamePrefix(AppPlatform platform) => platform == AppPlatform.windows ? '${name}_' : 'lib${name}_';
}

/// Key in [FfiBundleInfo.downloadUrl] for this device (spec-02 §2.4 ABI order: x86_64, arm64-v8a, armeabi-v7a).
String? selectBundleDownloadKey(AppPlatform platform, {List<String> androidAbis = const []}) => switch (platform) {
  AppPlatform.linux => 'linux',
  AppPlatform.windows => 'windows',
  AppPlatform.android =>
    androidAbis.contains('x86_64')
        ? 'android-x86_64'
        : androidAbis.contains('arm64-v8a')
        ? 'arm64-v8a'
        : androidAbis.contains('armeabi-v7a')
        ? 'armeabi-v7a'
        : null,
};
