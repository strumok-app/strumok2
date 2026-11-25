import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../core/hls/hls_proxy.dart';
import '../domain/equalizer.dart';
import '../domain/upscaling.dart';
import 'mpv_audio_filter.dart';
import 'mpv_shaders.dart';
import 'playback_progress.dart';
import 'shader_store.dart';
import 'video_backend.dart';

final _log = Logger('MediaKitVideoBackend');

/// media_kit (libmpv) backend with the mpv tuning of spec-06 §6.3.
class MediaKitVideoBackend implements VideoBackend {
  static const _resizeDelay = Duration(milliseconds: 150);

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
    // SPEC: not in spec-06 §6.3. Render-quality tuning: sharp anti-ringing scaling plus debanding for compressed
    // old TV rips. Adds GPU cost; revisit if weak Android TV GPUs drop frames.
    'scale': 'ewa_lanczossharp',
    'cscale': 'mitchell',
    'dscale': 'mitchell',
    'linear-downscaling': 'no',
    'deband': 'yes',
    'deband-iterations': '2',
    'deband-threshold': '35',
    'deband-range': '16',
    'deband-grain': '12',
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
  late final Widget _videoView = Video(
    controller: _video,
    controls: NoVideoControls,
    fill: Colors.black,
    // Subtitles are loaded, parsed and rendered by the player itself, never by mpv.
    subtitleViewConfiguration: const SubtitleViewConfiguration(visible: false),
  );
  // Reports the on-screen size in every host (full screen, floating, PiP) for upscaling output sizing.
  late final Widget _view = LayoutBuilder(
    builder: (context, constraints) {
      final ratio = MediaQuery.devicePixelRatioOf(context);
      _onViewSize(Size(constraints.maxWidth * ratio, constraints.maxHeight * ratio));
      return _videoView;
    },
  );
  late final Future<void> _configured = _configure();

  final _status = ValueNotifier(const PlaybackStatus());
  final _tracks = ValueNotifier(const PlaybackTracks());
  final _ended = StreamController<void>.broadcast();
  final _errors = StreamController<String>.broadcast();
  final _subscriptions = <StreamSubscription<Object?>>[];
  final _progress = PlaybackProgress();
  HlsProxy? _proxy;

  final ShaderStore? _shaders;
  final List<Upscaler> _supportedUpscalers;
  final _upscalerFailures = StreamController<Upscaler>.broadcast();
  Upscaler? _upscaler;
  int _upscalerToken = 0;
  Size? _viewSize;
  Timer? _resizeTimer;

  /// Fixed output size set for the active upscaler; null = the video's own size (media_kit default).
  ({int width, int height})? _outputSize;

  /// The video track mpv is actually decoding, resolved even under `vid=auto`; null when unknown.
  String? _activeVideoId;

  /// mpv left idle after the current file started: it ended (EOF) or failed.
  bool _fileStarted = false;
  bool _finished = false;
  String? _lastError;
  bool _disposed = false;

  /// [upscalers] must be empty unless [shaders] is given.
  MediaKitVideoBackend(this._client, {ShaderStore? shaders, List<Upscaler> upscalers = const []})
    : _shaders = shaders,
      _supportedUpscalers = shaders == null ? const [] : upscalers,
      _player = Player(
        configuration: const PlayerConfiguration(title: 'Strumok', bufferSize: 128 * 1024 * 1024),
      ) {
    final stream = _player.stream;
    _subscriptions.addAll([
      stream.position.listen((v) {
        _progress.position(v);
        _update(_status.value.copyWith(position: v));
      }),
      stream.duration.listen((v) => _update(_status.value.copyWith(duration: v))),
      stream.buffer.listen((v) => _update(_status.value.copyWith(buffered: v))),
      stream.playing.listen((v) => _update(_status.value.copyWith(playing: v))),
      stream.buffering.listen((v) => _update(_status.value.copyWith(buffering: v))),
      stream.volume.listen((v) => _update(_status.value.copyWith(volume: v))),
      stream.width.listen((_) => _updateAspectRatio()),
      stream.height.listen((_) => _updateAspectRatio()),
      stream.tracks.listen((_) => _updateTracks()),
      stream.track.listen((_) => _updateTracks()),
      stream.completed.listen((completed) {
        if (completed) _onStopped(eof: true);
      }),
      stream.error.listen((message) {
        _log.fine('mpv: $message');
        _lastError = message;
      }),
      stream.log.listen(_onLog),
      // spec-13 F7: media_kit resets the output to the video size on every video-params change.
      stream.videoParams.listen((_) => _scheduleResize(force: true)),
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
    // Resolves the rendition behind "Auto": mpv reports the decoded track id even when selection is automatic.
    await _native.observeProperty('current-tracks/video/id', (value) async {
      final id = value.trim();
      _activeVideoId = id.isEmpty || id == 'no' ? null : id;
      _updateTracks();
    });
  }

  void _update(PlaybackStatus next) {
    if (!_disposed) _status.value = next;
  }

  void _updateAspectRatio() {
    final PlayerState(:width, :height) = _player.state;
    if (width != null && height != null && width > 0 && height > 0) {
      _update(_status.value.copyWith(aspectRatio: width / height));
    }
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
      activeVideoId: _activeVideoId,
    );
  }

  /// mpv went idle or reached EOF; a stream that broke before its end is a failure, not a finished file.
  void _onStopped({bool eof = false}) {
    final duration = _status.value.duration;
    // EOF of a file with unknown duration cannot be verified: trust it.
    if (_progress.reachedEnd(duration) || (eof && duration <= Duration.zero)) {
      _finish();
    } else if (!_finished) {
      _finished = true;
      _errors.add(_lastError ?? 'Playback stopped at ${_progress.reached} of $duration');
    }
  }

  void _finish() {
    if (_finished) return;
    _log.info(
      'Finishing playback duration: ${status.value.duration} position: ${status.value.position}, finished: $_finished',
    );
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
    _activeVideoId = null;
    _progress.reset(request.start);
    _update(PlaybackStatus(volume: _status.value.volume));
    // Downloaded files (spec-08 §8.4) open by path: mpv takes it verbatim, without URL decoding.
    final resource = url.scheme == 'file' ? url.toFilePath() : url.toString();
    _log.fine('opening stream $request');
    await _player.open(Media(resource, httpHeaders: request.headers, start: request.start));
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> playOrPause() => _player.playOrPause();

  @override
  Future<void> seek(Duration position) {
    _progress.seekTo(position);
    return _player.seek(position);
  }

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
  Future<void> setAudioEffects(AudioEffects effects) async {
    await _configured;
    await _native.setProperty('af', mpvAudioFilter(effects));
  }

  @override
  List<Upscaler> get supportedUpscalers => _supportedUpscalers;

  @override
  Stream<Upscaler> get upscalerFailures => _upscalerFailures.stream;

  @override
  Future<void> setUpscaler(Upscaler? upscaler) =>
      _applyUpscaler(_supportedUpscalers.contains(upscaler) ? upscaler : null);

  Future<void> _applyUpscaler(Upscaler? upscaler) async {
    final token = ++_upscalerToken;
    try {
      await _configured;
      final files = upscaler == null ? const <String>[] : await _shaders!.files(upscaler);
      if (_disposed || token != _upscalerToken) return;
      _upscaler = upscaler;
      for (final command in mpvShaderCommands(files)) {
        await _native.command(command);
      }
      // spec-13 F5: with framedrop=no an overloaded shader leaves video behind audio for good.
      await _native.setProperty('framedrop', upscaler == null ? 'no' : 'vo');
      _scheduleResize(force: true);
    } catch (e, st) {
      _log.warning('Upscaler ${upscaler?.id} could not be applied', e, st);
      if (upscaler != null && !_disposed && token == _upscalerToken) _failUpscaler(upscaler);
    }
  }

  void _onLog(PlayerLog log) {
    final upscaler = _upscaler;
    if (upscaler == null || !isShaderFailureLog(log.prefix, log.level, log.text)) return;
    _log.warning('Upscaler ${upscaler.id} failed: [${log.prefix}] ${log.text}');
    _failUpscaler(upscaler);
  }

  void _failUpscaler(Upscaler upscaler) {
    _upscaler = null;
    _upscalerFailures.add(upscaler);
    unawaited(_applyUpscaler(null));
  }

  void _onViewSize(Size size) {
    if (!size.isFinite || size == _viewSize) return;
    _viewSize = size;
    _scheduleResize();
  }

  void _scheduleResize({bool force = false}) {
    // Off and at the video's own size: nothing to do, keep media_kit's default sizing untouched.
    if (_upscaler == null && _outputSize == null) return;
    _resizeTimer?.cancel();
    _resizeTimer = Timer(_resizeDelay, () => unawaited(_resize(force: force)));
  }

  Future<void> _resize({required bool force}) async {
    final view = _viewSize;
    final VideoParams(:dw, :dh, :rotate) = _player.state.videoParams;
    final turned = rotate == 90 || rotate == 270;
    final video = Size(((turned ? dh : dw) ?? 0).toDouble(), ((turned ? dw : dh) ?? 0).toDouble());
    final target = _upscaler == null || view == null ? null : upscaleOutputSize(view, video);
    if (_disposed || (!force && target == _outputSize)) return;
    _outputSize = target;
    // setSize skips a size equal to its cached one even after media_kit reset the output (F7): go native first.
    await _video.setSize();
    if (target != null) await _video.setSize(width: target.width, height: target.height);
  }

  @override
  Widget buildView() => _view;

  @override
  Future<void> dispose() async {
    _disposed = true;
    _resizeTimer?.cancel();
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _player.dispose();
    await _proxy?.close();
    await _ended.close();
    await _errors.close();
    await _upscalerFailures.close();
    _status.dispose();
    _tracks.dispose();
  }
}
