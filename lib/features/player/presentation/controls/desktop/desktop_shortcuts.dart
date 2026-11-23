import 'package:flutter/material.dart';

import '../../../../../core/localization.dart';
import '../../../domain/player_session.dart';

/// Key captions shared by the button tooltips and the shortcuts overlay.
abstract final class DesktopKeys {
  static const playPause = 'Space';
  static const previous = '[';
  static const next = ']';
  static const fullscreen = 'F';
  static const playlist = 'P';
  static const sources = 'S';
  static const subtitles = 'C';
  static const mute = 'M';
  static const settings = ',';
  static const help = '?';
}

typedef ShortcutEntry = ({List<String> keys, String label});

List<ShortcutEntry> desktopShortcuts(AppLocalizations l10n, PlayerSession session) => [
  (keys: [DesktopKeys.playPause], label: l10n.playerShortcutPlayPause),
  (keys: ['←', '→'], label: l10n.playerShortcutSeek(10)),
  (keys: ['J', 'I'], label: l10n.playerShortcutSeek(60)),
  (keys: ['Shift + ←', 'Shift + →'], label: l10n.playerShortcutFrameStep),
  (keys: ['↑', '↓'], label: l10n.playerShortcutVolume),
  (keys: [DesktopKeys.mute], label: l10n.playerShortcutMute),
  (keys: [DesktopKeys.previous, DesktopKeys.next], label: l10n.playerShortcutPreviousNext),
  (keys: [DesktopKeys.fullscreen, 'Enter'], label: l10n.playerFullscreen),
  (keys: ['Esc'], label: l10n.playerExitFullscreen),
  if (session.items.length > 1) (keys: [DesktopKeys.playlist], label: l10n.detailsEpisodes),
  if (session.sources.length > 1) (keys: [DesktopKeys.sources], label: l10n.playerSource),
  if (session.subtitles.isNotEmpty) (keys: [DesktopKeys.subtitles], label: l10n.playerShortcutSubtitles),
  (keys: [DesktopKeys.settings], label: l10n.playerSettings),
  (keys: [DesktopKeys.help, 'H'], label: l10n.playerShortcutHelp),
];

/// Full-area cheat sheet over the video; a click anywhere dismisses it (keys are handled by the controls).
class ShortcutsOverlay extends StatelessWidget {
  final PlayerSession session;
  final VoidCallback onClose;

  const ShortcutsOverlay({super.key, required this.session, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final entries = desktopShortcuts(l10n, session);

    return GestureDetector(
      key: const Key('shortcutsOverlay'),
      behavior: HitTestBehavior.opaque,
      onTap: onClose,
      child: ColoredBox(
        color: Colors.black87,
        child: LayoutBuilder(
          builder: (context, constraints) {
            const padding = 24.0;
            const columnSpacing = 24.0;
            const maxContentWidth = 760.0;
            final available = (constraints.maxWidth - padding * 2).clamp(0.0, maxContentWidth);
            // Two columns once there is room for them, so the sheet stays short enough to avoid scrolling.
            final columns = available >= 520 ? 2 : 1;
            final itemWidth = (available - columnSpacing * (columns - 1)) / columns;

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(padding),
                child: SizedBox(
                  width: available,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.playerShortcutsTitle, style: theme.textTheme.titleLarge?.copyWith(color: Colors.white)),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: columnSpacing,
                        runSpacing: 4,
                        children: [
                          for (final entry in entries)
                            SizedBox(
                              width: itemWidth,
                              child: _ShortcutRow(entry: entry),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.playerShortcutsClose,
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  final ShortcutEntry entry;

  const _ShortcutRow({required this.entry});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(
          width: 80,
          child: Wrap(spacing: 4, runSpacing: 4, children: [for (final key in entry.keys) _KeyCap(key)]),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(entry.label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white)),
        ),
      ],
    ),
  );
}

class _KeyCap extends StatelessWidget {
  final String caption;

  const _KeyCap(this.caption);

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 28),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.white12,
      border: Border.all(color: Colors.white38),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(caption, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white)),
  );
}
