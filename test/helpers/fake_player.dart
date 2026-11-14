import 'dart:async';

import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter/widgets.dart';
import 'package:strumok/core/platform/window_fullscreen.dart';
import 'package:strumok/features/player/data/video_backend.dart';

class FakeVideoSource extends VideoMediaItemSource {
  @override
  final String description;
  @override
  final Map<String, String>? headers;
  @override
  final bool hlsProxy;
  final String url;

  FakeVideoSource(this.description, {String? url, this.headers, this.hlsProxy = false})
    : url = url ?? 'https://cdn.example.com/$description.m3u8';

  @override
  Future<Uri> get link async => Uri.parse(url);
}

/// Records calls; tests drive [status], [ended] and [errors].
class FakeVideoBackend implements VideoBackend {
  final calls = <String>[];
  final opened = <VideoOpenRequest>[];
  final _status = ValueNotifier(const PlaybackStatus());
  final _ended = StreamController<void>.broadcast(sync: true);
  final _errors = StreamController<String>.broadcast(sync: true);
  var disposed = false;

  @override
  ValueNotifier<PlaybackStatus> get status => _status;

  @override
  Stream<void> get ended => _ended.stream;

  @override
  Stream<String> get errors => _errors.stream;

  void end() => _ended.add(null);

  void fail(String message) => _errors.add(message);

  void emit({Duration? position, Duration? duration, bool? playing}) =>
      _status.value = _status.value.copyWith(position: position, duration: duration, playing: playing);

  @override
  Future<void> open(VideoOpenRequest request) async {
    opened.add(request);
    calls.add('open:${request.link}@${request.start.inSeconds}');
    _status.value = PlaybackStatus(position: request.start, volume: _status.value.volume, playing: true);
  }

  @override
  Future<void> play() async {
    calls.add('play');
    emit(playing: true);
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    emit(playing: false);
  }

  @override
  Future<void> playOrPause() async {
    calls.add('playOrPause');
    emit(playing: !_status.value.playing);
  }

  @override
  Future<void> seek(Duration position) async {
    calls.add('seek:${position.inSeconds}');
    emit(position: position);
  }

  @override
  Future<void> setVolume(double volume) async {
    calls.add('volume:${volume.round()}');
    _status.value = _status.value.copyWith(volume: volume);
  }

  @override
  Future<void> frameStep({required bool forward}) async => calls.add(forward ? 'frameStep' : 'frameBackStep');

  @override
  Widget buildView() => const SizedBox.expand(key: Key('fakeVideo'));

  @override
  Future<void> dispose() async {
    disposed = true;
    calls.add('dispose');
  }
}

class FakeWindowFullscreen implements WindowFullscreen {
  final changes = <bool>[];

  @override
  Future<void> setFullScreen(bool value) async => changes.add(value);
}
