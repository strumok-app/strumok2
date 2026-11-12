import 'package:flutter/material.dart';

import '../../core/localization.dart';

/// Loading-error state with a focusable Retry action.
class LoadErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  final String? message;
  final bool autofocus;

  const LoadErrorView({super.key, required this.onRetry, this.message, this.autofocus = false});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            Icon(Icons.cloud_off_outlined, color: colors.onSurfaceVariant),
            Text(message ?? l10n.errorLoading, textAlign: TextAlign.center),
            FilledButton.tonal(autofocus: autofocus, onPressed: onRetry, child: Text(l10n.commonRetry)),
          ],
        ),
      ),
    );
  }
}

/// Centered icon + message (+ optional action) for empty states.
class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String message;
  final Widget? action;

  const EmptyStateView({super.key, required this.icon, required this.message, this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}
