import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/widgets/side_sheet.dart';
import '../../../../app/widgets/stepper_tile.dart';
import '../../../../core/localization.dart';
import '../../../../core/platform/device_class.dart';
import '../../data/video_backend.dart';
import '../../domain/equalizer.dart';
import '../../domain/player_preferences.dart';
import '../../domain/player_session.dart';
import '../../domain/upscaling.dart';
import '../player_controller.dart';
import '../player_settings.dart';
import '../subtitle_size.dart';
import 'player_widgets.dart';

String audioTrackLabel(BuildContext context, MediaTrack track, int index) =>
    track.title ?? track.language ?? context.l10n.playerTrack(index + 1);

String qualityLabel(BuildContext context, MediaTrack track, int index) => switch (track) {
  MediaTrack(:final height?) => '${height}p',
  MediaTrack(:final title?) => title,
  MediaTrack(:final bitrate?) => '${(bitrate / 1000).round()} kbps',
  _ => context.l10n.playerTrack(index + 1),
};

/// Signed seconds with one decimal, e.g. `+0.5`, `−1.0`.
String formatSubtitleOffset(Duration offset) =>
    '${offset.isNegative ? '−' : '+'}${(offset.inMilliseconds.abs() / 1000).toStringAsFixed(1)}';

/// Shows or hides subtitles (spec-06 §6.5.1); absent when the item has no supplier subtitles.
class SubtitlesToggleButton extends ConsumerWidget {
  final PlayerSession session;
  final String? shortcut;

  const SubtitlesToggleButton({super.key, required this.session, this.shortcut});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (session.subtitles.isEmpty) return const SizedBox.shrink();
    final on = session.subtitleIndex != null;
    return IconButton(
      key: const Key('subtitlesButton'),
      tooltip: tooltipWithShortcut(
        context,
        on ? context.l10n.playerHideSubtitles : context.l10n.playerShowSubtitles,
        shortcut,
      ),
      onPressed: () => unawaited(ref.read(playerControllerProvider.notifier).toggleSubtitles()),
      icon: Icon(subtitlesToggleIcon(on: on)),
    );
  }
}

IconData subtitlesToggleIcon({required bool on}) => on ? Icons.closed_caption : Icons.closed_caption_off_outlined;

class PlayerSettingsButton extends StatelessWidget {
  final String? shortcut;

  const PlayerSettingsButton({super.key, this.shortcut});

  @override
  Widget build(BuildContext context) => IconButton(
    key: const Key('settingsButton'),
    tooltip: tooltipWithShortcut(context, context.l10n.playerSettings, shortcut),
    onPressed: () => showPlayerSettings(context),
    icon: const Icon(Icons.settings_outlined),
  );
}

/// Settings in a side sheet on every device: a root list of settings, each opening its own page.
Future<void> showPlayerSettings(BuildContext context) =>
    showSideSheet<void>(context, title: context.l10n.playerSettings, builder: (_) => const PlayerSettingsPanel());

/// Subtitle choices scroll; size and offset stay pinned below them.
class _SubtitlesPage extends ConsumerWidget {
  static const _offsetStep = Duration(milliseconds: 500);

  final PlayerSession session;

  const _SubtitlesPage({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final controller = ref.read(playerControllerProvider.notifier);
    final size = ref.watch(subtitleSizeProvider);
    final sizeNotifier = ref.read(subtitleSizeProvider.notifier);
    final offset = session.subtitleOffset;
    return Column(
      children: [
        Expanded(
          child: _ClippedInk(
            child: ListView(
              children: [
                _Choice(
                  key: const ValueKey('subtitle-off'),
                  label: l10n.playerSubtitlesOff,
                  selected: session.subtitleIndex == null,
                  onTap: () => unawaited(controller.selectSubtitles(null)),
                ),
                for (final (index, subtitle) in session.subtitles.indexed)
                  _Choice(
                    key: ValueKey('subtitle-$index'),
                    label: context.sourceLabel(subtitle),
                    selected: session.subtitleIndex == index,
                    error: session.subtitleIndex == index && session.subtitleFailed ? l10n.playerSubtitlesFailed : null,
                    loading: session.subtitleIndex == index && session.subtitleLoading,
                    onTap: () => unawaited(controller.selectSubtitles(index)),
                  ),
              ],
            ),
          ),
        ),
        StepperTile(
          key: const ValueKey('subtitleSize'),
          label: l10n.playerSubtitleSize,
          value: size.round().toString(),
          onDecrease: size > SubtitleSize.min ? () => sizeNotifier.set(size - SubtitleSize.step) : null,
          onIncrease: size < SubtitleSize.max ? () => sizeNotifier.set(size + SubtitleSize.step) : null,
        ),
        StepperTile(
          key: const ValueKey('subtitleOffset'),
          label: l10n.playerSubtitleOffset,
          value: l10n.playerSubtitleOffsetValue(formatSubtitleOffset(offset)),
          onDecrease: () => controller.setSubtitleOffset(offset - _offsetStep),
          onIncrease: () => controller.setSubtitleOffset(offset + _offsetStep),
        ),
      ],
    );
  }
}

/// Selected tile backgrounds are ink on the nearest Material; clip it to the list so scrolled tiles never paint
/// over the header above.
class _ClippedInk extends StatelessWidget {
  final Widget child;

  const _ClippedInk({required this.child});

  @override
  Widget build(BuildContext context) =>
      Material(type: MaterialType.transparency, clipBehavior: Clip.hardEdge, child: child);
}

/// Settings pages; the root lists one row per page with its current value.
enum _SettingsPage { subtitles, audio, quality, upscaling, speed, equalizer, startFrom, endAction }

/// Root list of settings; a row opens its page in place, with a pinned back header. Back (key or header) returns
/// to the root and focuses the row that was opened.
class PlayerSettingsPanel extends ConsumerStatefulWidget {
  const PlayerSettingsPanel({super.key});

  @override
  ConsumerState<PlayerSettingsPanel> createState() => _PlayerSettingsPanelState();
}

class _PlayerSettingsPanelState extends ConsumerState<PlayerSettingsPanel> {
  static const _fixedPositionStep = 10;

  _SettingsPage? _page;
  _SettingsPage? _returnedFrom;

  PlayerController get _controller => ref.read(playerControllerProvider.notifier);
  PlayerSettings get _settings => ref.read(playerSettingsProvider.notifier);

  void _open(_SettingsPage page) => setState(() => _page = page);

  void _back() => setState(() {
    _returnedFrom = _page;
    _page = null;
  });

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(playerControllerProvider);
    final settings = ref.watch(playerSettingsProvider);
    if (session == null) return const SizedBox.shrink();
    return PopScope(
      canPop: _page == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: ValueListenableBuilder(
        valueListenable: _controller.tracks,
        builder: (context, tracks, _) => switch (_page) {
          null => _root(session, tracks, settings),
          final page => Column(
            children: [
              ListTile(
                key: const ValueKey('settings-back'),
                leading: const Icon(Icons.arrow_back),
                title: Text(_title(page), style: Theme.of(context).textTheme.titleMedium),
                onTap: _back,
              ),
              Expanded(
                child: page == _SettingsPage.subtitles
                    ? _SubtitlesPage(session: session)
                    : _ClippedInk(child: ListView(children: _choices(page, session, tracks, settings))),
              ),
            ],
          ),
        },
      ),
    );
  }

  Widget _root(PlayerSession session, PlaybackTracks tracks, PlayerPreferences settings) {
    final l10n = context.l10n;
    final startFrom = settings.startFrom == StartFrom.fromFixedPosition
        ? '${startFromLabel(l10n, settings.startFrom)} · ${formatPlaybackTime(Duration(seconds: settings.fixedPosition))}'
        : startFromLabel(l10n, settings.startFrom);
    final rows = [
      if (session.subtitles.isNotEmpty)
        (
          page: _SettingsPage.subtitles,
          value: session.subtitle == null ? l10n.playerSubtitlesOff : context.sourceLabel(session.subtitle!),
        ),
      if (tracks.audio.length > 1) (page: _SettingsPage.audio, value: _currentAudio(tracks)),
      if (tracks.video.length > 1) (page: _SettingsPage.quality, value: _currentQuality(tracks)),
      // Desktop only; hidden where no upscaler can run (spec-13 §13.6).
      if (_controller.supportedUpscalers.isNotEmpty)
        (page: _SettingsPage.upscaling, value: upscalerLabel(l10n, _controller.upscaler)),
      (page: _SettingsPage.speed, value: speedLabel(l10n, session.speed)),
      (page: _SettingsPage.equalizer, value: equalizerPresetLabel(l10n, settings.equalizerPreset)),
      (page: _SettingsPage.startFrom, value: startFrom),
      (page: _SettingsPage.endAction, value: endActionLabel(l10n, settings.endAction)),
    ];
    return _ClippedInk(
      child: ListView(
        children: [
          for (final (index, row) in rows.indexed)
            ListTile(
              key: ValueKey('settings-${row.page.name}'),
              autofocus: _returnedFrom == null ? index == 0 : row.page == _returnedFrom,
              title: Text(_title(row.page)),
              subtitle: Text(row.value),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(row.page),
            ),
          SwitchListTile(
            key: const ValueKey('settings-shuffle'),
            title: Text(l10n.playerShuffle),
            value: settings.shuffle,
            onChanged: (value) => unawaited(_settings.setShuffle(value)),
          ),
          // No floating player on TV (spec-06 §6.8).
          if (ref.watch(deviceClassProvider) != DeviceClass.tv)
            SwitchListTile(
              key: const ValueKey('settings-floating'),
              title: Text(l10n.playerFloating),
              subtitle: Text(l10n.playerFloatingDescription),
              value: settings.floatingPlayer,
              onChanged: (value) => unawaited(_settings.setFloatingPlayer(value)),
            ),
        ],
      ),
    );
  }

  String _title(_SettingsPage page) => switch (page) {
    _SettingsPage.subtitles => context.l10n.playerSubtitles,
    _SettingsPage.audio => context.l10n.playerAudio,
    _SettingsPage.quality => context.l10n.playerQuality,
    _SettingsPage.upscaling => context.l10n.playerUpscaling,
    _SettingsPage.speed => context.l10n.playerSpeed,
    _SettingsPage.equalizer => context.l10n.playerEqualizer,
    _SettingsPage.startFrom => context.l10n.playerStartFrom,
    _SettingsPage.endAction => context.l10n.playerOnEnd,
  };

  List<Widget> _choices(_SettingsPage page, PlayerSession session, PlaybackTracks tracks, PlayerPreferences settings) {
    final l10n = context.l10n;
    return switch (page) {
      // Built by _SubtitlesPage: its size and offset stay pinned under the list.
      _SettingsPage.subtitles => const [],
      _SettingsPage.audio => [
        _Choice(
          key: const ValueKey('audio-auto'),
          label: l10n.playerAuto,
          selected: tracks.audioId == null,
          onTap: () => _choose(() => _controller.selectAudioTrack(null)),
        ),
        for (final (index, track) in tracks.audio.indexed)
          _Choice(
            key: ValueKey('audio-${track.id}'),
            label: audioTrackLabel(context, track, index),
            selected: tracks.audioId == track.id,
            onTap: () => _choose(() => _controller.selectAudioTrack(track.id)),
          ),
      ],
      _SettingsPage.quality => [
        _Choice(
          key: const ValueKey('quality-auto'),
          label: l10n.playerAuto,
          selected: tracks.videoId == null,
          onTap: () => _choose(() => _controller.selectVideoTrack(null)),
        ),
        for (final (index, track) in [
          ...tracks.video.indexed,
        ]..sort((a, b) => (b.$2.height ?? 0).compareTo(a.$2.height ?? 0)))
          _Choice(
            key: ValueKey('quality-${track.id}'),
            label: qualityLabel(context, track, index),
            selected: tracks.videoId == track.id,
            onTap: () => _choose(() => _controller.selectVideoTrack(track.id)),
          ),
      ],
      _SettingsPage.upscaling => _upscalingChoices(),
      _SettingsPage.speed => [
        for (final value in playbackSpeeds)
          _Choice(
            key: ValueKey('speed-$value'),
            label: speedLabel(l10n, value),
            selected: value == session.speed,
            onTap: () => _choose(() => _controller.setSpeed(value)),
          ),
      ],
      // Stays open: presets and per-band gains are tuned together.
      _SettingsPage.equalizer => [
        for (final preset in EqualizerPreset.values)
          _Choice(
            key: ValueKey('equalizer-${preset.name}'),
            label: equalizerPresetLabel(l10n, preset),
            selected: settings.equalizerPreset == preset,
            onTap: () => unawaited(_controller.setEqualizer(preset.bands)),
          ),
        for (final (band, frequency) in equalizerFrequencies.indexed)
          StepperTile(
            key: ValueKey('equalizer-band-$band'),
            label: frequencyLabel(l10n, frequency),
            value: gainLabel(l10n, settings.equalizer[band]),
            onDecrease: settings.equalizer[band] > -equalizerMaxGain
                ? () => _setBand(settings.equalizer, band, settings.equalizer[band] - 1)
                : null,
            onIncrease: settings.equalizer[band] < equalizerMaxGain
                ? () => _setBand(settings.equalizer, band, settings.equalizer[band] + 1)
                : null,
          ),
        SwitchListTile(
          key: const ValueKey('equalizer-volume-normalization'),
          title: Text(l10n.playerVolumeNormalization),
          subtitle: Text(l10n.playerVolumeNormalizationDescription),
          value: settings.volumeNormalization,
          onChanged: (value) => unawaited(_controller.setVolumeNormalization(value)),
        ),
        SwitchListTile(
          key: const ValueKey('equalizer-dynamic-compression'),
          title: Text(l10n.playerDynamicCompression),
          subtitle: Text(l10n.playerDynamicCompressionDescription),
          value: settings.dynamicCompression,
          onChanged: (value) => unawaited(_controller.setDynamicCompression(value)),
        ),
      ],
      _SettingsPage.startFrom => [
        for (final value in StartFrom.values)
          _Choice(
            key: ValueKey('startFrom-${value.name}'),
            label: startFromLabel(l10n, value),
            selected: settings.startFrom == value,
            // A fixed position still needs its time, so the page stays open for it.
            onTap: value == StartFrom.fromFixedPosition
                ? () => unawaited(_settings.setStartFrom(value))
                : () => _choose(() => _settings.setStartFrom(value)),
          ),
        if (settings.startFrom == StartFrom.fromFixedPosition)
          StepperTile(
            key: const ValueKey('fixedPosition'),
            label: l10n.playerFixedPosition,
            value: formatPlaybackTime(Duration(seconds: settings.fixedPosition)),
            onDecrease: settings.fixedPosition > 0
                ? () => _settings.setFixedPosition(settings.fixedPosition - _fixedPositionStep)
                : null,
            onIncrease: () => _settings.setFixedPosition(settings.fixedPosition + _fixedPositionStep),
          ),
      ],
      _SettingsPage.endAction => [
        for (final value in EndAction.values)
          _Choice(
            key: ValueKey('endAction-${value.name}'),
            label: endActionLabel(l10n, value),
            selected: settings.endAction == value,
            onTap: () => _choose(() => _settings.setEndAction(value)),
          ),
      ],
    };
  }

  /// Off, then the supported presets grouped by family, each with its GPU cost.
  List<Widget> _upscalingChoices() {
    final l10n = context.l10n;
    final supported = _controller.supportedUpscalers;
    final current = _controller.upscaler;
    return [
      _Choice(
        key: const ValueKey('upscaler-off'),
        label: l10n.playerUpscalingOff,
        selected: current == null,
        onTap: () => _choose(() => _controller.setUpscaler(null)),
      ),
      for (final family in UpscalerFamily.values)
        if (supported.any((u) => u.family == family)) ...[
          _SectionHeader(upscalerFamilyLabel(l10n, family)),
          for (final upscaler in supported.where((u) => u.family == family))
            _Choice(
              key: ValueKey('upscaler-${upscaler.id}'),
              label: upscalerVariantLabel(l10n, upscaler),
              description: [
                upscalerCostLabel(l10n, upscaler.cost),
                if (upscaler.forAnime) l10n.playerUpscalerForAnime,
              ].join(' · '),
              selected: current == upscaler,
              onTap: () => _choose(() => _controller.setUpscaler(upscaler)),
            ),
        ],
      _Hint(l10n.playerUpscalingDescription),
    ];
  }

  String _currentAudio(PlaybackTracks tracks) {
    final current = tracks.audio.indexed.where((t) => t.$2.id == tracks.audioId).firstOrNull;
    return current == null ? context.l10n.playerAuto : audioTrackLabel(context, current.$2, current.$1);
  }

  String _currentQuality(PlaybackTracks tracks) {
    final current = tracks.video.indexed.where((t) => t.$2.id == tracks.videoId).firstOrNull;
    return current == null ? context.l10n.playerAuto : qualityLabel(context, current.$2, current.$1);
  }

  void _setBand(List<double> bands, int band, double gain) =>
      unawaited(_controller.setEqualizer([...bands]..[band] = gain));

  /// Applies a single choice and returns to the root, which shows the new value.
  void _choose(Future<void> Function() apply) {
    unawaited(apply());
    _back();
  }
}

/// Not focusable: a group title inside a choice list.
class _SectionHeader extends StatelessWidget {
  final String text;

  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(text, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;

  const _Hint(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Text(text, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
    );
  }
}

/// One option of a single-choice list; the selected one is checked and takes initial focus.
class _Choice extends StatelessWidget {
  final String label;
  final bool selected;
  final String? description;
  final String? error;
  final bool loading;
  final VoidCallback onTap;

  const _Choice({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.description,
    this.error,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      autofocus: selected,
      selected: selected,
      title: Text(label),
      subtitle: error != null
          ? Text(error!, style: TextStyle(color: theme.colorScheme.error))
          : description == null
          ? null
          : Text(description!),
      trailing: loading
          ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : selected
          ? const Icon(Icons.check)
          : null,
      onTap: onTap,
    );
  }
}
