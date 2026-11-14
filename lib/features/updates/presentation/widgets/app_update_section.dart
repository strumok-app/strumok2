import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization.dart';
import '../../data/app_installer.dart';
import '../../domain/update_check.dart';
import '../update_providers.dart';
import 'install_progress_view.dart';
import 'release_notes_dialog.dart';

/// Settings → Application version (spec-09 §1, spec-11 §11.2).
class AppUpdateSection extends ConsumerWidget {
  const AppUpdateSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final check = ref.watch(latestAppReleaseProvider);
    final available = ref.watch(availableAppUpdateProvider);
    final install = ref.watch(appUpdateInstallControllerProvider);
    final downloads = ref.watch(appInstallerProvider).downloads;
    final installing = install is InstallInProgress;
    final checkError = check.error;
    final release = available ?? check.latest;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text(l10n.updatesCurrentVersion(ref.watch(currentAppVersionProvider))),
        if (check.latest case final latest?) Text(l10n.updatesLatestVersion(latest.version.toString())),
        if (checkError != null)
          Text(
            updateErrorText(l10n, checkError, fallback: l10n.updatesCheckFailed),
            style: TextStyle(color: theme.colorScheme.error),
          )
        else if (available == null && check.latest != null && !check.checking)
          Text(l10n.updatesUpToDate),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: check.checking || installing
                  ? null
                  : () => ref.read(latestAppReleaseProvider.notifier).check(),
              icon: check.checking
                  ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh),
              label: Text(l10n.updatesCheck),
            ),
            if (available != null && !installing)
              FilledButton.icon(
                onPressed: () => ref.read(appUpdateInstallControllerProvider.notifier).install(available),
                icon: Icon(downloads ? Icons.system_update : Icons.open_in_new),
                label: Text(downloads ? l10n.updatesUpdate : l10n.appUpdateOpenDownload),
              ),
            if (release != null && release.notes != null)
              TextButton(
                onPressed: () => showReleaseNotesDialog(context, release),
                child: Text(l10n.appUpdateReleaseNotes),
              ),
          ],
        ),
        InstallProgressView(
          state: install,
          errorFallback: l10n.appUpdateFailed,
          onRetry: () {
            if (available != null) ref.read(appUpdateInstallControllerProvider.notifier).install(available);
          },
          onCancel: downloads ? ref.read(appUpdateInstallControllerProvider.notifier).cancel : null,
        ),
      ],
    );
  }
}
