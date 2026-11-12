import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization.dart';
import '../../../suppliers/data/supplier_registry.dart';
import '../../domain/bundle_update_status.dart';
import '../../domain/update_check.dart';
import '../update_providers.dart';
import 'install_progress_view.dart';

/// Settings → Suppliers library (spec-09 §2, spec-11 §11.1).
class SupplierBundleSection extends ConsumerWidget {
  const SupplierBundleSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final registry = ref.watch(supplierRegistryProvider);
    final check = ref.watch(latestSupplierBundleProvider);
    final status = ref.watch(supplierBundleUpdateStatusProvider);
    final install = ref.watch(supplierBundleInstallControllerProvider);
    final installing = install is InstallInProgress;
    final latest = check.latest;
    final checkError = check.error;

    final installed = switch (registry) {
      SupplierBundleReady(info: final info?) => l10n.updatesInstalledVersion(info.versionString),
      SupplierBundleReady() => l10n.updatesDevLibrary,
      SupplierBundleMissing() => l10n.updatesNotInstalled,
    };

    void installLatest() {
      if (latest != null) ref.read(supplierBundleInstallControllerProvider.notifier).install(latest);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text(installed),
        if (latest != null) Text(l10n.updatesLatestVersion(latest.versionString)),
        if (checkError != null)
          Text(
            updateErrorText(l10n, checkError, fallback: l10n.updatesCheckFailed),
            style: TextStyle(color: theme.colorScheme.error),
          )
        else if (!check.checking)
          switch (status) {
            BundleUpdateStatus.upToDate => Text(l10n.updatesUpToDate),
            BundleUpdateStatus.appUpdateRequired => Text(
              l10n.suppliersBundleAppUpdateRequired(latest!.versionString),
              style: TextStyle(color: theme.colorScheme.error),
            ),
            BundleUpdateStatus.unknown || BundleUpdateStatus.updateAvailable => const SizedBox.shrink(),
          },
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: check.checking || installing
                  ? null
                  : () => ref.read(latestSupplierBundleProvider.notifier).check(),
              icon: check.checking
                  ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh),
              label: Text(l10n.updatesCheck),
            ),
            if (status == BundleUpdateStatus.updateAvailable && !installing)
              FilledButton.icon(
                onPressed: installLatest,
                icon: const Icon(Icons.download),
                label: Text(registry is SupplierBundleMissing ? l10n.updatesInstall : l10n.updatesUpdate),
              ),
          ],
        ),
        InstallProgressView(
          state: install,
          errorFallback: l10n.suppliersBundleInstallFailed,
          onRetry: installLatest,
          onCancel: ref.read(supplierBundleInstallControllerProvider.notifier).cancel,
        ),
      ],
    );
  }
}
