import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/riverpod/cache_for.dart';
import '../../suppliers/data/supplier_registry.dart';

part 'details_providers.g.dart';

class ContentNotFoundException implements Exception {
  final String supplier;
  final String id;

  const ContentNotFoundException(this.supplier, this.id);

  @override
  String toString() => 'Content not found [supplier=$supplier id=$id]';
}

@riverpod
Future<ContentDetails> contentDetails(Ref ref, String supplier, String id) async {
  ref.cacheFor(const Duration(minutes: 5));
  final details = await ref.watch(supplierByNameProvider(supplier)).detailsById(id);
  return details ?? (throw ContentNotFoundException(supplier, id));
}

/// Lazily loaded items (spec-02 §2.3); list index is the item number stored by the collection.
@riverpod
Future<List<ContentMediaItem>> mediaItems(Ref ref, String supplier, String id) async {
  ref.cacheFor(const Duration(minutes: 5));
  final details = await ref.watch(contentDetailsProvider(supplier, id).future);
  return details.mediaItems;
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
