import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/riverpod/cache_for.dart';
import '../../../core/storage/offline_mode.dart';
import '../../downloads/data/local_sources.dart';
import '../../downloads/presentation/downloads_providers.dart';
import '../../suppliers/data/supplier_registry.dart';

part 'details_providers.g.dart';

class ContentNotFoundException implements Exception {
  final String supplier;
  final String id;

  const ContentNotFoundException(this.supplier, this.id);

  @override
  String toString() => 'Content not found [supplier=$supplier id=$id]';
}

/// Supplier details; in offline mode (or when the supplier fails and the content is downloaded) the details saved
/// with the download (spec-08 §8.4).
@riverpod
Future<ContentDetails> contentDetails(Ref ref, String supplier, String id) async {
  ref.cacheFor(const Duration(minutes: 5));
  Future<ContentDetails?> offline() async {
    final content = await ref.read(offlineContentProvider(supplier, id).future);
    return content == null ? null : offlineContentDetails(ref, content);
  }

  if (ref.watch(offlineModeProvider)) {
    return await offline() ?? (throw ContentNotFoundException(supplier, id));
  }
  try {
    final details = await ref.watch(supplierByNameProvider(supplier)).detailsById(id);
    return details ?? (throw ContentNotFoundException(supplier, id));
  } catch (_) {
    final fallback = await offline();
    if (fallback == null) rethrow;
    return fallback;
  }
}

/// Lazily loaded items (spec-02 §2.3) with their downloaded sources listed first (spec-08 §8.4).
/// Offline details list only downloaded items, so collection progress is keyed by [ContentMediaItem.number].
@riverpod
Future<List<ContentMediaItem>> mediaItems(Ref ref, String supplier, String id) async {
  ref.cacheFor(const Duration(minutes: 5));
  // The folder scan runs while the supplier loads the details and items.
  final local = ref.watch(offlineContentProvider(supplier, id).future)..ignore();
  final details = await ref.watch(contentDetailsProvider(supplier, id).future);
  final items = await details.mediaItems;
  if (details is OfflineContentDetails) return items;
  final content = await local;
  if (content == null) return items;
  return [
    for (final item in items)
      if (content.items[item.number] case final local?) OfflineAwareMediaItem(item, localSourcesOf(local)) else item,
  ];
}

/// Items grouped by `section`, preserving supplier order (never re-sorted).
List<(String?, List<ContentMediaItem>)> groupBySection(List<ContentMediaItem> items) {
  final groups = <(String?, List<ContentMediaItem>)>[];
  for (final item in items) {
    if (groups.isNotEmpty && groups.last.$1 == item.section) {
      groups.last.$2.add(item);
    } else {
      groups.add((item.section, [item]));
    }
  }
  return groups;
}

/// List index of the item with [number]; null when it is not in the list (e.g. not downloaded).
int? itemIndexOfNumber(List<ContentMediaItem> items, int number) {
  final index = items.indexWhere((i) => i.number == number);
  return index < 0 ? null : index;
}
