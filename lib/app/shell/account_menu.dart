import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization.dart';
import '../../core/platform/device_class.dart';
import '../../features/auth/presentation/account_flows.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/auth/presentation/connect_tv_dialog.dart';
import '../../features/auth/presentation/pairing_code_dialog.dart';
import '../../features/profiles/presentation/profile_avatar.dart';
import '../../features/profiles/presentation/profiles_providers.dart';
import '../../features/updates/presentation/update_providers.dart';
import '../router.dart';
import '../theme.dart';

/// Active profile avatar opening [AccountDialog]: account actions, profiles, Settings, Downloads.
class AccountMenu extends ConsumerWidget {
  const AccountMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasUpdate = ref.watch(hasUpdateNoticeProvider);
    return IconButton(
      key: const Key('accountMenuButton'),
      tooltip: context.l10n.accountMenuTooltip,
      icon: Badge(
        isLabelVisible: hasUpdate,
        child: ProfileAvatar(profile: ref.watch(activeProfileProvider), radius: 14),
      ),
      onPressed: () => showDialog<void>(context: context, builder: (_) => const AccountDialog()),
    );
  }
}

class AccountDialog extends ConsumerWidget {
  const AccountDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final hasUpdate = ref.watch(hasUpdateNoticeProvider);
    final profile = ref.watch(activeProfileProvider);
    final user = ref.watch(activeAuthUserProvider).value;
    final isTv = ref.watch(deviceClassProvider) == DeviceClass.tv;
    final accounts = ref.watch(accountsAvailableProvider);

    void open(String route) {
      final router = GoRouter.of(context);
      Navigator.of(context).pop();
      router.push(route);
    }

    // Account actions stay on top of this dialog, which then shows the new state (spec-04 §4.4).
    final accountActions = <Widget>[
      if (accounts && user == null) ...[
        if (ref.watch(googleSignInAvailableProvider))
          ListTile(
            key: const Key('accountSignInGoogle'),
            leading: const Icon(Icons.login),
            title: Text(l10n.accountSignInGoogle),
            onTap: () => signInWithGoogleFlow(context, ref, profile.id),
          ),
        ListTile(
          key: const Key('accountSignInWithCode'),
          leading: const Icon(Icons.pin_outlined),
          title: Text(l10n.accountSignInWithCode),
          onTap: () => showPairingCodeDialog(context, profile.id),
        ),
      ],
      if (accounts && user != null) ...[
        if (!isTv)
          ListTile(
            key: const Key('accountConnectTv'),
            leading: const Icon(Icons.tv),
            title: Text(l10n.accountConnectTv),
            onTap: () => showConnectTvDialog(context),
          ),
        ListTile(
          key: const Key('accountSignOut'),
          leading: const Icon(Icons.logout),
          title: Text(l10n.accountSignOut),
          onTap: () =>
              runAccountAction(context, ref, () => ref.read(accountControllerProvider.notifier).signOut(profile.id)),
        ),
      ],
    ];

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Text(l10n.accountMenuTooltip, style: theme.textTheme.titleLarge),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SurfaceZone(
                  color: theme.colorScheme.surfaceContainerHighest,
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    children: [
                      ListTile(
                        leading: ProfileAvatar(profile: profile),
                        title: Text(profile.name),
                        subtitle: Text(
                          user == null ? l10n.accountNotSignedIn : (user.displayName ?? user.email ?? user.uid),
                        ),
                      ),
                      ...accountActions,
                      ListTile(
                        leading: const Icon(Icons.switch_account_outlined),
                        title: Text(l10n.profilesSwitch),
                        onTap: () => open(AppRoutes.profiles),
                      ),
                      ListTile(
                        leading: const Icon(Icons.manage_accounts_outlined),
                        title: Text(l10n.profilesManage),
                        onTap: () => open(AppRoutes.settingsProfiles),
                      ),
                    ],
                  ),
                ),
              ),
              ListTile(
                autofocus: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: const Icon(Icons.download_outlined),
                title: Text(l10n.navDownloads),
                onTap: () => open(AppRoutes.downloads),
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: Badge(isLabelVisible: hasUpdate, child: const Icon(Icons.settings_outlined)),
                title: Text(l10n.navSettings),
                onTap: () => open(AppRoutes.settings),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
