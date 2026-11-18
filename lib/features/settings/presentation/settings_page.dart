import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/reveal_on_focus.dart';
import '../../../core/localization.dart';
import '../../updates/presentation/widgets/app_update_section.dart';
import '../../updates/presentation/widgets/supplier_bundle_section.dart';
import 'widgets/appearance_settings.dart';
import 'widgets/downloads_settings.dart';

/// Sections follow spec-09 order.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.navSettings, style: theme.textTheme.headlineSmall),
        _Section(title: l10n.settingsAppVersionSection, child: const AppUpdateSection()),
        _Section(title: l10n.settingsSuppliersBundleSection, child: const SupplierBundleSection()),
        _Section(title: l10n.settingsLanguageSection, child: const LanguageSettingsSection()),
        _Section(title: l10n.settingsThemeSection, child: const ThemeSettingsSection()),
        _Section(title: l10n.navDownloads, child: const DownloadsSettingsSection()),
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
