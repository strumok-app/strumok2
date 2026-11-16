import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';

import 'app_platform.dart';

part 'device_levels.g.dart';

/// Screen brightness for this app only (0..1); [reset] returns to the system level.
abstract interface class BrightnessControl {
  Future<double> get();
  Future<void> set(double value);
  Future<void> reset();
}

/// System media volume (0..1).
abstract interface class VolumeControl {
  Future<double> get();
  Future<void> set(double value);
}

class AndroidBrightnessControl implements BrightnessControl {
  const AndroidBrightnessControl();

  @override
  Future<double> get() => ScreenBrightness.instance.application;

  @override
  Future<void> set(double value) => ScreenBrightness.instance.setApplicationScreenBrightness(value);

  @override
  Future<void> reset() => ScreenBrightness.instance.resetApplicationScreenBrightness();
}

class AndroidVolumeControl implements VolumeControl {
  AndroidVolumeControl() {
    // The player shows its own indicator.
    VolumeController.instance.showSystemUI = false;
  }

  @override
  Future<double> get() => VolumeController.instance.getVolume();

  @override
  Future<void> set(double value) => VolumeController.instance.setVolume(value);
}

/// Desktop/TV: gestures are not offered there; values stay at full.
class NoBrightnessControl implements BrightnessControl {
  const NoBrightnessControl();

  @override
  Future<double> get() async => 1;

  @override
  Future<void> set(double value) async {}

  @override
  Future<void> reset() async {}
}

class NoVolumeControl implements VolumeControl {
  const NoVolumeControl();

  @override
  Future<double> get() async => 1;

  @override
  Future<void> set(double value) async {}
}

@Riverpod(keepAlive: true)
BrightnessControl brightnessControl(Ref ref) =>
    AppPlatform.current == AppPlatform.android ? const AndroidBrightnessControl() : const NoBrightnessControl();

@Riverpod(keepAlive: true)
VolumeControl volumeControl(Ref ref) =>
    AppPlatform.current == AppPlatform.android ? AndroidVolumeControl() : const NoVolumeControl();
