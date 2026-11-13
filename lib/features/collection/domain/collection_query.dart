import 'package:content_suppliers_api/content_suppliers_api.dart';

import 'collection_item.dart';

/// Group order on the collection page (spec-01).
const collectionStatusOrder = [
  CollectionStatus.inProgress,
  CollectionStatus.latter,
  CollectionStatus.onHold,
  CollectionStatus.complete,
];

final _wordPattern = RegExp(r'[\u0400-\u04FF\w]+', unicode: true);

/// Lowercased words of [text] (Cyrillic aware), stored locally for prefix search (spec-03 §3.5).
List<String> searchTokens(String text) => [for (final m in _wordPattern.allMatches(text.toLowerCase())) m[0]!];

/// True when any query word is a prefix of any title word.
bool matchesQuery(List<String> tokens, String query) {
  final words = searchTokens(query);
  return words.isEmpty || words.any((w) => tokens.any((t) => t.startsWith(w)));
}

final class CollectionFilter {
  final String query;

  /// Empty sets mean "all".
  final Set<CollectionStatus> statuses;
  final Set<MediaType> mediaTypes;
  final Set<String> suppliers;

  const CollectionFilter({
    this.query = '',
    this.statuses = const {},
    this.mediaTypes = const {},
    this.suppliers = const {},
  });

  CollectionFilter copyWith({
    String? query,
    Set<CollectionStatus>? statuses,
    Set<MediaType>? mediaTypes,
    Set<String>? suppliers,
  }) => CollectionFilter(
    query: query ?? this.query,
    statuses: statuses ?? this.statuses,
    mediaTypes: mediaTypes ?? this.mediaTypes,
    suppliers: suppliers ?? this.suppliers,
  );

  bool accepts(CollectionItem item) =>
      (statuses.isEmpty || statuses.contains(item.status)) &&
      (mediaTypes.isEmpty || mediaTypes.contains(item.mediaType)) &&
      (suppliers.isEmpty || suppliers.contains(item.supplier)) &&
      matchesQuery(searchTokens(item.title), query);
}

/// Priority desc, then lastSeen desc.
int compareCollectionItems(CollectionItem a, CollectionItem b) {
  final byPriority = b.priority.index.compareTo(a.priority.index);
  return byPriority != 0 ? byPriority : b.lastSeen.compareTo(a.lastSeen);
}

/// Items grouped by status in [collectionStatusOrder], each group sorted; empty groups omitted.
List<(CollectionStatus, List<CollectionItem>)> groupCollection(
  Iterable<CollectionItem> items,
  CollectionFilter filter,
) {
  final groups = <(CollectionStatus, List<CollectionItem>)>[];
  for (final status in collectionStatusOrder) {
    final group = items.where((i) => i.status == status && filter.accepts(i)).toList()..sort(compareCollectionItems);
    if (group.isNotEmpty) groups.add((status, group));
  }
  return groups;
}

/// Home "Continue" row: in-progress items, or watch-later ones when there are none (spec-01 Home).
List<CollectionItem> continueItems(Iterable<CollectionItem> items) {
  List<CollectionItem> withStatus(CollectionStatus s) => [
    for (final i in items)
      if (i.status == s) i,
  ]..sort(compareCollectionItems);
  final inProgress = withStatus(CollectionStatus.inProgress);
  return inProgress.isNotEmpty ? inProgress : withStatus(CollectionStatus.latter);
}
