import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization.dart';
import '../../../core/platform/device_class.dart';
import '../data/pip/pip.dart';
import '../domain/upscaling.dart';
import 'controls/desktop/desktop_controls.dart';
import 'controls/mobile/mobile_controls.dart';
import 'controls/tv/tv_controls.dart';
import 'floating_player.dart';
import 'pip_view.dart';
import 'player_controller.dart';
import 'player_fullscreen.dart';
import 'player_settings.dart';
import 'player_theme.dart';

/// Full-screen; outside the app shell, always in the dark player theme. Controls are picked by device class
/// (spec-06 §6.1). Leaving it hands a playing session to the floating player (spec-06 §6.9); PiP is allowed only
/// while it is shown (spec-06 §6.10).
class PlayerPage extends ConsumerStatefulWidget {
  final String supplier;
  final String id;

  /// Media item index to start; null resumes `currentItem` from the collection.
  final int? item;

  const PlayerPage({super.key, required this.supplier, required this.id, this.item});

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> {
  late final PlayerController _controller;
  late final PlayerFullscreen _fullscreen;
  late final FloatingPlayer _floating;
  late final Pip _pip;
  late final StreamSubscription<Upscaler> _upscalerFailures;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(playerControllerProvider.notifier);
    _fullscreen = ref.read(playerFullscreenProvider.notifier);
    _floating = ref.read(floatingPlayerProvider.notifier);
    _pip = ref.read(pipProvider);
    _upscalerFailures = _controller.upscalerFailures.listen(_onUpscalerFailed);
    _pip.isActive.addListener(_onPipChanged);
    unawaited(_pip.enable());
    // Providers must not change while the tree is building.
    unawaited(
      Future.microtask(() async {
        _floating.hide();
        await _controller.open(widget.supplier, widget.id, item: widget.item);
      }),
    );
  }

  @override
  void dispose() {
    unawaited(_upscalerFailures.cancel());
    _pip.isActive.removeListener(_onPipChanged);
    final pip = _pip, fullscreen = _fullscreen, floating = _floating;
    unawaited(
      Future.microtask(() async {
        // Decided right away: the playing state must not change while the window is restored.
        final leave = floating.leavePlayer();
        await pip.disable();
        await fullscreen.set(false);
        await leave;
      }),
    );
    super.dispose();
  }

  /// The controller already turned it off (spec-13 §13.5); say so once.
  void _onUpscalerFailed(Upscaler upscaler) {
    if (!mounted) return;
    final l10n = context.l10n;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.playerUpscalingFailed(upscalerLabel(l10n, upscaler)))));
  }

  /// Side sheets would cover the picture in the PiP window.
  void _onPipChanged() {
    if (!_pip.isActive.value || !mounted) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) Navigator.of(context).popUntil((r) => r == route);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(playerControllerProvider);
    final deviceClass = ref.watch(deviceClassProvider);
    final video = _controller.buildVideoView();

    return Theme(
      data: ref.watch(playerThemeProvider),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: PipBinding(
          session: session,
          status: _controller.status,
          child: ValueListenableBuilder(
            valueListenable: _pip.isActive,
            builder: (context, inPip, _) => Stack(
              fit: StackFit.expand,
              children: [
                if (video != null)
                  // Kept in the tree: the surface is reused by the next item, only the stale frame is hidden.
                  Visibility(visible: session?.showsVideo ?? false, maintainState: true, child: video),
                if (session == null)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  // Kept alive under PiP: the controls own orientation, immersive mode and their own state.
                  Visibility(
                    visible: !inPip,
                    maintainState: true,
                    child: switch (deviceClass) {
                      DeviceClass.desktop => DesktopControls(session: session),
                      DeviceClass.phone || DeviceClass.tablet => MobileControls(session: session),
                      DeviceClass.tv => TvControls(session: session),
                    },
                  ),
                  if (inPip) PipView(session: session, interactive: deviceClass == DeviceClass.desktop),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
