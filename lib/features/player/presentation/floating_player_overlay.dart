import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../../core/localization.dart';
import '../../../core/platform/device_class.dart';
import '../domain/floating_layout.dart';
import '../domain/player_session.dart';
import 'floating_player.dart';
import 'player_controller.dart';
import 'player_theme.dart';
import 'widgets/compact_player_controls.dart';
import 'widgets/player_widgets.dart';
import 'widgets/subtitle_overlay.dart';

/// In-app mini player above all routes (spec-06 §6.9); place it in the app root `Stack`, after the router.
class FloatingPlayerOverlay extends ConsumerWidget {
  const FloatingPlayerOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(floatingPlayerProvider);
    final open = ref.watch(playerControllerProvider.select((session) => session != null));
    if (!visible || !open) return const SizedBox.shrink();
    // Beside the navigator, so without an Overlay: no tooltips here.
    return Positioned.fill(
      child: Theme(data: ref.watch(playerThemeProvider), child: const _FloatingPlayer()),
    );
  }
}

class _FloatingPlayer extends ConsumerStatefulWidget {
  const _FloatingPlayer();

  @override
  ConsumerState<_FloatingPlayer> createState() => _FloatingPlayerState();
}

class _FloatingPlayerState extends ConsumerState<_FloatingPlayer> {
  static const _mobileWidth = 220.0;
  static const _desktopWidth = 420.0;

  FloatingCorner _corner = FloatingCorner.bottomRight;
  Offset? _dragPosition;

  void _open(PlayerSession session) =>
      unawaited(ref.read(routerProvider).push(AppRoutes.video(session.supplier, session.id)));

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(playerControllerProvider);
    if (session == null) return const SizedBox.shrink();
    final mobile = switch (ref.watch(deviceClassProvider)) {
      DeviceClass.phone || DeviceClass.tablet => true,
      DeviceClass.desktop || DeviceClass.tv => false,
    };
    final width = mobile ? _mobileWidth : _desktopWidth;
    final player = Size(width, width * 9 / 16);
    final safe = MediaQuery.paddingOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final area = constraints.biggest;
        // Safe area is part of the edge distance on both sides, so corners stay symmetric.
        final horizontal = (mobile ? 16.0 : 10.0) + safe.horizontal / 2;
        final vertical = (mobile ? 32.0 : 10.0) + safe.vertical / 2;
        final (minX, maxX) = floatingRangeX(area: area, player: player, horizontal: horizontal);
        final (minY, maxY) = floatingRangeY(area: area, player: player, vertical: vertical);
        Offset corner(FloatingCorner value) =>
            floatingCornerOffset(value, area: area, player: player, horizontal: horizontal, vertical: vertical);
        Offset clamp(Offset value) => Offset(value.dx.clamp(minX, maxX), value.dy.clamp(minY, maxY));
        final drag = _dragPosition;
        final position = drag == null ? corner(_corner) : clamp(drag);

        return Stack(
          children: [
            AnimatedPositioned(
              duration: drag == null ? const Duration(milliseconds: 200) : Duration.zero,
              curve: Curves.easeOut,
              left: position.dx,
              top: position.dy,
              width: player.width,
              height: player.height,
              child: GestureDetector(
                key: const Key('floatingPlayer'),
                // Desktop opens the full player with the expand button; a click shows the controls there.
                onTap: mobile ? () => _open(session) : null,
                onPanStart: (_) => setState(() => _dragPosition = position),
                onPanUpdate: (details) =>
                    setState(() => _dragPosition = clamp((_dragPosition ?? position) + details.delta)),
                // Events can arrive without a frame in between: use the live drag, not this build's position.
                onPanEnd: (_) => setState(() {
                  final end = clamp(_dragPosition ?? position);
                  _corner = nearestFloatingCorner(end + player.center(Offset.zero), area);
                  _dragPosition = null;
                }),
                onPanCancel: () => setState(() => _dragPosition = null),
                child: mobile
                    ? Semantics(
                        button: true,
                        label: context.l10n.playerOpen,
                        child: _FloatingContent(session: session, mobile: true, onOpen: () => _open(session)),
                      )
                    : _FloatingContent(session: session, mobile: false, onOpen: () => _open(session)),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Video and scaled subtitles. Touch: play/pause and close always shown, a tap opens the full player. Desktop:
/// the controls of the desktop PiP window (spec-06 §6.9).
class _FloatingContent extends ConsumerWidget {
  final PlayerSession session;
  final bool mobile;
  final VoidCallback onOpen;

  const _FloatingContent({required this.session, required this.mobile, required this.onOpen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(playerControllerProvider.notifier);
    final status = controller.status;
    final video = controller.buildVideoView();
    final l10n = context.l10n;
    void close() => unawaited(ref.read(floatingPlayerProvider.notifier).close());
    final buttonStyle = IconButton.styleFrom(
      backgroundColor: Colors.black54,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.all(6),
      minimumSize: const Size.square(32),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    return Material(
      elevation: 8,
      color: Colors.black,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (video != null) Visibility(visible: session.showsVideo, maintainState: true, child: video),
          const ScaledSubtitleOverlay(),
          if (session.failure != null)
            const Center(child: Icon(Icons.error_outline, color: Colors.white70))
          else
            ValueListenableBuilder(
              valueListenable: status,
              builder: (context, status, _) => session.loading || status.buffering
                  ? const Center(
                      child: SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 3)),
                    )
                  : const SizedBox.shrink(),
            ),
          if (!mobile)
            CompactPlayerControls(
              session: session,
              expandLabel: l10n.playerOpen,
              onExpand: onOpen,
              closeLabel: l10n.playerClose,
              onClose: close,
            )
          else ...[
            Positioned(
              top: 6,
              left: 6,
              child: ValueListenableBuilder(
                valueListenable: status,
                builder: (context, status, _) => IconButton(
                  key: const Key('floatingPlayPause'),
                  style: buttonStyle,
                  iconSize: 20,
                  onPressed: controller.playOrPause,
                  icon: Icon(
                    status.playing ? Icons.pause : Icons.play_arrow,
                    semanticLabel: status.playing ? l10n.playerPause : l10n.playerPlay,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: IconButton(
                key: const Key('floatingClose'),
                style: buttonStyle,
                iconSize: 20,
                onPressed: close,
                icon: Icon(Icons.close, semanticLabel: l10n.playerClose),
              ),
            ),
            Positioned(left: 0, right: 0, bottom: 0, child: PlaybackProgressLine(status: status)),
          ],
        ],
      ),
    );
  }
}
