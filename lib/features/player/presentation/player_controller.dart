import 'dart:async';

import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/localization.dart';
import '../../../core/network/http_client.dart';
import '../../../core/platform/app_platform.dart';
import '../../../core/storage/app_preferences.dart';
import '../../collection/domain/collection_item.dart';
import '../../collection/domain/progress.dart';
import '../../collection/presentation/collection_providers.dart';
import '../../details/presentation/details_providers.dart';
import '../data/media_kit_backend.dart';
import '../data/shader_store.dart';
import '../data/subtitle_repository.dart';
import '../data/video_backend.dart';
import '../domain/equalizer.dart';
import '../domain/player_preferences.dart';
import '../domain/player_session.dart';
import '../domain/subtitles.dart';
import '../domain/upscaling.dart';
import 'player_settings.dart';

part 'player_controller.g.dart';

final _log = Logger('PlayerController');

@Riverpod(keepAlive: true)
VideoBackend Function() videoBackendFactory(Ref ref) {
  final client = ref.watch(httpClientProvider);
  // spec-13: Linux only for now; Windows stays off until verified (U0 T9), Android never.
  final upscaling = AppPlatform.current == AppPlatform.linux;
  final shaders = upscaling ? ref.watch(shaderStoreProvider) : null;
  return () => MediaKitVideoBackend(client, shaders: shaders, upscalers: upscaling ? upscalers : const []);
}

/// UI-agnostic player (spec-06 §6.1–6.2): loads items and sources, drives the backend, saves progress.
/// Kept alive so the session can outlive the player route (floating player / PiP, M6).
@Riverpod(keepAlive: true)
class PlayerController extends _$PlayerController {
  static const _progressInterval = Duration(seconds: 1);
  static final _idleStatus = ValueNotifier(const PlaybackStatus());
  static final _idleTracks = ValueNotifier(const PlaybackTracks());

  VideoBackend? _backend;
  final _subscriptions = <StreamSubscription<Object?>>[];
  final _subtitleLines = ValueNotifier<List<String>>(const []);
  final _upscalerFailures = StreamController<Upscaler>.broadcast();
  SubtitleTrack? _subtitleTrack;
  int _subtitleToken = 0;

  /// Incremented by every load; async steps of an older load stop when it changed (spec-06 §6.2.7).
  int _token = 0;
  double _speed = 1;

  /// Volume restored by the mute toggle.
  double _volumeBeforeMute = 100;

  /// Subtitles the show/hide toggle turns back on.
  String? _lastSubtitleName;

  /// Number (collection key) of the item the backend is currently playing; null while loading, so stale positions
  /// are never saved.
  int? _playingNumber;

  /// The collection item this session edits; seeded by [open], kept current after every save. [_latest]
  /// re-merges it with live synced data. Only touched after [open] has seeded it (guarded by [_playingNumber]).
  late CollectionItem _base;
  Duration _lastProgressCheck = Duration.zero;
  Duration _resumeAt = Duration.zero;

  @override
  PlayerSession? build() {
    ref.onDispose(() {
      unawaited(_disposeBackend());
      unawaited(_upscalerFailures.close());
    });
    return null;
  }

  ValueListenable<PlaybackStatus> get status => _backend?.status ?? _idleStatus;

  ValueListenable<PlaybackTracks> get tracks => _backend?.tracks ?? _idleTracks;

  /// Lines of the selected supplier subtitles at the current position (with the offset).
  ValueListenable<List<String>> get subtitleLines => _subtitleLines;

  Widget? buildVideoView() => _backend?.buildView();

  /// Upscalers the current backend can run; empty (setting hidden) without one or where unsupported (spec-13).
  List<Upscaler> get supportedUpscalers => _backend?.supportedUpscalers ?? const [];

  /// The chosen upscaler if it can run here; null is off.
  Upscaler? get upscaler {
    final chosen = upscalerById(ref.read(playerSettingsProvider).upscaler);
    return supportedUpscalers.contains(chosen) ? chosen : null;
  }

  /// An upscaler failed and was turned off (the setting too); playback continues without it.
  Stream<Upscaler> get upscalerFailures => _upscalerFailures.stream;

  /// Reopening the title of a running session (floating player → full screen) keeps it: no reload, no re-buffering.
  /// [item] is an item number (collection key); offline content lists only downloaded items, so numbers and list
  /// indexes differ there.
  Future<void> open(String supplier, String id, {int? item}) async {
    _log.fine('Opening player for supplier: $supplier, id: $id, item: $item');
    final current = state;
    if (current != null &&
        current.supplier == supplier &&
        current.id == id &&
        current.failure == null &&
        (current.loading || _backend != null)) {
      final index = item == null ? null : itemIndexOfNumber(current.items, item);
      if (index != null && index != current.itemIndex) await selectItem(index);
      return;
    }
    await _saveProgress();
    final token = ++_token;
    _playingNumber = null;
    state = PlayerSession(supplier: supplier, id: id, speed: _speed);
    try {
      final details = await ref.read(contentDetailsProvider(supplier, id).future);
      final items = await ref.read(mediaItemsProvider(supplier, id).future);
      final collection = await ref.read(collectionItemsProvider.future);
      if (!_isCurrent(token)) return;

      _base =
          (collection[collectionItemKey(supplier, id)] ??
                  CollectionItem(
                    id: id,
                    supplier: supplier,
                    title: details.title,
                    image: details.image,
                    mediaType: details.mediaType,
                  ))
              .copyWith(title: details.title, image: details.image);
      state = state!.copyWith(title: details.title, items: items);
      if (items.isEmpty) {
        state = state!.copyWith(loading: false, failure: PlayerFailure.noSources);
        return;
      }

      await _openItem(token, itemIndexOfNumber(items, item ?? _base.currentItem) ?? 0);
    } catch (e, st) {
      _fail(token, PlayerFailure.loadFailed, e, st);
    }
  }

  Future<void> selectItem(int index) async {
    final session = state;
    if (session == null || index < 0 || index >= session.items.length) return;
    await _saveProgress();
    await _openItem(++_token, index);
  }

  Future<void> next() async {
    if (state?.hasNext ?? false) await selectItem(state!.itemIndex + 1);
  }

  Future<void> previous() async {
    if (state?.hasPrevious ?? false) await selectItem(state!.itemIndex - 1);
  }

  /// Switches the server, keeping the playback position.
  Future<void> selectSource(int index) async {
    final session = state;
    if (session == null || index < 0 || index >= session.sources.length) return;
    final position = status.value.position;
    await _saveProgress();
    final token = ++_token;
    _playingNumber = null;
    state = session.copyWith(sourceIndex: index, loading: true, clearFailure: true);
    await _updateItem((item) => item.copyWith(currentSourceName: session.sources[index].description));
    await _openSource(token, position);
  }

  /// Supplier subtitles by index; null turns them off. The choice is remembered as `currentSubtitleName`.
  Future<void> selectSubtitles(int? index) async {
    final session = state;
    if (session == null || (index != null && (index < 0 || index >= session.subtitles.length))) return;
    state = session.copyWith(subtitleIndex: index, clearSubtitle: index == null, subtitleFailed: false);
    if (index != null) _lastSubtitleName = session.subtitles[index].description;
    // Loading starts (and shows) before the collection write finishes.
    final load = _loadSubtitles();
    final name = index == null ? null : session.subtitles[index].description;
    await _updateItem((item) => item.copyWith(currentSubtitleName: name, clearSubtitleName: name == null));
    await load;
  }

  /// Show/hide: off when on; otherwise the last chosen subtitles of this session (the first when none match).
  Future<void> toggleSubtitles() async {
    final session = state;
    if (session == null || session.subtitles.isEmpty) return;
    if (session.subtitleIndex != null) return selectSubtitles(null);
    final last = session.subtitles.indexWhere((s) => s.description == _lastSubtitleName);
    await selectSubtitles(last < 0 ? 0 : last);
  }

  /// Positive shows subtitles later.
  void setSubtitleOffset(Duration offset) {
    if (state == null) return;
    state = state!.copyWith(subtitleOffset: offset);
    _refreshSubtitleLines();
  }

  /// Null selects automatically.
  Future<void> selectAudioTrack(String? id) async => _backend?.selectAudioTrack(id);

  /// Video quality; null selects automatically.
  Future<void> selectVideoTrack(String? id) async => _backend?.selectVideoTrack(id);

  /// Kept for the rest of the app session, across items and titles.
  Future<void> setSpeed(double speed) async {
    _speed = speed.clamp(playbackSpeeds.first, playbackSpeeds.last);
    if (state != null) state = state!.copyWith(speed: _speed);
    await _backend?.setSpeed(_speed);
  }

  /// Persisted equalizer gains, applied right away.
  Future<void> setEqualizer(EqualizerGains gains) async {
    await ref.read(playerSettingsProvider.notifier).setEqualizer(gains);
    await _applyAudioEffects();
  }

  Future<void> setVolumeNormalization(bool enabled) async {
    await ref.read(playerSettingsProvider.notifier).setVolumeNormalization(enabled);
    await _applyAudioEffects();
  }

  Future<void> setDynamicCompression(bool enabled) async {
    await ref.read(playerSettingsProvider.notifier).setDynamicCompression(enabled);
    await _applyAudioEffects();
  }

  Future<void> _applyAudioEffects() async => _backend?.setAudioEffects(ref.read(playerSettingsProvider).audioEffects);

  /// Persisted and applied right away; null turns upscaling off.
  Future<void> setUpscaler(Upscaler? upscaler) async {
    await ref.read(playerSettingsProvider.notifier).setUpscaler(upscaler?.id);
    await _backend?.setUpscaler(upscaler);
  }

  /// Reloads after a failure; playback resumes at the last known position.
  Future<void> retry() async {
    final session = state;
    if (session == null) return;
    if (session.items.isEmpty) return open(session.supplier, session.id);
    if (session.sources.isEmpty) return _openItem(++_token, session.itemIndex);
    final token = ++_token;
    state = session.copyWith(loading: true, clearFailure: true);
    await _openSource(token, _resumeAt);
  }

  Future<void> close() async {
    if (!ref.mounted) return;
    await _saveProgress();
    _token++;
    _playingNumber = null;
    state = null;
    _clearSubtitles();
    await _disposeBackend();
  }

  Future<void> playOrPause() async => _backend?.playOrPause();

  Future<void> play() async => _backend?.play();

  Future<void> pause() async => _backend?.pause();

  Future<void> seekTo(Duration position) async {
    final duration = status.value.duration;
    var target = position < Duration.zero ? Duration.zero : position;
    if (duration > Duration.zero && target > duration) target = duration;
    await _backend?.seek(target);
  }

  Future<void> seekBy(Duration offset) => seekTo(status.value.position + offset);

  Future<void> frameStep({required bool forward}) async => _backend?.frameStep(forward: forward);

  Future<void> setVolume(double volume) async {
    final clamped = volume.clamp(0, 100).toDouble();
    await _backend?.setVolume(clamped);
    await ref.read(appPreferencesProvider).setDouble(AppPreferences.volume, clamped);
  }

  /// Mutes (remembering the current level) or restores the previous level.
  Future<void> toggleMute() async {
    final current = status.value.volume;
    if (current > 0) {
      _volumeBeforeMute = current;
      await setVolume(0);
    } else {
      await setVolume(_volumeBeforeMute > 0 ? _volumeBeforeMute : 100);
    }
  }

  bool _isCurrent(int token) => ref.mounted && token == _token;

  Future<void> _openItem(int token, int index) async {
    _playingNumber = null;
    state = state!.copyWith(
      itemIndex: index,
      sources: const [],
      sourceIndex: 0,
      subtitles: const [],
      clearSubtitle: true,
      subtitleFailed: false,
      subtitleLoading: false,
      subtitleOffset: Duration.zero,
      loading: true,
      clearFailure: true,
    );
    _clearSubtitles();
    final number = state!.items[index].number;
    await _updateItem((item) => item.copyWith(currentItem: number));
    try {
      final all = await state!.items[index].sources;
      if (!_isCurrent(token)) return;
      final sources = all.whereType<VideoMediaItemSource>().toList();
      if (sources.isEmpty) {
        state = state!.copyWith(loading: false, failure: PlayerFailure.noSources);
        return;
      }
      final subtitles = all.whereType<SubtitleMediaItemSource>().toList();
      final subtitleIndex = chooseSubtitles(subtitles, _latest.currentSubtitleName);
      state = state!.copyWith(
        sources: sources,
        sourceIndex: chooseSource(sources, _latest.currentSourceName),
        subtitles: subtitles,
        subtitleIndex: subtitleIndex,
      );
      if (subtitleIndex != null) {
        _lastSubtitleName = subtitles[subtitleIndex].description;
        unawaited(_loadSubtitles());
      }
      final settings = ref.read(playerSettingsProvider);
      final start = startPosition(
        settings.startFrom,
        remembered: _latest.positions[number],
        fixedSeconds: settings.fixedPosition,
      );
      await _openSource(token, Duration(seconds: start));
    } catch (e, st) {
      _fail(token, PlayerFailure.loadFailed, e, st);
    }
  }

  Future<void> _openSource(int token, Duration start) async {
    final session = state!;
    final source = session.source!;
    _resumeAt = start;

    _log.fine('Opening source: $source');
    try {
      final link = await source.link;
      if (!_isCurrent(token)) return;
      final backend = _backend ??= _createBackend();
      await backend.open(
        VideoOpenRequest(
          link: link,
          headers: source.headers,
          start: start,
          hlsProxy: source.hlsProxy,
          languages: {ref.read(appLocaleProvider).languageCode, 'en'}.toList(),
        ),
      );
      if (!_isCurrent(token)) return;
      _playingNumber = session.item?.number;
      _lastProgressCheck = start;
      state = state!.copyWith(loading: false);
    } catch (e, st) {
      _fail(token, PlayerFailure.loadFailed, e, st);
    }
  }

  VideoBackend _createBackend() {
    final backend = ref.read(videoBackendFactoryProvider)();
    backend.status.addListener(_onStatus);
    _subscriptions
      ..add(backend.ended.listen((_) => unawaited(_onEnded())))
      ..add(backend.errors.listen(_onPlaybackError))
      ..add(backend.upscalerFailures.listen(_onUpscalerFailed));
    final volume = ref.read(appPreferencesProvider).getDouble(AppPreferences.volume);
    if (volume != null) unawaited(backend.setVolume(volume));
    if (_speed != 1) unawaited(backend.setSpeed(_speed));
    final effects = ref.read(playerSettingsProvider).audioEffects;
    if (!effects.isNeutral) unawaited(backend.setAudioEffects(effects));
    final upscaler = upscalerById(ref.read(playerSettingsProvider).upscaler);
    if (upscaler != null && backend.supportedUpscalers.contains(upscaler)) unawaited(backend.setUpscaler(upscaler));
    return backend;
  }

  Future<void> _disposeBackend() async {
    final backend = _backend;
    _backend = null;
    if (backend == null) return;
    backend.status.removeListener(_onStatus);
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
    await backend.dispose();
  }

  void _onStatus() {
    final status = _backend?.status.value;
    if (status == null) return;
    _refreshSubtitleLines();
    if (_playingNumber == null) return;
    _resumeAt = status.position;
    if (!status.playing || (status.position - _lastProgressCheck).abs() >= _progressInterval) {
      _lastProgressCheck = status.position;
      unawaited(_saveProgress());
    }
  }

  /// Spec-06 §6.5 on-end action; shuffle picks the next item at random.
  Future<void> _onEnded() async {
    await _saveProgress();
    final session = state;
    if (session == null) return;
    final settings = ref.read(playerSettingsProvider);
    switch (settings.endAction) {
      case EndAction.playNext:
        final next = nextItemIndex(session.itemIndex, session.items.length, shuffle: settings.shuffle);
        if (next != null) await selectItem(next);
      case EndAction.playAgain:
        await _openSource(++_token, Duration.zero);
      case EndAction.doNothing:
        break;
    }
  }

  void _onPlaybackError(String message) {
    _log.warning('Playback failed: $message');
    _playingNumber = null;
    if (state != null) state = state!.copyWith(loading: false, failure: PlayerFailure.playbackFailed);
  }

  /// Off for good: the same shader would fail again next time (spec-13 §13.5).
  void _onUpscalerFailed(Upscaler upscaler) {
    _log.warning('Upscaler ${upscaler.id} failed; turned off');
    final settings = ref.read(playerSettingsProvider.notifier);
    if (ref.read(playerSettingsProvider).upscaler == upscaler.id) unawaited(settings.setUpscaler(null));
    _upscalerFailures.add(upscaler);
  }

  void _fail(int token, PlayerFailure failure, Object error, StackTrace stackTrace) {
    _log.warning('Player load failed', error, stackTrace);
    if (_isCurrent(token) && state != null) state = state!.copyWith(loading: false, failure: failure);
  }

  void _clearSubtitles() {
    _subtitleToken++;
    _subtitleTrack = null;
    _subtitleLines.value = const [];
  }

  Future<void> _loadSubtitles() async {
    _clearSubtitles();
    final token = _subtitleToken;
    final session = state;
    final source = session?.subtitle;
    if (session == null) return;
    state = session.copyWith(subtitleLoading: source != null, subtitleFailed: false);

    _log.fine('Loading subtitles for source: $source');
    if (source == null) return;
    try {
      final track = await ref
          .read(subtitleRepositoryProvider)
          .load(subtitleCacheKey(session.supplier, session.id, session.item!.number, source.description), source);
      if (!ref.mounted || token != _subtitleToken) return;
      _subtitleTrack = track;
      if (state != null) state = state!.copyWith(subtitleLoading: false);
      _refreshSubtitleLines();
    } catch (e, st) {
      _log.warning('Subtitles failed to load', e, st);
      if (ref.mounted && token == _subtitleToken && state != null) {
        state = state!.copyWith(subtitleLoading: false, subtitleFailed: true);
      }
    }
  }

  void _refreshSubtitleLines() {
    final track = _subtitleTrack;
    final lines = track == null
        ? const <String>[]
        : track.linesAt(status.value.position, offset: state?.subtitleOffset ?? Duration.zero);
    if (!listEquals(lines, _subtitleLines.value)) _subtitleLines.value = lines;
  }

  /// [_base] merged with the latest synced data, keeping this session's title/image.
  CollectionItem get _latest {
    final stored = ref.read(collectionItemsProvider).value?[_base.key];
    return stored?.copyWith(title: _base.title, image: _base.image) ?? _base;
  }

  /// Applies [change]; persists only items that are in the collection (saving `status == none` deletes).
  Future<void> _updateItem(CollectionItem Function(CollectionItem item) change) async {
    final updated = change(_latest);
    _base = updated;
    if (updated.status != CollectionStatus.none) {
      await ref.read(collectionItemsProvider.notifier).save(updated);
    }
  }

  Future<void> _saveProgress() async {
    final number = _playingNumber;
    final backend = _backend;
    if (number == null || backend == null) return;
    final status = backend.status.value;
    final updated = updateVideoProgress(
      _latest,
      itemIndex: number,
      position: status.position.inSeconds,
      length: status.duration.inSeconds,
    );
    if (updated == null) return;
    _base = updated;
    await ref.read(collectionItemsProvider.notifier).save(updated);
  }
}
