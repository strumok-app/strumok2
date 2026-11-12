import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/widgets/side_sheet.dart';
import '../../../app/widgets/state_views.dart';
import '../../../core/localization.dart';
import 'details_providers.dart';
import 'details_widgets.dart';

Future<void> showMediaItemsSheet(BuildContext context, ContentDetails details) => showSideSheet(
  context,
  title: details.mediaType == MediaType.video ? context.l10n.detailsEpisodes : context.l10n.detailsChapters,
  builder: (_) => MediaItemsSheet(details: details),
);

/// Episodes/chapters, one tab per section (season/volume) when there are several.
class MediaItemsSheet extends ConsumerWidget {
  final ContentDetails details;

  const MediaItemsSheet({super.key, required this.details});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final provider = mediaItemsProvider(details.supplier, details.id);

    return switch (ref.watch(provider)) {
      AsyncData(:final value) when value.isEmpty => EmptyStateView(icon: Icons.list, message: l10n.rowEmpty),
      AsyncData(:final value) => _SectionTabs(details: details, groups: groupBySection(value)),
      AsyncError() => LoadErrorView(autofocus: true, onRetry: () => ref.invalidate(provider)),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _SectionTabs extends StatelessWidget {
  final ContentDetails details;
  final List<(String?, List<ContentMediaItem>)> groups;

  const _SectionTabs({required this.details, required this.groups});

  @override
  Widget build(BuildContext context) {
    if (groups.length == 1) return _ItemList(details: details, items: groups.single.$2);

    return DefaultTabController(
      length: groups.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            tabs: [
              for (final (index, (section, _)) in groups.indexed)
                Tab(text: section == null || section.isEmpty ? '${index + 1}' : section),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              children: [
                for (final (index, (_, items)) in groups.indexed)
                  _ItemList(details: details, items: items, autofocus: index == 0),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemList extends StatelessWidget {
  final ContentDetails details;
  final List<ContentMediaItem> items;
  final bool autofocus;

  const _ItemList({required this.details, required this.items, this.autofocus = true});

  @override
  Widget build(BuildContext context) {
    final icon = details.mediaType == MediaType.video ? Icons.play_circle_outline : Icons.menu_book_outlined;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          autofocus: autofocus && index == 0,
          leading: Icon(icon),
          title: Text(item.title),
          onTap: () {
            final router = GoRouter.of(context);
            Navigator.of(context).pop();
            router.push(mediaItemRoute(details, item: item.number));
          },
        );
      },
    );
  }
}
