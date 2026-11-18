import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/reveal_on_focus.dart';
import '../../../core/localization.dart';
import '../../../core/platform/device_class.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../auth/presentation/connect_tv_dialog.dart';
import '../../updates/presentation/widgets/app_update_section.dart';
import '../../updates/presentation/widgets/supplier_bundle_section.dart';
import 'widgets/appearance_settings.dart';
import 'widgets/downloads_settings.dart';

/// Sections follow spec-09 order.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    // TVs receive codes, they don't generate them (spec-04 §4.3).
    final canConnectTv =
        ref.watch(deviceClassProvider) != DeviceClass.tv &&
        ref.watch(accountsAvailableProvider) &&
        ref.watch(activeAuthUserProvider).value != null;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.navSettings, style: theme.textTheme.headlineSmall),
        _Section(title: l10n.settingsAppVersionSection, child: const AppUpdateSection()),
        _Section(title: l10n.settingsSuppliersBundleSection, child: const SupplierBundleSection()),
        _Section(title: l10n.settingsLanguageSection, child: const LanguageSettingsSection()),
        _Section(title: l10n.settingsThemeSection, child: const ThemeSettingsSection()),
        _Section(title: l10n.navDownloads, child: const DownloadsSettingsSection()),
        if (canConnectTv)
          _Section(
            title: l10n.settingsTvSection,
            child: ListTile(
              key: const Key('accountConnectTv'),
              leading: const Icon(Icons.tv),
              title: Text(l10n.accountConnectTv),
              subtitle: Text(l10n.settingsConnectTvSubtitle),
              onTap: () => showConnectTvDialog(context),
            ),
          ),
        const SizedBox(height: 24),
        SurfaceZone(
          padding: const EdgeInsets.all(4),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.extension_outlined),
                title: Text(l10n.settingsSuppliers),
                subtitle: Text(l10n.settingsSuppliersSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.settingsSuppliers),
              ),
              ListTile(
                leading: const Icon(Icons.manage_accounts_outlined),
                title: Text(l10n.profilesTitle),
                subtitle: Text(l10n.settingsProfilesSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.settingsProfiles),
              ),
              ListTile(
                leading: const Icon(Icons.switch_account_outlined),
                title: Text(l10n.profilesSwitch),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.profiles),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RevealOnFocus(
      child: Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(title, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
            ),
            SurfaceZone(child: child),
          ],
        ),
      ),
    );
  }
}
