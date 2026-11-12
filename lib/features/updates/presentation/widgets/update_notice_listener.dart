import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/localization.dart';
import '../../../../core/storage/app_preferences.dart';
import '../../domain/bundle_update_status.dart';
import '../update_providers.dart';

/// Runs the throttled startup checks and shows each new version's notice once (spec-11).
class UpdateNoticeListener extends ConsumerStatefulWidget {
  final Widget child;

  const UpdateNoticeListener({super.key, required this.child});

  @override
  ConsumerState<UpdateNoticeListener> createState() => _UpdateNoticeListenerState();
}

class _UpdateNoticeListenerState extends ConsumerState<UpdateNoticeListener> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(availableAppUpdateProvider, (_, release) {
      if (release != null) _notifyOnce(AppPreferences.appUpdateNotifiedVersion, release.name, _appMessage);
    }, fireImmediately: true);
    ref.listenManual(supplierBundleUpdateStatusProvider, (_, status) {
      final latest = ref.read(latestSupplierBundleProvider).latest;
      if (status == BundleUpdateStatus.updateAvailable && latest != null) {
        _notifyOnce(AppPreferences.ffiUpdateNotifiedVersion, latest.versionString, _bundleMessage);
      }
    }, fireImmediately: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(latestAppReleaseProvider.notifier).check(silent: true);
      ref.read(latestSupplierBundleProvider.notifier).check(silent: true);
    });
  }

  String _appMessage(AppLocalizations l10n, String version) => l10n.appUpdateAvailable(version);
  String _bundleMessage(AppLocalizations l10n, String version) => l10n.suppliersBundleUpdateAvailable(version);

  void _notifyOnce(String key, String version, String Function(AppLocalizations, String) message) {
    final prefs = ref.read(appPreferencesProvider);
    if (prefs.getString(key) == version) return;
    prefs.setString(key, version);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final l10n = context.l10n;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message(l10n, version)),
          action: SnackBarAction(label: l10n.updatesUpdate, onPressed: () => context.push(AppRoutes.settings)),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
