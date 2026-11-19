import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../core/localization.dart';
import '../../../core/platform/app_platform.dart';
import '../../../core/platform/device_class.dart';
import '../../profiles/presentation/profiles_providers.dart';
import '../domain/app_user.dart';
import 'auth_providers.dart';
import 'pairing_code_dialog.dart';

final _log = Logger('AccountFlows');

/// Runs an account action and reports failures: cancellation is silent, an already linked account offers to
/// switch to its profile, other errors show a snackbar ([onError] may supply a specific message).
/// Returns true on success.
Future<bool> runAccountAction(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() action, {
  String? Function(Object error)? onError,
}) async {
  try {
    await action();
    return true;
  } on AuthCancelledException {
    return false;
  } on AccountAlreadyLinkedException catch (e) {
    if (context.mounted) await _showAlreadyLinked(context, ref, e.profileId);
    return false;
  } catch (e, st) {
    _log.warning('Account action failed', e, st);
    if (!context.mounted) return false;
    final l10n = context.l10n;
    final message =
        onError?.call(e) ?? (e is AuthUnavailableException ? l10n.accountSignInUnavailable : l10n.accountSignInFailed);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    return false;
  }
}

Future<void> _showAlreadyLinked(BuildContext context, WidgetRef ref, String profileId) async {
  final l10n = context.l10n;
  final owner = ref.read(profilesProvider).where((p) => p.id == profileId).firstOrNull;
  if (owner == null) return;
  final switchTo = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(l10n.accountAlreadyLinked(owner.name)),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.commonCancel)),
        FilledButton(
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.accountSwitchToProfile),
        ),
      ],
    ),
  );
  if (switchTo == true) await ref.read(activeProfileProvider.notifier).select(profileId);
}

/// Google sign-in for [profileId] with a modal progress dialog (desktop: consent continues in the browser).
Future<bool> signInWithGoogleFlow(BuildContext context, WidgetRef ref, String profileId) async {
  final cancel = Completer<void>();
  final navigator = Navigator.of(context);
  final progress = showDialog<void>(
    context: context,
    barrierDismissible: false,
    // The dialog pops itself when cancelled.
    builder: (context) => _SignInProgressDialog(onCancel: () => cancel.isCompleted ? null : cancel.complete()),
  );

  return runAccountAction(context, ref, () async {
    try {
      final signIn = ref.read(accountControllerProvider.notifier).signInWithGoogle(profileId);
      // The loopback/browser flow cannot be aborted; cancelling only stops waiting for it.
      await Future.any([signIn, cancel.future.then((_) => throw const AuthCancelledException())]);
    } finally {
      // Closed before any error dialog/snackbar is shown.
      if (!cancel.isCompleted) {
        cancel.complete();
        navigator.pop();
      }
      await progress;
    }
  });
}

class _SignInProgressDialog extends StatelessWidget {
  final VoidCallback onCancel;

  const _SignInProgressDialog({required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final desktop = AppPlatform.current != AppPlatform.android;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        onCancel();
        Navigator.of(context).pop();
      },
      child: AlertDialog(
        content: Row(
          spacing: 24,
          children: [
            const CircularProgressIndicator(),
            Expanded(child: Text(desktop ? l10n.accountSignInBrowser : l10n.accountSigningIn)),
          ],
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () {
              onCancel();
              Navigator.of(context).pop();
            },
            child: Text(l10n.commonCancel),
          ),
        ],
      ),
    );
  }
}

/// Sign-in for a profile: pairing code on TV, Google elsewhere (spec-04 §4.4, spec-05 §5.4).
Future<void> signInFlow(BuildContext context, WidgetRef ref, String profileId) async {
  if (ref.read(deviceClassProvider) == DeviceClass.tv) {
    await showPairingCodeDialog(context, profileId);
  } else {
    await signInWithGoogleFlow(context, ref, profileId);
  }
}
