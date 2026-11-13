import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/localization.dart';
import 'profile_avatar.dart';
import 'profile_edit_dialog.dart';
import 'profiles_providers.dart';

/// "Who's watching?" grid of large focusable avatars (spec-05 §5.4). Full screen, outside the shell.
class ProfilePickerPage extends ConsumerWidget {
  const ProfilePickerPage({super.key});

  Future<void> _pick(BuildContext context, WidgetRef ref, String id) async {
    await ref.read(activeProfileProvider.notifier).select(id);
    ref.read(profilePickPendingProvider.notifier).done();
    if (!context.mounted) return;
    context.canPop() ? context.pop() : context.go(AppRoutes.home);
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final draft = await showProfileEditDialog(context);
    if (draft == null || !context.mounted) return;
    final profile = await ref.read(profilesProvider.notifier).create(draft.name, draft.color);
    if (context.mounted) await _pick(context, ref, profile.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final profiles = ref.watch(profilesProvider);
    final activeId = ref.watch(activeProfileIdProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 32,
              children: [
                Text(l10n.profilesPickTitle, style: Theme.of(context).textTheme.headlineMedium),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 24,
                  runSpacing: 24,
                  children: [
                    for (final profile in profiles)
                      _PickerTile(
                        autofocus: profile.id == activeId,
                        label: profile.name,
                        avatar: ProfileAvatar(profile: profile, radius: 48),
                        onTap: () => _pick(context, ref, profile.id),
                      ),
                    _PickerTile(
                      label: l10n.profilesAdd,
                      avatar: CircleAvatar(
                        radius: 48,
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.add, size: 40),
                      ),
                      onTap: () => _add(context, ref),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerTile extends StatefulWidget {
  final String label;
  final Widget avatar;
  final VoidCallback onTap;
  final bool autofocus;

  const _PickerTile({required this.label, required this.avatar, required this.onTap, this.autofocus = false});

  @override
  State<_PickerTile> createState() => _PickerTileState();
}

class _PickerTileState extends State<_PickerTile> {
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      autofocus: widget.autofocus,
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      focusColor: Colors.transparent,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _focused ? 1.08 : 1,
        duration: const Duration(milliseconds: 120),
        child: SizedBox(
          width: 128,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              spacing: 12,
              children: [
                DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: _focused ? Border.all(color: colors.onSurface, width: 3) : null,
                  ),
                  child: widget.avatar,
                ),
                Text(widget.label, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
