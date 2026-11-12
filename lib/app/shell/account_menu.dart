import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization.dart';
import '../../features/updates/presentation/update_providers.dart';
import '../router.dart';
import '../theme.dart';

/// Account button opening [AccountDialog]: Settings, Downloads and (from M4) account actions.
class AccountMenu extends ConsumerWidget {
  const AccountMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasUpdate = ref.watch(hasUpdateNoticeProvider);
    return IconButton(
      key: const Key('accountMenuButton'),
      tooltip: context.l10n.accountMenuTooltip,
      icon: Badge(isLabelVisible: hasUpdate, child: const Icon(Icons.account_circle_outlined)),
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

    void open(String route) {
      final router = GoRouter.of(context);
      Navigator.of(context).pop();
      router.push(route);
    }

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                    title: Text(l10n.accountNotSignedIn),
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
