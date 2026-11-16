import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/widgets/stepper_tile.dart';
import '../../../../core/localization.dart';
import '../../../player/domain/player_preferences.dart';
import '../../../player/domain/player_session.dart';
import '../../../player/presentation/player_settings.dart';
import '../../../player/presentation/subtitle_size.dart';
import '../../../player/presentation/widgets/player_widgets.dart';

/// Spec-09 §5 "Video player": the same persisted settings as the player's settings sheet.
/// SPEC: floating player (M6) and max parallel downloads (M8) join this section with their milestones.
class VideoPlayerSettingsSection extends ConsumerWidget {
  static const _fixedPositionStep = 10;

  const VideoPlayerSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final settings = ref.watch(playerSettingsProvider);
    final notifier = ref.read(playerSettingsProvider.notifier);
    final size = ref.watch(subtitleSizeProvider);
    final sizeNotifier = ref.read(subtitleSizeProvider.notifier);
    const padding = EdgeInsets.zero;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.playerStartFrom, style: theme.textTheme.titleSmall),
        RadioGroup<StartFrom>(
          groupValue: settings.startFrom,
          onChanged: (value) => notifier.setStartFrom(value!),
          child: Column(
            children: [
              for (final value in StartFrom.values)
                RadioListTile<StartFrom>(
                  key: ValueKey('startFrom-${value.name}'),
                  contentPadding: padding,
                  value: value,
                  title: Text(startFromLabel(l10n, value)),
                ),
            ],
          ),
        ),
        if (settings.startFrom == StartFrom.fromFixedPosition)
          StepperTile(
            key: const ValueKey('fixedPosition'),
            contentPadding: padding,
            label: l10n.playerFixedPosition,
            value: formatPlaybackTime(Duration(seconds: settings.fixedPosition)),
            onDecrease: settings.fixedPosition > 0
                ? () => notifier.setFixedPosition(settings.fixedPosition - _fixedPositionStep)
                : null,
            onIncrease: () => notifier.setFixedPosition(settings.fixedPosition + _fixedPositionStep),
          ),
        const SizedBox(height: 16),
        Text(l10n.playerOnEnd, style: theme.textTheme.titleSmall),
        RadioGroup<EndAction>(
          groupValue: settings.endAction,
          onChanged: (value) => notifier.setEndAction(value!),
          child: Column(
            children: [
              for (final value in EndAction.values)
                RadioListTile<EndAction>(
                  key: ValueKey('endAction-${value.name}'),
                  contentPadding: padding,
                  value: value,
                  title: Text(endActionLabel(l10n, value)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          key: const ValueKey('shuffle'),
          contentPadding: padding,
          title: Text(l10n.playerShuffle),
          value: settings.shuffle,
          onChanged: notifier.setShuffle,
        ),
        StepperTile(
          key: const ValueKey('subtitleSize'),
          contentPadding: padding,
          label: l10n.playerSubtitleSize,
          value: size.round().toString(),
          onDecrease: size > SubtitleSize.min ? () => sizeNotifier.set(size - SubtitleSize.step) : null,
          onIncrease: size < SubtitleSize.max ? () => sizeNotifier.set(size + SubtitleSize.step) : null,
        ),
      ],
    );
  }
}
