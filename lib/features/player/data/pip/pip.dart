import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/platform/app_platform.dart';
import '../../../../core/platform/device_class.dart';
import 'pip_android.dart';
import 'pip_desktop.dart';

part 'pip.g.dart';

/// Actions from platform PiP controls; [dismissed]: the user closed the PiP window, the app stays in background.
enum PipAction { playPause, next, prev, dismissed }

@immutable
final class PipPlayback {
  static const defaultAspectRatio = 16 / 9;

  final bool isPlaying;
  final bool hasPrev;
  final bool hasNext;
  final bool showSkipButtons;
  final double aspectRatio;

  const PipPlayback({
    this.isPlaying = false,
    this.hasPrev = false,
    this.hasNext = false,
    this.showSkipButtons = false,
    this.aspectRatio = defaultAspectRatio,
  });

  @override
  bool operator ==(Object other) =>
      other is PipPlayback &&
      other.isPlaying == isPlaying &&
      other.hasPrev == hasPrev &&
      other.hasNext == hasNext &&
      other.showSkipButtons == showSkipButtons &&
      other.aspectRatio == aspectRatio;

  @override
  int get hashCode => Object.hash(isPlaying, hasPrev, hasNext, showSkipButtons, aspectRatio);
}

/// Picture-in-picture (spec-06 §6.10). Allowed only between [enable] and [disable], so the player screen decides
/// when PiP is available.
abstract class Pip {
  final _active = ValueNotifier(false);
  final _actions = StreamController<PipAction>.broadcast();

  bool get isSupported;

  ValueListenable<bool> get isActive => _active;

  Stream<PipAction> get actions => _actions.stream;

  @protected
  set active(bool value) => _active.value = value;

  @protected
  void emitAction(PipAction action) => _actions.add(action);

  /// Allows PiP, including auto-enter when the user leaves the app while playing (Android).
  Future<void> enable();

  /// Disallows PiP and leaves it when active.
  Future<void> disable();

  Future<void> updatePlayback(PipPlayback playback);

  Future<void> enter();

  Future<void> exit();

  Future<void> closeApp();

  /// Moves the compact window with the pointer (desktop; the PiP window has no title bar).
  Future<void> startWindowDrag() async {}
}

/// TV and platforms without PiP.
class UnsupportedPip extends Pip {
  @override
  bool get isSupported => false;

  @override
  Future<void> enable() async {}

  @override
  Future<void> disable() async {}

  @override
  Future<void> updatePlayback(PipPlayback playback) async {}

  @override
  Future<void> enter() async {}

  @override
  Future<void> exit() async {}

  @override
  Future<void> closeApp() async {}
}

/// Overridden in `bootstrap()` with [createPip].
@Riverpod(keepAlive: true)
Pip pip(Ref ref) => UnsupportedPip();

/// No PiP on TV (spec-06 §6.8).
Future<Pip> createPip(AppPlatform platform, DeviceClass deviceClass) async {
  if (deviceClass == DeviceClass.tv) return UnsupportedPip();
  return switch (platform) {
    AppPlatform.android => AndroidPip.create(),
    AppPlatform.linux || AppPlatform.windows => DesktopPip(const WindowManagerPipWindow()),
  };
}
