import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/widgets/stepper_tile.dart';
import '../../../../core/localization.dart';
import '../../../../core/platform/background_permissions.dart';
import '../../../../core/platform/device_class.dart';
import '../../../../core/storage/offline_mode.dart';
import '../../../downloads/domain/download_queue.dart';
import '../../../downloads/presentation/downloads_providers.dart';

/// Spec-09 §5: downloads folder (desktop only), max parallel downloads, offline mode.
class DownloadsSettingsSection extends ConsumerWidget {
  const DownloadsSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final folder = ref.watch(downloadsFolderProvider);
    final folderNotifier = ref.read(downloadsFolderProvider.notifier);
    final maxParallel = ref.watch(maxParallelDownloadsProvider);
    final maxNotifier = ref.read(maxParallelDownloadsProvider.notifier);
    final desktop = ref.watch(deviceClassProvider) == DeviceClass.desktop;

    return Column(
      children: [
        if (desktop)
          ListTile(
            key: const Key('downloadsFolder'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.settingsDownloadsFolder),
            subtitle: Text(folder.path, maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: Wrap(
              spacing: 8,
              children: [
                if (folderNotifier.isCustom)
                  TextButton(
                    key: const Key('downloadsFolderReset'),
                    onPressed: () => unawaited(folderNotifier.reset()),
                    child: Text(l10n.settingsDownloadsFolderReset),
                  ),
                FilledButton.tonal(
                  key: const Key('downloadsFolderChange'),
                  onPressed: () async {
                    final path = await ref.read(directoryPickerProvider)(initialDirectory: folder.path);
                    if (path != null) await folderNotifier.set(path);
                  },
                  child: Text(l10n.settingsDownloadsFolderChange),
                ),
              ],
            ),
          ),
        StepperTile(
          key: const Key('maxParallelDownloads'),
          contentPadding: EdgeInsets.zero,
          label: l10n.settingsMaxDownloads,
          value: '$maxParallel',
          onDecrease: maxParallel > DownloadQueue.minConcurrent
              ? () => unawaited(maxNotifier.set(maxParallel - 1))
              : null,
          onIncrease: maxParallel < DownloadQueue.maxConcurrentLimit
              ? () => unawaited(maxNotifier.set(maxParallel + 1))
              : null,
        ),
        const OfflineModeSwitch(contentPadding: EdgeInsets.zero),
      ],
    );
  }
}

/// Global offline mode (spec-08 §8.4); in Settings and in the account menu.
class OfflineModeSwitch extends ConsumerWidget {
  final EdgeInsetsGeometry? contentPadding;

  const OfflineModeSwitch({super.key, this.contentPadding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return SwitchListTile(
      key: const Key('offlineModeSwitch'),
      contentPadding: contentPadding,
      secondary: const Icon(Icons.cloud_off_outlined),
      title: Text(l10n.offlineMode),
      subtitle: Text(l10n.offlineModeDescription),
      value: ref.watch(offlineModeProvider),
      onChanged: (value) => unawaited(ref.read(offlineModeProvider.notifier).set(value)),
    );
  }
}
