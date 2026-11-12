import 'dart:io';
import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'device_class.g.dart';

enum DeviceClass { phone, tablet, tv, desktop }

const _forceTvMode = bool.fromEnvironment('FORCE_TV_MODE');
const _tabletShortestSide = 600.0;

/// Computed once at startup; overridden on the root `ProviderScope`.
@Riverpod(keepAlive: true)
DeviceClass deviceClass(Ref ref) => throw UnimplementedError('deviceClassProvider must be overridden in main()');

Future<DeviceClass> detectDeviceClass() async {
  if (_forceTvMode) return DeviceClass.tv;
  if (Platform.isLinux || Platform.isWindows) return DeviceClass.desktop;

  final info = await DeviceInfoPlugin().androidInfo;
  return classifyAndroid(systemFeatures: info.systemFeatures, shortestSide: _currentShortestSide());
}

DeviceClass classifyAndroid({required List<String> systemFeatures, required double shortestSide}) {
  if (systemFeatures.contains('android.software.leanback') || systemFeatures.contains('android.software.live_tv')) {
    return DeviceClass.tv;
  }
  return shortestSide >= _tabletShortestSide ? DeviceClass.tablet : DeviceClass.phone;
}

double _currentShortestSide() {
  final display = PlatformDispatcher.instance.displays.first;
  return display.size.shortestSide / display.devicePixelRatio;
}
