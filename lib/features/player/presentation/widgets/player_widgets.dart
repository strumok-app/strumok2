import 'dart:async';

import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/widgets/side_sheet.dart';
import '../../../../core/localization.dart';
import '../../../collection/presentation/collection_providers.dart';
import '../../../details/presentation/media_items_list.dart';
import '../../data/video_backend.dart';
import '../../domain/player_session.dart';
import '../player_controller.dart';

/// `m:ss` or `h:mm:ss`.
String formatPlaybackTime(Duration value) {
  final seconds = value.inSeconds.abs();
  final h = seconds ~/ 3600, m = seconds % 3600 ~/ 60, s = seconds % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
}

/// Controls overlay visibility with auto-hide after inactivity while playing.
class ControlsVisibility extends ChangeNotifier {
  static const hideDelay = Duration(seconds: 3);

  final ValueListenable<PlaybackStatus> Function() status;
  Timer? _timer;
  bool _visible = true;

  ControlsVisibility(this.status) {
    _arm();
  }

  bool get visible => _visible;

  void show() {
    _arm();
    if (_visible) return;
    _visible = true;
    notifyListeners();
  }

  void hide() {
    _timer?.cancel();
    if (!_visible) return;
    _visible = false;
    notifyListeners();
  }

  void toggle() => _visible ? hide() : show();

  void _arm() {
    _timer?.cancel();
    _timer = Timer(hideDelay, () => status().value.playing ? hide() : _arm());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Seek bar with the buffered range; seeks when the drag ends.
class PlayerSeekBar extends StatefulWidget {
  final ValueListenable<PlaybackStatus> status;
  final ValueChanged<Duration> onSeek;

  /// Keyboard-focusable; desktop turns it off so the arrow keys keep seeking by the key map.
  final bool focusable;

  const PlayerSeekBar({super.key, required this.status, required this.onSeek, this.focusable = true});

  @override
  State<PlayerSeekBar> createState() => _PlayerSeekBarState();
}

class _PlayerSeekBarState extends State<PlayerSeekBar> {
  late final _focusNode = FocusNode(canRequestFocus: widget.focusable, skipTraversal: !widget.focusable);
  double? _dragValue;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: widget.status,
    builder: (context, status, _) {
      final max = status.duration.inMilliseconds.toDouble();
      if (max <= 0) return Slider(key: const Key('seekBar'), value: 0, focusNode: _focusNode, onChanged: null);
      double clamp(Duration d) => d.inMilliseconds.clamp(0, max).toDouble();
      return Slider(
        key: const Key('seekBar'),
        focusNode: _focusNode,
        max: max,
        value: _dragValue ?? clamp(status.position),
        secondaryTrackValue: clamp(status.buffered),
        onChanged: (v) => setState(() => _dragValue = v),
        onChangeEnd: (v) {
          widget.onSeek(Duration(milliseconds: v.round()));
          setState(() => _dragValue = null);
        },
      );
    },
  );
}

class PlayerTimeLabel extends StatelessWidget {
  final ValueListenable<PlaybackStatus> status;

  const PlayerTimeLabel({super.key, required this.status});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: status,
    builder: (context, status, _) => Text(
      '${formatPlaybackTime(status.position)} / ${formatPlaybackTime(status.duration)}',
      style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
    ),
  );
}

class PlayPauseButton extends StatelessWidget {
  final ValueListenable<PlaybackStatus> status;
  final VoidCallback onPressed;
  final FocusNode? focusNode;
  final double? iconSize;

  const PlayPauseButton({super.key, required this.status, required this.onPressed, this.focusNode, this.iconSize});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: status,
    builder: (context, status, _) => IconButton(
      key: const Key('playPauseButton'),
      focusNode: focusNode,
      iconSize: iconSize,
      tooltip: status.playing ? context.l10n.playerPause : context.l10n.playerPlay,
      onPressed: onPressed,
      icon: Icon(status.playing ? Icons.pause : Icons.play_arrow),
    ),
  );
}

/// Spinner while loading or buffering.
class PlayerBufferingIndicator extends StatelessWidget {
  final PlayerSession session;
  final ValueListenable<PlaybackStatus> status;

  const PlayerBufferingIndicator({super.key, required this.session, required this.status});

  @override
  Widget build(BuildContext context) {
    if (session.failure != null) return const SizedBox.shrink();
    return ValueListenableBuilder(
      valueListenable: status,
      builder: (context, status, _) => session.loading || status.buffering
          ? const Center(child: CircularProgressIndicator())
          : const SizedBox.shrink(),
    );
  }
}

/// Back button, content title and the current episode title.
class PlayerTopBar extends StatelessWidget {
  final PlayerSession session;
  final List<Widget> actions;

  const PlayerTopBar({super.key, required this.session, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itemTitle = session.items.length > 1 ? session.item?.title : null;
    return Padding(
      // Close to the shell rail's back button (rail: 80 wide, 8 from the top), so back navigation doesn't jump.
      padding: const EdgeInsets.fromLTRB(20, 12, 0, 0),
      child: Row(
        children: [
          const BackButton(),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(session.title, style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (itemTitle != null && itemTitle.isNotEmpty)
                  Text(itemTitle, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// Scrim behind a control bar so it stays readable over bright video.
class ControlsScrim extends StatelessWidget {
  final Widget child;
  final bool top;

  const ControlsScrim({super.key, required this.child, required this.top});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: top ? Alignment.topCenter : Alignment.bottomCenter,
        end: top ? Alignment.bottomCenter : Alignment.topCenter,
        colors: const [Color(0xCC000000), Color(0x00000000)],
      ),
    ),
    child: SafeArea(top: top, bottom: !top, child: child),
  );
}

/// Failure message with Retry (focused) and, when there are alternatives, Change source.
class PlayerFailureView extends ConsumerWidget {
  final PlayerSession session;

  const PlayerFailureView({super.key, required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final controller = ref.read(playerControllerProvider.notifier);
    final message = switch (session.failure!) {
      PlayerFailure.noSources => l10n.playerNoSources,
      PlayerFailure.loadFailed => l10n.playerLoadFailed,
      PlayerFailure.playbackFailed => l10n.playerPlaybackFailed,
    };
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: [
              Text(message, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton(autofocus: true, onPressed: controller.retry, child: Text(l10n.commonRetry)),
                  if (session.sources.length > 1)
                    FilledButton.tonal(
                      onPressed: () => showSourceSelector(context, session, controller.selectSource),
                      child: Text(l10n.playerChangeSource),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SourceButton extends StatelessWidget {
  final PlayerSession session;
  final ValueChanged<int> onSelected;

  const SourceButton({super.key, required this.session, required this.onSelected});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: context.l10n.playerSource,
    onPressed: () => showSourceSelector(context, session, onSelected),
    icon: const Icon(Icons.dns_outlined),
  );
}

Future<void> showSourceSelector(BuildContext context, PlayerSession session, ValueChanged<int> onSelected) async {
  final selected = await showDialog<int>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(context.l10n.playerSource),
      children: [
        for (final (index, source) in session.sources.indexed)
          SimpleDialogOption(
            key: ValueKey('source-$index'),
            onPressed: () => Navigator.of(context).pop(index),
            child: Row(
              children: [
                Expanded(child: Text(source.description)),
                if (index == session.sourceIndex) const Icon(Icons.check),
              ],
            ),
          ),
      ],
    ),
  );
  if (selected != null && selected != session.sourceIndex) onSelected(selected);
}

class PlaylistButton extends StatelessWidget {
  final PlayerSession session;

  const PlaylistButton({super.key, required this.session});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: context.l10n.detailsEpisodes,
    onPressed: () => showPlaylistPanel(context, session),
    icon: const Icon(Icons.playlist_play),
  );
}

/// Episodes grouped by section with collection progress; picking one switches the player to it.
Future<void> showPlaylistPanel(BuildContext context, PlayerSession session) => showSideSheet(
  context,
  title: context.l10n.detailsEpisodes,
  builder: (context) => Consumer(
    builder: (context, ref, _) {
      final item = ref.watch(collectionItemProvider(session.supplier, session.id));
      return MediaItemsList(
        items: session.items,
        mediaType: MediaType.video,
        positions: item?.positions ?? const {},
        currentItem: session.item?.number,
        onSelected: (selected) {
          final controller = ref.read(playerControllerProvider.notifier);
          Navigator.of(context).pop();
          unawaited(controller.selectItem(session.items.indexOf(selected)));
        },
      );
    },
  ),
);
