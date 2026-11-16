import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../core/hls/hls_proxy.dart';
import 'video_backend.dart';

final _log = Logger('MediaKitVideoBackend');

/// media_kit (libmpv) backend with the mpv tuning of spec-06 §6.3.
class MediaKitVideoBackend implements VideoBackend {
  static const _endTolerance = Duration(seconds: 5);

  // Proven on slow CDNs (spec-06 §6.3).
  static const _properties = {
    'hr-seek': 'no',
    'force-seekable': 'yes',
    'framedrop': 'no',
    'video-sync': 'audio',
    'cache': 'yes',
    'cache-secs': '180',
    'demuxer-readahead-secs': '180',
    'demuxer-max-bytes': '128M',
    'demuxer-max-back-bytes': '32M',
    'cache-pause-wait': '3',
    'network-timeout': '30',
    // Embedded subtitle tracks are never selected or decoded.
    'sid': 'no',
  };
  // No reconnect on 4xx: expired links must fail fast.
  static const _reconnect = [
    'reconnect=1',
    'reconnect_streamed=1',
    'reconnect_on_network_error=1',
    'reconnect_on_http_error=5xx',
    'reconnect_delay_max=10',
  ];

  final http.Client _client;
  final Player _player;
  late final VideoController _video = VideoController(_player);
  late final Widget _view = Video(
    controller: _video,
    controls: NoVideoControls,
    fill: Colors.black,
    // Subtitles are loaded, parsed and rendered by the player itself, never by mpv.
    subtitleViewConfiguration: const SubtitleViewConfiguration(visible: false),
  );
  late final Future<void> _configured = _configure();

  final _status = ValueNotifier(const PlaybackStatus());
  final _tracks = ValueNotifier(const PlaybackTracks());
  final _ended = StreamController<void>.broadcast();
  final _errors = StreamController<String>.broadcast();
  final _subscriptions = <StreamSubscription<Object?>>[];
  HlsProxy? _proxy;

  /// mpv left idle after the current file started: it ended (EOF) or failed.
  bool _fileStarted = false;
  bool _finished = false;
  String? _lastError;
  bool _disposed = false;

  MediaKitVideoBackend(this._client)
    : _player = Player(
        configuration: const PlayerConfiguration(title: 'Strumok', bufferSize: 128 * 1024 * 1024),
      ) {
    final stream = _player.stream;
    _subscriptions.addAll([
      stream.position.listen((v) => _update(_status.value.copyWith(position: v))),
      stream.duration.listen((v) => _update(_status.value.copyWith(duration: v))),
      stream.buffer.listen((v) => _update(_status.value.copyWith(buffered: v))),
      stream.playing.listen((v) => _update(_status.value.copyWith(playing: v))),
      stream.buffering.listen((v) => _update(_status.value.copyWith(buffering: v))),
      stream.volume.listen((v) => _update(_status.value.copyWith(volume: v))),
      stream.tracks.listen((_) => _updateTracks()),
      stream.track.listen((_) => _updateTracks()),
      stream.completed.listen((completed) {
        if (completed) _finish();
      }),
      stream.error.listen((message) {
        _log.fine('mpv: $message');
        _lastError = message;
      }),
    ]);
  }

  NativePlayer get _native => _player.platform as NativePlayer;

  Future<void> _configure() async {
    for (final MapEntry(:key, :value) in _properties.entries) {
      await _native.setProperty(key, value);
    }
    await _native.setProperty('stream-lavf-o', _reconnect.join(','));
    // Appended to keep media_kit's own demuxer options.
    for (final option in [..._reconnect, 'seg_max_retry=10']) {
      await _native.command(['change-list', 'demuxer-lavf-o', 'append', option]);
    }
    await _native.observeProperty('idle-active', (idle) async {
      if (idle == 'no') {
        _fileStarted = true;
      } else if (_fileStarted) {
        _onStopped();
      }
    });
  }

  void _update(PlaybackStatus next) {
    if (!_disposed) _status.value = next;
  }

  static bool _real(String id) => id != 'auto' && id != 'no';

  static MediaTrack _track(String id, String? title, String? language, {int? height, int? bitrate}) =>
      MediaTrack(id, title: title, language: language, height: height, bitrate: bitrate);

  void _updateTracks() {
    if (_disposed) return;
    final state = _player.state;
    final tracks = state.tracks;
    final selected = state.track;
    String? id(String value) => _real(value) ? value : null;
    _tracks.value = PlaybackTracks(
      video: [
        for (final t in tracks.video)
          if (_real(t.id) && t.albumart != true) _track(t.id, t.title, t.language, height: t.h, bitrate: t.bitrate),
      ],
      audio: [
        for (final t in tracks.audio)
          if (_real(t.id)) _track(t.id, t.title, t.language),
      ],
      videoId: id(selected.video.id),
      audioId: id(selected.audio.id),
    );
  }

  void _onStopped() {
    final status = _status.value;
    final nearEnd = status.duration > Duration.zero && status.duration - status.position <= _endTolerance;
    if (nearEnd) {
      _finish();
    } else if (!_finished) {
      _finished = true;
      _errors.add(_lastError ?? 'Playback stopped');
    }
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _ended.add(null);
  }

  @override
  ValueListenable<PlaybackStatus> get status => _status;

  @override
  Stream<void> get ended => _ended.stream;

  @override
  Stream<String> get errors => _errors.stream;

  @override
  ValueListenable<PlaybackTracks> get tracks => _tracks;

  @override
  Future<void> open(VideoOpenRequest request) async {
    await _configured;
    var url = request.link;
    if (request.hlsProxy) {
      _proxy ??= await HlsProxy.start(_client);
      url = _proxy!.masterUrl(request.link);
    }
    if (request.languages.isNotEmpty) {
      final languages = request.languages.join(',');
      await _native.setProperty('alang', languages);
      await _native.setProperty('vlang', languages);
    }
    _fileStarted = false;
    _finished = false;
    _lastError = null;
    _update(PlaybackStatus(volume: _status.value.volume));
    await _player.open(Media(url.toString(), httpHeaders: request.headers, start: request.start));
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> playOrPause() => _player.playOrPause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> frameStep({required bool forward}) => _native.command([forward ? 'frame-step' : 'frame-back-step']);

  @override
  Future<void> selectVideoTrack(String? id) =>
      _player.setVideoTrack(_player.state.tracks.video.firstWhere((t) => t.id == id, orElse: VideoTrack.auto));

  @override
  Future<void> selectAudioTrack(String? id) =>
      _player.setAudioTrack(_player.state.tracks.audio.firstWhere((t) => t.id == id, orElse: AudioTrack.auto));

  @override
  Future<void> setSpeed(double speed) => _player.setRate(speed);

  @override
  Future<void> setAudioFilter(String filter) async {
    await _configured;
    await _native.setProperty('af', filter);
  }

  @override
  Widget buildView() => _view;

  @override
  Future<void> dispose() async {
    _disposed = true;
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _player.dispose();
    await _proxy?.close();
    await _ended.close();
    await _errors.close();
    _status.dispose();
    _tracks.dispose();
  }
}
