import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/device_class.dart';
import 'controls/basic_controls.dart';
import 'controls/desktop/desktop_controls.dart';
import 'player_controller.dart';
import 'player_fullscreen.dart';

/// Full-screen; outside the app shell. Controls are picked by device class (spec-06 §6.1).
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

  @override
  void initState() {
    super.initState();
    _controller = ref.read(playerControllerProvider.notifier);
    _fullscreen = ref.read(playerFullscreenProvider.notifier);
    // Providers must not change while the tree is building.
    unawaited(Future.microtask(() => _controller.open(widget.supplier, widget.id, item: widget.item)));
  }

  @override
  void dispose() {
    unawaited(
      Future.microtask(() async {
        await _fullscreen.set(false);
        await _controller.close();
      }),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(playerControllerProvider);
    final deviceClass = ref.watch(deviceClassProvider);
    final video = _controller.buildVideoView();
    final theme = Theme.of(context);

    // Controls sit on video: always light-on-dark, whatever the app brightness.
    return Theme(
      data: theme.copyWith(
        iconTheme: const IconThemeData(color: Colors.white),
        textTheme: theme.textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
        iconButtonTheme: IconButtonThemeData(
          style: (theme.iconButtonTheme.style ?? const ButtonStyle()).copyWith(
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.disabled) ? Colors.white38 : Colors.white,
            ),
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            ?video,
            if (session == null)
              const Center(child: CircularProgressIndicator())
            else
              switch (deviceClass) {
                DeviceClass.desktop => DesktopControls(session: session),
                // SPEC: phone/tablet (M5.5) and TV (M5.6) get dedicated controls in their stages.
                _ => BasicControls(session: session),
              },
          ],
        ),
      ),
    );
  }
}
