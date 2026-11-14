import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/localization.dart';
import '../../auth/presentation/account_flows.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/profile.dart';
import 'profile_avatar.dart';
import 'profile_edit_dialog.dart';
import 'profiles_providers.dart';

/// Settings → Profiles (spec-05 §5.4): add, rename/color, link or unlink a Google account, delete.
class ManageProfilesPage extends ConsumerWidget {
  const ManageProfilesPage({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, Profile profile) async {
    final draft = await showProfileEditDialog(context, profile: profile);
    if (draft != null) {
      await ref.read(profilesProvider.notifier).update(profile.id, name: draft.name, color: draft.color);
    }
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final draft = await showProfileEditDialog(context);
    if (draft != null) await ref.read(profilesProvider.notifier).create(draft.name, draft.color);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Profile profile) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.profilesDelete),
        content: Text(l10n.profilesDeleteConfirm(profile.name)),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.profilesDelete)),
        ],
      ),
    );
    if (confirmed == true) await ref.read(profilesProvider.notifier).delete(profile.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final profiles = ref.watch(profilesProvider);
    final activeId = ref.watch(activeProfileIdProvider);
    final accounts = ref.watch(accountsAvailableProvider);

    String subtitle(Profile profile) => [
      if (profile.id == activeId) l10n.profilesActive,
      if (profile.isLinked) profile.accountName ?? l10n.accountSyncHint else l10n.accountNotSignedIn,
    ].join(' · ');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.profilesTitle, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 16),
        SurfaceZone(
          padding: const EdgeInsets.all(4),
          child: Column(
            children: [
              for (final profile in profiles)
                ListTile(
                  leading: ProfileAvatar(profile: profile),
                  title: Text(profile.name),
                  subtitle: Text(subtitle(profile)),
                  onTap: () => _edit(context, ref, profile),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (accounts)
                        profile.isLinked
                            ? IconButton(
                                key: Key('profileSignOut-${profile.id}'),
                                tooltip: l10n.accountSignOut,
                                icon: const Icon(Icons.logout),
                                onPressed: () => runAccountAction(
                                  context,
                                  ref,
                                  () => ref.read(accountControllerProvider.notifier).signOut(profile.id),
                                ),
                              )
                            : IconButton(
                                key: Key('profileSignIn-${profile.id}'),
                                tooltip: l10n.accountSignIn,
                                icon: const Icon(Icons.login),
                                onPressed: () => signInFlow(context, ref, profile.id),
                              ),
                      IconButton(
                        tooltip: l10n.profilesDelete,
                        icon: const Icon(Icons.delete_outline),
                        // The active profile can't be deleted; switch first.
                        onPressed: profile.id == activeId || profiles.length <= 1
                            ? null
                            : () => _delete(context, ref, profile),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: () => _add(context, ref),
            icon: const Icon(Icons.person_add_alt),
            label: Text(l10n.profilesAdd),
          ),
        ),
        const SizedBox(height: 24),
        SurfaceZone(
          padding: const EdgeInsets.all(4),
          child: SwitchListTile(
            title: Text(l10n.profilesAskOnStartup),
            subtitle: Text(l10n.profilesAskOnStartupSubtitle),
            value: ref.watch(profileAskOnStartupProvider),
            onChanged: ref.read(profileAskOnStartupProvider.notifier).set,
          ),
        ),
      ],
    );
  }
}
