import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/core/platform/device_class.dart';

void main() {
  group('classifyAndroid', () {
    test('leanback is tv', () {
      expect(classifyAndroid(systemFeatures: ['android.software.leanback'], shortestSide: 1080), DeviceClass.tv);
    });

    test('live_tv is tv', () {
      expect(classifyAndroid(systemFeatures: ['android.software.live_tv'], shortestSide: 360), DeviceClass.tv);
    });

    test('shortest side decides phone vs tablet', () {
      expect(classifyAndroid(systemFeatures: [], shortestSide: 599), DeviceClass.phone);
      expect(classifyAndroid(systemFeatures: [], shortestSide: 600), DeviceClass.tablet);
    });
  });
}
