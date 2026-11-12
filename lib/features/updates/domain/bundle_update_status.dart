import '../../suppliers/domain/ffi_bundle_info.dart';

enum BundleUpdateStatus { unknown, upToDate, updateAvailable, appUpdateRequired }

/// A newer bundle with another major is never offered; it requires an app update (spec-11 §11.1).
BundleUpdateStatus bundleUpdateStatus({required FfiBundleInfo? installed, required FfiBundleInfo? latest}) {
  if (latest == null) return BundleUpdateStatus.unknown;
  if (installed != null && !(latest.version > installed.version)) return BundleUpdateStatus.upToDate;
  return latest.isCompatible ? BundleUpdateStatus.updateAvailable : BundleUpdateStatus.appUpdateRequired;
}
