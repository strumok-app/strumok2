import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter/material.dart';

import '../../../core/localization.dart';
import '../domain/collection_item.dart';

extension CollectionLabels on AppLocalizations {
  String collectionStatus(CollectionStatus status) => switch (status) {
    CollectionStatus.none => collectionStatusNone,
    CollectionStatus.inProgress => collectionStatusInProgress,
    CollectionStatus.latter => collectionStatusLater,
    CollectionStatus.onHold => collectionStatusOnHold,
    CollectionStatus.complete => collectionStatusComplete,
  };

  String collectionPriority(CollectionPriority priority) => switch (priority) {
    CollectionPriority.low => collectionPriorityLow,
    CollectionPriority.normal => collectionPriorityNormal,
    CollectionPriority.high => collectionPriorityHigh,
  };

  /// "Episode N" / "Chapter N" for the item index (0-based).
  String collectionCurrentItem(CollectionItem item) => item.mediaType == MediaType.video
      ? collectionEpisode(item.currentItem + 1)
      : collectionChapter(item.currentItem + 1);
}

IconData collectionStatusIcon(CollectionStatus status) => switch (status) {
  CollectionStatus.none => Icons.bookmark_add_outlined,
  CollectionStatus.inProgress => Icons.play_circle_outline,
  CollectionStatus.latter => Icons.schedule,
  CollectionStatus.onHold => Icons.pause_circle_outline,
  CollectionStatus.complete => Icons.check_circle_outline,
};
