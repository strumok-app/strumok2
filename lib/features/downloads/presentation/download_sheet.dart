import 'dart:async';
import 'dart:io';

import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/widgets/side_sheet.dart';
import '../../../app/widgets/state_views.dart';
import '../../../core/localization.dart';
import '../../collection/presentation/collection_providers.dart';
import '../../details/presentation/details_providers.dart';
import '../../details/presentation/media_items_list.dart';
import '../domain/download_queue.dart';
import '../domain/download_task.dart';
import '../domain/offline_layout.dart';
import 'downloads_providers.dart';
import 'widgets/download_widgets.dart';

Future<void> showDownloadSheet(BuildContext context, ContentDetails details) => showSideSheet(
  context,
  title: context.l10n.detailsDownload,
  builder: (_) => DownloadSheet(details: details),
);

/// What to download (spec-08 §8.1–8.2): everything, a season/volume or one item; then the source(s). A group of items
/// downloads one at a time in order; each item gets the first preferred source it has, or the most similar one.
class DownloadSheet extends ConsumerStatefulWidget {
  final ContentDetails details;

  const DownloadSheet({super.key, required this.details});

  @override
  ConsumerState<DownloadSheet> createState() => _DownloadSheetState();
}

class _DownloadSheetState extends ConsumerState<DownloadSheet> {
  List<ContentMediaItem>? _selection;
  var _step = _Step.root;

  /// Root row to focus when coming back to the root.
  _Step? _returnedFrom;

  ContentDetails get _details => widget.details;

  bool get _isManga => _details.mediaType == MediaType.manga;

  void _open(_Step step) => setState(() => _step = step);

  void _select(List<ContentMediaItem> items) => setState(() => _selection = items);

  /// Back from the sources to the list they were chosen in, otherwise to the root.
  void _back() => setState(() {
    if (_selection != null) {
      _selection = null;
    } else {
      _returnedFrom = _step;
      _step = _Step.root;
    }
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = mediaItemsProvider(_details.supplier, _details.id);
    return switch (ref.watch(provider)) {
      AsyncData(:final value) when value.isEmpty => EmptyStateView(icon: Icons.list, message: l10n.rowEmpty),
      AsyncData(:final value) => _steps(value),
      AsyncError(isLoading: false) => LoadErrorView(autofocus: true, onRetry: () => ref.invalidate(provider)),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }

  Widget _steps(List<ContentMediaItem> items) {
    final l10n = context.l10n;
    final single = items.length == 1;
    final selection = _selection ?? (single ? items : null);
    final atRoot = (selection == null && _step == _Step.root) || single;
    final Widget body;
    final String title;
    if (selection != null) {
      body = _SourceList(details: _details, items: selection);
      title = l10n.downloadsChooseSource;
    } else {
      switch (_step) {
        case _Step.root:
          body = _options(items);
          title = '';
        case _Step.sections:
          body = _sections(items);
          title = _isManga ? l10n.downloadsPickVolume : l10n.downloadsPickSeason;
        case _Step.items:
          final collection = ref.watch(collectionItemProvider(_details.supplier, _details.id));
          body = MediaItemsList(
            items: items,
            mediaType: _details.mediaType,
            positions: collection?.positions ?? const {},
            currentItem: collection?.currentItem,
            onSelected: (item) => _select([item]),
          );
          title = _isManga ? l10n.downloadsPickChapter : l10n.downloadsPickEpisode;
      }
    }
    return PopScope(
      canPop: atRoot,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: atRoot
          ? body
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  key: const ValueKey('download-back'),
                  leading: const Icon(Icons.arrow_back),
                  title: Text(title, style: Theme.of(context).textTheme.titleMedium),
                  onTap: _back,
                ),
                Expanded(child: body),
              ],
            ),
    );
  }

  String _count(int count) => _isManga ? context.l10n.downloadsChapters(count) : context.l10n.downloadsEpisodes(count);

  /// Everything, a season/volume (sub-list, when there are several) or a single item.
  Widget _options(List<ContentMediaItem> items) {
    final l10n = context.l10n;
    final hasSections = groupBySection(items).length > 1;
    return ListView(
      children: [
        ListTile(
          key: const ValueKey('download-all'),
          autofocus: _returnedFrom == null,
          leading: const Icon(Icons.download_for_offline_outlined),
          title: Text(l10n.downloadsAll),
          subtitle: Text(_count(items.length)),
          onTap: () => _select(items),
        ),
        if (hasSections)
          ListTile(
            key: const ValueKey('download-sections'),
            autofocus: _returnedFrom == _Step.sections,
            leading: const Icon(Icons.playlist_add),
            title: Text(_isManga ? l10n.downloadsPickVolume : l10n.downloadsPickSeason),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _open(_Step.sections),
          ),
        ListTile(
          key: const ValueKey('download-pick'),
          autofocus: _returnedFrom == _Step.items,
          leading: const Icon(Icons.format_list_bulleted),
          title: Text(_isManga ? l10n.downloadsPickChapter : l10n.downloadsPickEpisode),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _open(_Step.items),
        ),
      ],
    );
  }

  Widget _sections(List<ContentMediaItem> items) => ListView(
    children: [
      for (final (index, (section, sectionItems)) in groupBySection(items).indexed)
        ListTile(
          key: ValueKey('download-section-$index'),
          autofocus: index == 0,
          leading: const Icon(Icons.playlist_add),
          title: Text(section == null || section.isEmpty ? '${index + 1}' : section),
          subtitle: Text(_count(sectionItems.length)),
          onTap: () => _select(sectionItems),
        ),
    ],
  );
}

enum _Step { root, sections, items }

/// Downloadable sources of the first selected item (videos or manga translations, not local copies). One item
/// downloads on tap; for several items the user picks one or more sources in priority order, and each item gets the
/// first of them it has, or a similar one (spec-08 §8.2).
class _SourceList extends ConsumerStatefulWidget {
  final ContentDetails details;
  final List<ContentMediaItem> items;

  const _SourceList({required this.details, required this.items});

  @override
  ConsumerState<_SourceList> createState() => _SourceListState();
}

class _SourceListState extends ConsumerState<_SourceList> {
  late Future<List<ContentMediaItemSource>> _sources = _load();
  var _busy = false;

  /// Picked source descriptions, highest priority first.
  final _picked = <String>[];

  bool get _multiple => widget.items.length > 1;

  Future<List<ContentMediaItemSource>> _load() async => [
    for (final source in await widget.items.first.sources)
      if ((source is VideoMediaItemSource || source is MangaMediaItemSource) && !isLocalSource(source)) source,
  ];

  void _toggle(String name) => setState(() {
    if (!_picked.remove(name)) _picked.add(name);
  });

  Future<void> _download(FileKind kind, List<String> sourceNames) async {
    if (_busy) return;
    setState(() => _busy = true);
    final details = widget.details;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final l10n = context.l10n;
    try {
      await ensureDownloadPermissions(context, ref);
      final folder = ref.read(downloadsFolderProvider).path;
      await ref.read(offlineStorageProvider).writeDetails(details.supplier, details.id, OfflineDetails.of(details));
      final subtitle = ref.read(collectionItemProvider(details.supplier, details.id))?.currentSubtitleName;
      final requests = [
        for (final item in widget.items)
          DownloadRequest(
            supplier: details.supplier,
            contentId: details.id,
            itemIndex: item.number,
            title: details.title,
            // A movie's only item is often named like the movie itself.
            itemTitle: item.title == details.title ? '' : item.title,
            image: details.image,
            kind: kind,
            sourceNames: sourceNames,
            subtitleName: kind == FileKind.video ? subtitle : null,
            root: folder,
          ),
      ];
      await ref.read(downloadTasksProvider.notifier).send(EnqueueDownloads(requests));
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(l10n.downloadsAdded(requests.length))));
    } on FileSystemException {
      messenger.showSnackBar(SnackBar(content: Text(l10n.downloadsFailureStorage)));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FutureBuilder(
      future: _sources,
      builder: (context, snapshot) => switch (snapshot) {
        AsyncSnapshot(hasError: true) => LoadErrorView(
          autofocus: true,
          onRetry: () => setState(() => _sources = _load()),
        ),
        AsyncSnapshot(:final data?) when data.isEmpty => EmptyStateView(
          icon: Icons.download_outlined,
          message: l10n.downloadsNoSources,
        ),
        AsyncSnapshot(:final data?) when !_multiple => ListView(
          children: [
            for (final (index, source) in data.indexed)
              ListTile(
                key: ValueKey('download-source-$index'),
                autofocus: index == 0,
                enabled: !_busy,
                leading: _icon(source),
                title: Text(source.description),
                trailing: const Icon(Icons.download_outlined),
                onTap: () => unawaited(_download(_kind(source), [source.description])),
              ),
          ],
        ),
        AsyncSnapshot(:final data?) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(l10n.downloadsSourcesHint, style: Theme.of(context).textTheme.bodySmall),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final (index, source) in data.indexed)
                    _pickTile(index, source, _picked.indexOf(source.description)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                key: const ValueKey('download-start'),
                icon: const Icon(Icons.download_outlined),
                label: Text(l10n.detailsDownload),
                onPressed: _busy || _picked.isEmpty
                    ? null
                    : () => unawaited(
                        _download(_kind(data.firstWhere((s) => s.description == _picked.first)), [..._picked]),
                      ),
              ),
            ),
          ],
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _pickTile(int index, ContentMediaItemSource source, int priority) {
    final picked = priority >= 0;
    return ListTile(
      key: ValueKey('download-source-$index'),
      autofocus: index == 0,
      enabled: !_busy,
      selected: picked,
      leading: _icon(source),
      title: Text(source.description),
      subtitle: picked ? Text(context.l10n.downloadsSourcePriority(priority + 1)) : null,
      trailing: Icon(picked ? Icons.check_box : Icons.check_box_outline_blank),
      onTap: () => _toggle(source.description),
    );
  }

  static FileKind _kind(ContentMediaItemSource source) =>
      source is MangaMediaItemSource ? FileKind.manga : FileKind.video;

  static Widget _icon(ContentMediaItemSource source) =>
      Icon(source is MangaMediaItemSource ? Icons.menu_book_outlined : Icons.movie_outlined);
}
