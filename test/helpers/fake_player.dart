import 'dart:async';

import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter/widgets.dart';
import 'package:strumok/core/platform/device_levels.dart';
import 'package:strumok/core/platform/window_fullscreen.dart';
import 'package:strumok/features/player/data/pip/pip.dart';
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

class FakeSubtitleSource extends SubtitleMediaItemSource {
  @override
  final String description;
  @override
  final Map<String, String>? headers;
  final String url;

  FakeSubtitleSource(this.description, {String? url, this.headers})
    : url = url ?? 'https://subs.example.com/$description.vtt';

  @override
  Future<Uri> get link async => Uri.parse(url);
}

/// Records calls; tests drive [status], [ended] and [errors].
class FakeVideoBackend implements VideoBackend {
  final calls = <String>[];
  final opened = <VideoOpenRequest>[];
  final _status = ValueNotifier(const PlaybackStatus());
  final _tracks = ValueNotifier(const PlaybackTracks());
  final _ended = StreamController<void>.broadcast(sync: true);
  final _errors = StreamController<String>.broadcast(sync: true);
  var disposed = false;

  @override
  ValueNotifier<PlaybackStatus> get status => _status;

  @override
  Stream<void> get ended => _ended.stream;

  @override
  Stream<String> get errors => _errors.stream;

  @override
  ValueNotifier<PlaybackTracks> get tracks => _tracks;

  void end() => _ended.add(null);

  void fail(String message) => _errors.add(message);

  void emit({Duration? position, Duration? duration, bool? playing}) =>
      _status.value = _status.value.copyWith(position: position, duration: duration, playing: playing);

  @override
  Future<void> open(VideoOpenRequest request) async {
    opened.add(request);
    calls.add('open:${request.link}@${request.start.inSeconds}');
    _status.value = PlaybackStatus(position: request.start, volume: _status.value.volume, playing: true);
    final tracks = _tracks.value;
    _tracks.value = PlaybackTracks(video: tracks.video, audio: tracks.audio);
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

  PlaybackTracks _select({Object? video = _keep, Object? audio = _keep}) {
    final t = _tracks.value;
    return PlaybackTracks(
      video: t.video,
      audio: t.audio,
      videoId: video == _keep ? t.videoId : video as String?,
      audioId: audio == _keep ? t.audioId : audio as String?,
    );
  }

  static const _keep = Object();

  @override
  Future<void> selectVideoTrack(String? id) async {
    calls.add('video:$id');
    _tracks.value = _select(video: id);
  }

  @override
  Future<void> selectAudioTrack(String? id) async {
    calls.add('audio:$id');
    _tracks.value = _select(audio: id);
  }

  @override
  Future<void> setSpeed(double speed) async => calls.add('speed:$speed');

  @override
  Future<void> setAudioFilter(String filter) async => calls.add('af:$filter');

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

class FakeBrightnessControl implements BrightnessControl {
  double value;
  var resets = 0;

  FakeBrightnessControl([this.value = 0.5]);

  @override
  Future<double> get() async => value;

  @override
  Future<void> set(double value) async => this.value = value;

  @override
  Future<void> reset() async => resets++;
}

class FakeVolumeControl implements VolumeControl {
  double value;

  FakeVolumeControl([this.value = 0.5]);

  @override
  Future<double> get() async => value;

  @override
  Future<void> set(double value) async => this.value = value;
}

/// Records calls; tests emit platform actions with [action].
class FakePip extends Pip {
  final calls = <String>[];
  final playbacks = <PipPlayback>[];
  final bool supported;

  FakePip({this.supported = true});

  @override
  bool get isSupported => supported;

  void action(PipAction action) => emitAction(action);

  @override
  Future<void> enable() async => calls.add('enable');

  @override
  Future<void> disable() async {
    calls.add('disable');
    active = false;
  }

  @override
  Future<void> updatePlayback(PipPlayback playback) async => playbacks.add(playback);

  @override
  Future<void> enter() async {
    calls.add('enter');
    active = true;
  }

  @override
  Future<void> exit() async {
    calls.add('exit');
    active = false;
  }

  @override
  Future<void> closeApp() async => calls.add('closeApp');
}
