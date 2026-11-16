import 'dart:async';

import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/localization.dart';
import '../../../core/network/http_client.dart';
import '../../../core/storage/app_preferences.dart';
import '../../collection/domain/collection_item.dart';
import '../../collection/domain/progress.dart';
import '../../collection/presentation/collection_providers.dart';
import '../../details/presentation/details_providers.dart';
import '../data/media_kit_backend.dart';
import '../data/subtitle_repository.dart';
import '../data/video_backend.dart';
import '../domain/equalizer.dart';
import '../domain/player_preferences.dart';
import '../domain/player_session.dart';
import '../domain/subtitles.dart';
import 'player_settings.dart';

part 'player_controller.g.dart';

final _log = Logger('PlayerController');

@Riverpod(keepAlive: true)
VideoBackend Function() videoBackendFactory(Ref ref) {
  final client = ref.watch(httpClientProvider);
  return () => MediaKitVideoBackend(client);
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
  SubtitleTrack? _subtitleTrack;
  int _subtitleToken = 0;

  /// Incremented by every load; async steps of an older load stop when it changed (spec-06 §6.2.7).
  int _token = 0;
  double _speed = 1;

  /// Item index the backend is currently playing; null while loading, so stale positions are never saved.
  int? _playingIndex;
  CollectionItem? _base;
  Duration _lastProgressCheck = Duration.zero;
  Duration _resumeAt = Duration.zero;

  @override
  PlayerSession? build() {
    ref.onDispose(() => unawaited(_disposeBackend()));
    return null;
  }

  ValueListenable<PlaybackStatus> get status => _backend?.status ?? _idleStatus;

  ValueListenable<PlaybackTracks> get tracks => _backend?.tracks ?? _idleTracks;

  /// Lines of the selected supplier subtitles at the current position (with the offset).
  ValueListenable<List<String>> get subtitleLines => _subtitleLines;

  Widget? buildVideoView() => _backend?.buildView();

  Future<void> open(String supplier, String id, {int? item}) async {
    await _saveProgress();
    final token = ++_token;
    _playingIndex = null;
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
      await _openItem(token, (item ?? _base!.currentItem).clamp(0, items.length - 1));
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
    _playingIndex = null;
    state = session.copyWith(sourceIndex: index, loading: true, clearFailure: true);
    await _updateItem((item) => item.copyWith(currentSourceName: session.sources[index].description));
    await _openSource(token, position);
  }

  /// Supplier subtitles by index; null turns them off. The choice is remembered as `currentSubtitleName`.
  Future<void> selectSubtitles(int? index) async {
    final session = state;
    if (session == null || (index != null && (index < 0 || index >= session.subtitles.length))) return;
    state = session.copyWith(subtitleIndex: index, clearSubtitle: index == null, subtitleFailed: false);
    // Loading starts (and shows) before the collection write finishes.
    final load = _loadSubtitles();
    final name = index == null ? null : session.subtitles[index].description;
    await _updateItem((item) => item.copyWith(currentSubtitleName: name, clearSubtitleName: name == null));
    await load;
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
  Future<void> setEqualizer(List<double> bands) async {
    await ref.read(playerSettingsProvider.notifier).setEqualizer(bands);
    await _backend?.setAudioFilter(equalizerFilter(ref.read(playerSettingsProvider).equalizer));
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
    _playingIndex = null;
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

  bool _isCurrent(int token) => ref.mounted && token == _token;

  Future<void> _openItem(int token, int index) async {
    _playingIndex = null;
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
    await _updateItem((item) => item.copyWith(currentItem: index));
    try {
      final all = await state!.items[index].sources;
      if (!_isCurrent(token)) return;
      final sources = all.whereType<VideoMediaItemSource>().toList();
      if (sources.isEmpty) {
        state = state!.copyWith(loading: false, failure: PlayerFailure.noSources);
        return;
      }
      final subtitles = all.whereType<SubtitleMediaItemSource>().toList();
      final subtitleIndex = chooseSubtitles(subtitles, _latest?.currentSubtitleName);
      state = state!.copyWith(
        sources: sources,
        sourceIndex: chooseSource(sources, _latest?.currentSourceName),
        subtitles: subtitles,
        subtitleIndex: subtitleIndex,
      );
      if (subtitleIndex != null) unawaited(_loadSubtitles());
      final settings = ref.read(playerSettingsProvider);
      final start = startPosition(
        settings.startFrom,
        remembered: _latest?.positions[index],
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
      _playingIndex = session.itemIndex;
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
      ..add(backend.errors.listen(_onPlaybackError));
    final volume = ref.read(appPreferencesProvider).getDouble(AppPreferences.volume);
    if (volume != null) unawaited(backend.setVolume(volume));
    if (_speed != 1) unawaited(backend.setSpeed(_speed));
    final filter = equalizerFilter(ref.read(playerSettingsProvider).equalizer);
    if (filter.isNotEmpty) unawaited(backend.setAudioFilter(filter));
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
    if (_playingIndex == null) return;
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
    _playingIndex = null;
    if (state != null) state = state!.copyWith(loading: false, failure: PlayerFailure.playbackFailed);
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
    if (source == null) return;
    try {
      final track = await ref
          .read(subtitleRepositoryProvider)
          .load(subtitleCacheKey(session.supplier, session.id, session.itemIndex, source.description), source);
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

  /// Collection item with the latest synced data, refreshed with this session's title/image.
  CollectionItem? get _latest {
    final base = _base;
    if (base == null) return null;
    final stored = ref.read(collectionItemsProvider).value?[base.key];
    return stored?.copyWith(title: base.title, image: base.image) ?? base;
  }

  /// Applies [change]; persists only items that are in the collection (saving `status == none` deletes).
  Future<void> _updateItem(CollectionItem Function(CollectionItem item) change) async {
    final latest = _latest;
    if (latest == null) return;
    final updated = change(latest);
    _base = updated;
    if (updated.status != CollectionStatus.none) {
      await ref.read(collectionItemsProvider.notifier).save(updated);
    }
  }

  Future<void> _saveProgress() async {
    final index = _playingIndex;
    final latest = _latest;
    final backend = _backend;
    if (index == null || latest == null || backend == null) return;
    final status = backend.status.value;
    final updated = updateVideoProgress(
      latest,
      itemIndex: index,
      position: status.position.inSeconds,
      length: status.duration.inSeconds,
    );
    if (updated == null) return;
    _base = updated;
    await ref.read(collectionItemsProvider.notifier).save(updated);
  }
}
