import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization.dart';
import '../../core/platform/device_class.dart';
import '../../features/auth/presentation/account_flows.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/auth/presentation/pairing_code_dialog.dart';
import '../../features/profiles/presentation/profile_avatar.dart';
import '../../features/profiles/presentation/profiles_providers.dart';
import '../../features/downloads/presentation/widgets/download_widgets.dart';
import '../../features/updates/presentation/update_providers.dart';
import '../router.dart';

const accountMenuKey = Key('accountMenuButton');

Future<void> showAccountDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const AccountDialog());

/// Active profile avatar opening [AccountDialog]: account actions, profile switch, Settings, offline mode.
class AccountMenu extends StatelessWidget {
  const AccountMenu({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    key: accountMenuKey,
    tooltip: context.l10n.accountMenuTooltip,
    icon: const AccountAvatar(),
    onPressed: () => showAccountDialog(context),
  );
}

/// Active profile avatar with the update-notice badge (spec-01, spec-11).
class AccountAvatar extends ConsumerWidget {
  const AccountAvatar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Badge(
    isLabelVisible: ref.watch(hasUpdateNoticeProvider),
    child: ProfileAvatar(profile: ref.watch(activeProfileProvider), radius: 14),
  );
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
        if (ref.watch(deviceClassProvider) == DeviceClass.tv)
          ListTile(
            key: const Key('accountSignInWithCode'),
            leading: const Icon(Icons.pin_outlined),
            title: Text(l10n.accountSignInWithCode),
            onTap: () => showPairingCodeDialog(context, profile.id),
          ),
      ],
    ];

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: ListTileTheme(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 12, 8),
                  child: Row(
                    spacing: 16,
                    children: [
                      ProfileAvatar(profile: profile, radius: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(profile.name, style: theme.textTheme.titleMedium, overflow: TextOverflow.ellipsis),
                            Text(
                              user == null ? l10n.accountNotSignedIn : (user.displayName ?? user.email ?? user.uid),
                              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (accounts && user != null)
                        IconButton(
                          key: const Key('accountSignOut'),
                          tooltip: l10n.accountSignOut,
                          icon: const Icon(Icons.logout),
                          onPressed: () => runAccountAction(
                            context,
                            ref,
                            () => ref.read(accountControllerProvider.notifier).signOut(profile.id),
                          ),
                        ),
                    ],
                  ),
                ),
                ...accountActions,
                ListTile(
                  leading: const Icon(Icons.switch_account_outlined),
                  title: Text(l10n.profilesSwitch),
                  onTap: () => open(AppRoutes.profiles),
                ),
                const Divider(height: 16),
                ListTile(
                  autofocus: true,
                  leading: Badge(isLabelVisible: hasUpdate, child: const Icon(Icons.settings_outlined)),
                  title: Text(l10n.navSettings),
                  onTap: () => open(AppRoutes.settings),
                ),
                const OfflineModeSwitch(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
