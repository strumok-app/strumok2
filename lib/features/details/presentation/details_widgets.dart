import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/localization.dart';
import '../../collection/domain/collection_item.dart';
import '../../collection/presentation/collection_labels.dart';
import '../../collection/presentation/collection_providers.dart';
import '../../collection/presentation/collection_status_sheet.dart';
import 'details_providers.dart';
import 'media_items_sheet.dart';

String mediaItemRoute(ContentDetails details, {int? item}) => details.mediaType == MediaType.video
    ? AppRoutes.video(details.supplier, details.id, item: item)
    : AppRoutes.manga(details.supplier, details.id, item: item);

/// Title block with the primary Watch/Read action (autofocused for TV).
class DetailsInfo extends StatelessWidget {
  final ContentDetails details;

  const DetailsInfo({super.key, required this.details});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isVideo = details.mediaType == MediaType.video;
    final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        SelectableText(details.title, style: theme.textTheme.headlineMedium),
        if (details.originalTitle case final original? when original.isNotEmpty)
          SelectableText(
            original,
            style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                autofocus: true,
                onPressed: () => context.push(mediaItemRoute(details)),
                icon: Icon(isVideo ? Icons.play_arrow : Icons.menu_book),
                label: Text(isVideo ? l10n.detailsWatch : l10n.detailsRead),
              ),
              _CollectionButton(details: details),
              _MediaItemsButton(details: details),
            ],
          ),
        ),
        // SPEC: download actions (M8) are added with their milestone.
        if (details.additionalInfo.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [for (final line in details.additionalInfo) Text(line, style: muted)],
          ),
        if (details.description.isNotEmpty) ExpandableText(details.description),
      ],
    );
  }
}

/// Collapsed to a few lines with a "more"/"less" toggle when it overflows.
class ExpandableText extends StatefulWidget {
  final String text;
  final int collapsedLines;

  const ExpandableText(this.text, {super.key, this.collapsedLines = 4});

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge;
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: widget.collapsedLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              style: style,
              maxLines: _expanded ? null : widget.collapsedLines,
              overflow: _expanded ? null : TextOverflow.ellipsis,
            ),
            if (overflows)
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(_expanded ? context.l10n.detailsLess : context.l10n.detailsMore),
              ),
          ],
        );
      },
    );
  }
}

/// Shows the collection status (or "add") and opens the status/priority sheet.
class _CollectionButton extends ConsumerWidget {
  final ContentDetails details;

  const _CollectionButton({required this.details});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final status = ref.watch(collectionItemProvider(details.supplier, details.id))?.status ?? CollectionStatus.none;
    return FilledButton.tonalIcon(
      key: const Key('collectionButton'),
      onPressed: () => showCollectionStatusSheet(context, details),
      icon: Icon(collectionStatusIcon(status)),
      label: Text(status == CollectionStatus.none ? l10n.collectionAdd : l10n.collectionStatus(status)),
    );
  }
}

/// Opens the episodes/chapters side panel; hidden while loading and for single-item content.
class _MediaItemsButton extends ConsumerWidget {
  final ContentDetails details;

  const _MediaItemsButton({required this.details});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final visible = switch (ref.watch(mediaItemsProvider(details.supplier, details.id))) {
      AsyncData(:final value) => value.length > 1,
      AsyncError() => true,
      _ => false,
    };
    if (!visible) return const SizedBox.shrink();

    return FilledButton.tonalIcon(
      key: const Key('mediaItemsButton'),
      onPressed: () => showMediaItemsSheet(context, details),
      icon: const Icon(Icons.format_list_bulleted),
      label: Text(details.mediaType == MediaType.video ? l10n.detailsEpisodes : l10n.detailsChapters),
    );
  }
}
