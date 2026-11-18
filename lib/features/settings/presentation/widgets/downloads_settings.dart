import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/widgets/stepper_tile.dart';
import '../../../../core/localization.dart';
import '../../../../core/platform/background_permissions.dart';
import '../../../../core/platform/device_class.dart';
import '../../../downloads/domain/download_queue.dart';
import '../../../downloads/presentation/downloads_providers.dart';

/// Spec-09 §5: downloads folder (desktop only) and max parallel downloads. The offline mode switch is in the
/// account menu only.
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
      ],
    );
  }
}
