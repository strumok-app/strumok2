import 'package:flutter/material.dart';

import '../../../../core/localization.dart';
import '../../data/app_installer.dart';
import '../../domain/update_check.dart';

String updateErrorText(AppLocalizations l10n, Object error, {required String fallback}) => switch (error) {
  UpdateCheckNotConfiguredException() => l10n.updatesNotConfigured,
  NoReleaseAssetException() => l10n.appUpdateNoAsset,
  _ => fallback,
};

/// Progress with Cancel, or error with Retry (spec-11 UX). Nothing while idle.
class InstallProgressView extends StatelessWidget {
  final InstallState state;
  final String errorFallback;
  final VoidCallback onRetry;
  final VoidCallback? onCancel;

  const InstallProgressView({
    super.key,
    required this.state,
    required this.errorFallback,
    required this.onRetry,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return switch (state) {
      InstallIdle() => const SizedBox.shrink(),
      InstallInProgress(:final progress) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  progress == null ? l10n.updatesDownloading : l10n.updatesProgress((progress * 100).round()),
                ),
              ),
              if (onCancel != null) TextButton(autofocus: true, onPressed: onCancel, child: Text(l10n.updatesCancel)),
            ],
          ),
        ],
      ),
      InstallFailed(:final error) => Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              updateErrorText(l10n, error, fallback: errorFallback),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(autofocus: true, onPressed: onRetry, child: Text(l10n.updatesRetry)),
        ],
      ),
    };
  }
}
