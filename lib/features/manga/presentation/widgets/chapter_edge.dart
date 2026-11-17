import 'package:flutter/material.dart';

import '../../../../core/localization.dart';

/// Shown past the last page (or before the first) when there is another chapter; continuing past it opens that
/// chapter (spec-07).
class ChapterEdge extends StatelessWidget {
  final bool next;
  final String current;
  final String target;
  final VoidCallback onOpen;

  const ChapterEdge({super.key, required this.next, required this.current, required this.target, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            Text(next ? l10n.readerChapterEnd(current) : l10n.readerChapterStart(current), style: muted),
            Text(target, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
            // The D-pad continues with the arrow keys; the button is for touch and mouse.
            ExcludeFocus(
              child: FilledButton.icon(
                onPressed: onOpen,
                icon: Icon(next ? Icons.skip_next : Icons.skip_previous),
                label: Text(next ? l10n.readerNextChapter : l10n.readerPreviousChapter),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
