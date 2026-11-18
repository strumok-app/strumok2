import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/widgets/reveal_on_focus.dart';
import '../../../core/localization.dart';
import '../../../core/storage/offline_mode.dart';
import '../../collection/domain/collection_item.dart';
import '../../collection/presentation/collection_labels.dart';
import '../../collection/presentation/collection_providers.dart';
import '../../collection/presentation/collection_status_sheet.dart';
import '../../downloads/presentation/download_sheet.dart';
import 'details_providers.dart';
import 'media_items_sheet.dart';

String mediaItemRoute(ContentDetails details, {int? item}) => details.mediaType == MediaType.video
    ? AppRoutes.video(details.supplier, details.id, item: item)
    : AppRoutes.manga(details.supplier, details.id, item: item);

/// Title block with the primary Watch/Read action (autofocused for TV); the wide layout's info pane.
class DetailsInfo extends StatelessWidget {
  final ContentDetails details;

  const DetailsInfo({super.key, required this.details});

  @override
  Widget build(BuildContext context) {
    // Margin covers the list padding above the title.
    return RevealOnFocus(
      margin: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          DetailsTitle(details: details),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                WatchButton(details: details),
                CollectionButton(details: details),
                MediaItemsButton(details: details),
                DownloadButton(details: details),
              ],
            ),
          ),
          DetailsMeta(details: details),
        ],
      ),
    );
  }
}

/// Title and original title; [overlay] styles them for legibility on top of the poster (light text, shadow).
class DetailsTitle extends StatelessWidget {
  final ContentDetails details;
  final bool overlay;

  const DetailsTitle({super.key, required this.details, this.overlay = false});

  static const _shadows = [Shadow(blurRadius: 6)];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final titleStyle = overlay
        ? textTheme.titleLarge?.copyWith(color: Colors.white, shadows: _shadows)
        : textTheme.headlineMedium;
    final originalStyle = textTheme.titleMedium?.copyWith(
      color: overlay ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
      shadows: overlay ? _shadows : null,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: overlay ? 4 : 12,
      children: [
        SelectableText(details.title, style: titleStyle),
        if (details.originalTitle case final original? when original.isNotEmpty)
          SelectableText(original, style: originalStyle),
      ],
    );
  }
}

/// Primary Watch/Read action; autofocused so TV lands on it.
class WatchButton extends StatelessWidget {
  final ContentDetails details;

  const WatchButton({super.key, required this.details});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isVideo = details.mediaType == MediaType.video;
    return FilledButton.icon(
      autofocus: true,
      onPressed: () => context.push(mediaItemRoute(details)),
      icon: Icon(isVideo ? Icons.play_arrow : Icons.menu_book),
      label: Text(isVideo ? l10n.detailsWatch : l10n.detailsRead),
    );
  }
}

/// Additional info lines and the expandable description.
class DetailsMeta extends StatelessWidget {
  final ContentDetails details;

  const DetailsMeta({super.key, required this.details});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
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
class CollectionButton extends ConsumerWidget {
  final ContentDetails details;

  const CollectionButton({super.key, required this.details});

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
class MediaItemsButton extends ConsumerWidget {
  final ContentDetails details;

  const MediaItemsButton({super.key, required this.details});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final visible = switch (ref.watch(mediaItemsProvider(details.supplier, details.id))) {
      AsyncData(:final value) => value.length > 1,
      AsyncError() => true,
      _ => false,
    };
    if (!visible) return const SizedBox.shrink();

    return IconButton.filledTonal(
      key: const Key('mediaItemsButton'),
      tooltip: details.mediaType == MediaType.video ? l10n.detailsEpisodes : l10n.detailsChapters,
      // M3 icon buttons ignore the theme density; match the filled buttons next to it.
      visualDensity: Theme.of(context).visualDensity,
      onPressed: () => showMediaItemsSheet(context, details),
      icon: const Icon(Icons.format_list_bulleted),
    );
  }
}

/// Opens the download sheet (spec-08 §8.2); hidden in offline mode, where there is nothing to download from.
class DownloadButton extends ConsumerWidget {
  final ContentDetails details;

  const DownloadButton({super.key, required this.details});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(offlineModeProvider)) return const SizedBox.shrink();
    return IconButton.filledTonal(
      key: const Key('downloadButton'),
      tooltip: context.l10n.detailsDownload,
      // M3 icon buttons ignore the theme density; match the filled buttons next to it.
      visualDensity: Theme.of(context).visualDensity,
      onPressed: () => showDownloadSheet(context, details),
      icon: const Icon(Icons.download_outlined),
    );
  }
}
