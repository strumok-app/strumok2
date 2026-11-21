import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/features/suppliers/domain/ffi_bundle_info.dart';
import 'package:strumok/features/updates/domain/bundle_update_status.dart';
import 'package:strumok/features/updates/domain/update_check.dart';

FfiBundleInfo info(String version) =>
    FfiBundleInfo.fromJson({'name': 'strumok_suppliers', 'version': version, 'downloadUrl': <String, Object?>{}});

void main() {
  group('isUpdateCheckDue', () {
    final now = DateTime(2026, 1, 1, 12);

    test('never checked', () => expect(isUpdateCheckDue(null, now), isTrue));
    test('within 12 h', () => expect(isUpdateCheckDue(now.subtract(const Duration(hours: 11)), now), isFalse));
    test('after 12 h', () => expect(isUpdateCheckDue(now.subtract(const Duration(hours: 12)), now), isTrue));
    test('clock moved back', () => expect(isUpdateCheckDue(now.add(const Duration(hours: 1)), now), isTrue));
  });

  group('bundleUpdateStatus', () {
    test('unknown without latest', () {
      expect(bundleUpdateStatus(installed: info('5.0.0'), latest: null), BundleUpdateStatus.unknown);
    });

    test('up to date', () {
      expect(bundleUpdateStatus(installed: info('5.3.0'), latest: info('5.3.0')), BundleUpdateStatus.upToDate);
      expect(bundleUpdateStatus(installed: info('5.3.0'), latest: info('5.2.0')), BundleUpdateStatus.upToDate);
    });

    test('newer compatible', () {
      expect(bundleUpdateStatus(installed: info('5.3.0'), latest: info('v5.4.0')), BundleUpdateStatus.updateAvailable);
      expect(bundleUpdateStatus(installed: null, latest: info('5.4.0')), BundleUpdateStatus.updateAvailable);
    });

    test('newer incompatible major requires app update', () {
      expect(bundleUpdateStatus(installed: info('5.3.0'), latest: info('6.0.0')), BundleUpdateStatus.appUpdateRequired);
      expect(bundleUpdateStatus(installed: null, latest: info('6.0.0')), BundleUpdateStatus.appUpdateRequired);
    });
  });
}
