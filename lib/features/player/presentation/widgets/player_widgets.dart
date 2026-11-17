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

enum SeekBarStyle {
  /// Desktop: thin track that thickens and shows a small thumb only while hovered or dragged; hover shows the time.
  hover,

  /// Touch: thick track flush with the screen edges, no thumb; the drag target is reported via `onDragTarget`.
  edge,
}

/// Seek bar with the buffered range; seeks when the drag ends.
class PlayerSeekBar extends StatefulWidget {
  static const hoverTrackHeight = 3.0;
  static const hoverActiveTrackHeight = 6.0;
  static const edgeTrackHeight = 12.0;

  /// Edge style: whole touchable height, the track included.
  static const edgeTouchHeight = 26.0;

  final ValueListenable<PlaybackStatus> status;
  final ValueChanged<Duration> onSeek;

  /// Target position while dragging; `null` when the drag ends.
  final ValueChanged<Duration?>? onDragTarget;

  /// Keyboard-focusable; desktop turns it off so the arrow keys keep seeking by the key map.
  final bool focusable;

  final SeekBarStyle style;

  const PlayerSeekBar({
    super.key,
    required this.status,
    required this.onSeek,
    this.onDragTarget,
    this.focusable = true,
    required this.style,
  });

  @override
  State<PlayerSeekBar> createState() => _PlayerSeekBarState();
}

class _PlayerSeekBarState extends State<PlayerSeekBar> {
  late final _focusNode = FocusNode(canRequestFocus: widget.focusable, skipTraversal: !widget.focusable);
  double? _dragValue;
  bool _hovered = false;
  double? _hoverX;

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
      double clamp(Duration d) => d.inMilliseconds.clamp(0, max).toDouble();
      final slider = max <= 0
          ? Slider(key: const Key('seekBar'), value: 0, focusNode: _focusNode, onChanged: null)
          : Slider(
              key: const Key('seekBar'),
              focusNode: _focusNode,
              max: max,
              value: _dragValue ?? clamp(status.position),
              secondaryTrackValue: clamp(status.buffered),
              onChanged: (v) {
                setState(() => _dragValue = v);
                widget.onDragTarget?.call(Duration(milliseconds: v.round()));
              },
              onChangeEnd: (v) {
                widget.onSeek(Duration(milliseconds: v.round()));
                setState(() => _dragValue = null);
                widget.onDragTarget?.call(null);
              },
            );

      final edge = widget.style == SeekBarStyle.edge;
      final side = edge ? 0.0 : 8.0;
      final dragging = _dragValue != null;
      final active = _hovered || dragging;
      final themed = SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: edge
              ? PlayerSeekBar.edgeTrackHeight
              : (active ? PlayerSeekBar.hoverActiveTrackHeight : PlayerSeekBar.hoverTrackHeight),
          thumbShape: !edge && active
              ? const RoundSliderThumbShape(enabledThumbRadius: 6, elevation: 0, pressedElevation: 0)
              : SliderComponentShape.noThumb,
          overlayShape: edge
              ? const _TouchAreaShape(Size(0, PlayerSeekBar.edgeTouchHeight))
              : SliderComponentShape.noOverlay,
          trackShape: edge ? const _BottomTrackShape() : null,
          // Edge: sizing comes from the overlay shape, since Slider theme padding is not touchable.
          padding: edge ? null : EdgeInsets.symmetric(horizontal: side, vertical: 12),
        ),
        child: slider,
      );
      final content = LayoutBuilder(
        builder: (context, constraints) {
          final track = constraints.maxWidth - 2 * side;
          final x = dragging ? side + _dragValue! / max * track : _hoverX;
          final show = x != null && max > 0 && track > 0;
          final time = show ? Duration(milliseconds: ((x - side) / track * max).clamp(0, max).round()) : Duration.zero;
          // Always a Stack, so the slider keeps its state when the indicator appears.
          return Stack(
            clipBehavior: Clip.none,
            children: [
              themed,
              if (show && !dragging)
                Positioned(
                  left: x - 1,
                  top: 0,
                  bottom: 0,
                  child: const IgnorePointer(
                    child: Center(
                      child: SizedBox(width: 2, height: 14, child: ColoredBox(color: Colors.white)),
                    ),
                  ),
                ),
              // Kept inside the bar so the label never leaves the screen at the ends.
              if (show && !edge)
                Positioned(
                  left: x.clamp(28.0, constraints.maxWidth - 28),
                  top: 4,
                  child: IgnorePointer(
                    child: FractionalTranslation(
                      translation: const Offset(-0.5, -1),
                      child: _SeekTimeLabel(time: time),
                    ),
                  ),
                ),
            ],
          );
        },
      );
      if (edge) return content;
      return MouseRegion(
        onEnter: (event) => setState(() {
          _hovered = true;
          _hoverX = event.localPosition.dx;
        }),
        onHover: (event) => setState(() => _hoverX = event.localPosition.dx),
        onExit: (_) => setState(() {
          _hovered = false;
          _hoverX = null;
        }),
        child: content,
      );
    },
  );
}

class _TouchAreaShape extends SliderComponentShape {
  final Size size;

  const _TouchAreaShape(this.size);

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => size;

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {}
}

/// Full-width track on the bottom edge of the slider's touch area.
class _BottomTrackShape extends RectangularSliderTrackShape {
  const _BottomTrackShape();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final height = sliderTheme.trackHeight!;
    return Rect.fromLTWH(offset.dx, offset.dy + parentBox.size.height - height, parentBox.size.width, height);
  }
}

class _SeekTimeLabel extends StatelessWidget {
  final Duration time;

  const _SeekTimeLabel({required this.time});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: const Key('seekHoverTime'),
    decoration: const BoxDecoration(color: Color(0xE6000000), borderRadius: BorderRadius.all(Radius.circular(6))),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Text(
        formatPlaybackTime(time),
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: Colors.white, fontFeatures: const [FontFeature.tabularFigures()]),
      ),
    ),
  );
}

/// Seek target with the offset from where seeking started, e.g. "12:30  +25 с".
class SeekTargetLabel extends StatelessWidget {
  final Duration from;
  final Duration to;

  const SeekTargetLabel({super.key, required this.from, required this.to});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final offset = (to - from).inSeconds;
    return DecoratedBox(
      decoration: const ShapeDecoration(color: Color(0x99000000), shape: StadiumBorder()),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: formatPlaybackTime(to), style: theme.textTheme.titleMedium),
              TextSpan(
                text: '  ${offset >= 0 ? l10n.playerSeekForward(offset) : l10n.playerSeekBackward(-offset)}',
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
              ),
            ],
          ),
          style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
        ),
      ),
    );
  }
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
  final ButtonStyle? style;

  /// Off: the label is only announced by screen readers.
  final bool tooltip;

  const PlayPauseButton({
    super.key,
    required this.status,
    required this.onPressed,
    this.focusNode,
    this.iconSize,
    this.style,
    this.tooltip = true,
  });

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: status,
    builder: (context, status, _) {
      final label = status.playing ? context.l10n.playerPause : context.l10n.playerPlay;
      return IconButton(
        key: const Key('playPauseButton'),
        focusNode: focusNode,
        iconSize: iconSize,
        style: style,
        tooltip: tooltip ? label : null,
        onPressed: onPressed,
        icon: Icon(status.playing ? Icons.pause : Icons.play_arrow, semanticLabel: tooltip ? null : label),
      );
    },
  );
}

/// Thin, non-interactive playback progress along the bottom edge (mini player, PiP).
class PlaybackProgressLine extends StatelessWidget {
  final ValueListenable<PlaybackStatus> status;

  const PlaybackProgressLine({super.key, required this.status});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: status,
    builder: (context, status, _) {
      final duration = status.duration.inMilliseconds;
      return LinearProgressIndicator(
        minHeight: 3,
        value: duration <= 0 ? 0 : (status.position.inMilliseconds / duration).clamp(0.0, 1.0),
        backgroundColor: Colors.white24,
      );
    },
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

  /// TV leaves it out: the remote's Back key already hides the controls, then exits.
  final bool back;

  // Close to the shell rail's back button (rail: 80 wide, 8 from the top), so back navigation doesn't jump.
  final EdgeInsetsGeometry padding;

  const PlayerTopBar({
    super.key,
    required this.session,
    this.actions = const [],
    this.back = true,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 0, 0),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itemTitle = session.items.length > 1 ? session.item?.title : null;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (back) ...[const BackButton(), const SizedBox(width: 8)],
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

  /// For D-pad controls, which move focus to Retry themselves.
  final FocusNode? retryFocus;

  const PlayerFailureView({super.key, required this.session, this.retryFocus});

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
                  FilledButton(
                    focusNode: retryFocus,
                    autofocus: true,
                    onPressed: controller.retry,
                    child: Text(l10n.commonRetry),
                  ),
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

/// Sources in a side sheet, opened with focus on the current one.
Future<void> showSourceSelector(BuildContext context, PlayerSession session, ValueChanged<int> onSelected) async {
  final selected = await showSideSheet<int>(
    context,
    title: context.l10n.playerSource,
    builder: (context) => ListView(
      children: [
        for (final (index, source) in session.sources.indexed)
          ListTile(
            key: ValueKey('source-$index'),
            autofocus: index == session.sourceIndex,
            selected: index == session.sourceIndex,
            title: Text(source.description),
            trailing: index == session.sourceIndex ? const Icon(Icons.check) : null,
            onTap: () => Navigator.of(context).pop(index),
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
