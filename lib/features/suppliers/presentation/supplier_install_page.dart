import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization.dart';
import '../../updates/domain/update_check.dart';
import '../../updates/presentation/update_providers.dart';
import '../../updates/presentation/widgets/app_update_section.dart';
import '../../updates/presentation/widgets/install_progress_view.dart';

/// Startup guard screen shown while no compatible supplier bundle is loaded (spec-11 §11.1).
/// The router leaves this page by itself once the bundle is activated.
class SupplierInstallPage extends ConsumerStatefulWidget {
  const SupplierInstallPage({super.key});

  @override
  ConsumerState<SupplierInstallPage> createState() => _SupplierInstallPageState();
}

class _SupplierInstallPageState extends ConsumerState<SupplierInstallPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(latestSupplierBundleProvider.notifier).check();
      ref.read(latestAppReleaseProvider.notifier).check(silent: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final check = ref.watch(latestSupplierBundleProvider);
    final install = ref.watch(supplierBundleInstallControllerProvider);
    final latest = check.latest;
    final checkError = check.error;

    void installLatest() {
      if (latest != null) ref.read(supplierBundleInstallControllerProvider.notifier).install(latest);
    }

    final Widget action;
    if (check.checking) {
      action = const Center(child: CircularProgressIndicator());
    } else if (latest == null) {
      action = Column(
        spacing: 16,
        children: [
          if (checkError != null)
            Text(
              updateErrorText(l10n, checkError, fallback: l10n.updatesCheckFailed),
              style: TextStyle(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
          FilledButton(
            autofocus: true,
            onPressed: () => ref.read(latestSupplierBundleProvider.notifier).check(),
            child: Text(l10n.updatesRetry),
          ),
        ],
      );
    } else if (!latest.isCompatible) {
      action = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          Text(
            l10n.suppliersBundleAppUpdateRequired(latest.versionString),
            style: TextStyle(color: theme.colorScheme.error),
            textAlign: TextAlign.center,
          ),
          const AppUpdateSection(),
        ],
      );
    } else {
      action = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          Text(l10n.updatesLatestVersion(latest.versionString), textAlign: TextAlign.center),
          if (install is InstallIdle)
            FilledButton.icon(
              autofocus: true,
              onPressed: installLatest,
              icon: const Icon(Icons.download),
              label: Text(l10n.updatesInstall),
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

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [
                  Icon(Icons.extension_outlined, size: 64, color: theme.colorScheme.primary),
                  Text(
                    l10n.suppliersBundleInstallTitle,
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  Text(l10n.suppliersBundleInstallMessage, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  action,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
