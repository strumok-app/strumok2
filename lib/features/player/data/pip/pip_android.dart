import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

import 'pip.dart';

final _log = Logger('AndroidPip');

/// Android PiP over the `strumok/pip` channel (spec-06 §6.10; method names are fixed). The native side owns
/// `PictureInPictureParams`, remote actions and auto-enter.
class AndroidPip extends Pip {
  static const channel = MethodChannel('strumok/pip');

  bool _supported = false;

  AndroidPip._();

  static Future<AndroidPip> create() async {
    final pip = AndroidPip._();
    channel.setMethodCallHandler(pip._handleCall);
    pip._supported = await pip._invoke<bool>('isSupported') ?? false;
    return pip;
  }

  @override
  bool get isSupported => _supported;

  Future<void> _handleCall(MethodCall call) async {
    final arguments = call.arguments;
    if (arguments is! Map) return;
    switch (call.method) {
      case 'onPipModeChanged':
        active = arguments['active'] == true;
      case 'onAction':
        final action = PipAction.values.asNameMap()[arguments['action']];
        if (action != null) emitAction(action);
    }
  }

  Future<T?> _invoke<T>(String method, [Map<String, Object?>? arguments]) async {
    try {
      return await channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (e, st) {
      _log.warning('PiP call $method failed', e, st);
      return null;
    } on MissingPluginException catch (e) {
      _log.warning('PiP channel unavailable', e);
      return null;
    }
  }

  @override
  Future<void> enable() async {
    if (_supported) await _invoke<void>('enable');
  }

  @override
  Future<void> disable() async {
    if (_supported) await _invoke<void>('disable');
  }

  @override
  Future<void> updatePlayback(PipPlayback playback) async {
    if (!_supported) return;
    await _invoke<void>('update', {
      'isPlaying': playback.isPlaying,
      'hasPrev': playback.hasPrev,
      'hasNext': playback.hasNext,
      'showSkipButtons': playback.showSkipButtons,
      'aspectRatio': playback.aspectRatio,
    });
  }

  @override
  Future<void> enter() async {
    if (_supported) await _invoke<bool>('enter');
  }

  @override
  Future<void> exit() async {
    if (_supported) await _invoke<void>('exit');
  }

  @override
  Future<void> closeApp() => _invoke<void>('closeApp');
}
