// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'downloads_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Downloads folder (spec-08 §8.3, spec-09 key `offline_downloads_directory`): user-selectable on desktop; a folder
/// that no longer exists falls back to the default.

@ProviderFor(DownloadsFolder)
final downloadsFolderProvider = DownloadsFolderProvider._();

/// Downloads folder (spec-08 §8.3, spec-09 key `offline_downloads_directory`): user-selectable on desktop; a folder
/// that no longer exists falls back to the default.
final class DownloadsFolderProvider
    extends $NotifierProvider<DownloadsFolder, Directory> {
  /// Downloads folder (spec-08 §8.3, spec-09 key `offline_downloads_directory`): user-selectable on desktop; a folder
  /// that no longer exists falls back to the default.
  DownloadsFolderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadsFolderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadsFolderHash();

  @$internal
  @override
  DownloadsFolder create() => DownloadsFolder();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Directory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Directory>(value),
    );
  }
}

String _$downloadsFolderHash() => r'18a0f3d8fc0857aceb978aa8c30a19d8d2c51787';

/// Downloads folder (spec-08 §8.3, spec-09 key `offline_downloads_directory`): user-selectable on desktop; a folder
/// that no longer exists falls back to the default.

abstract class _$DownloadsFolder extends $Notifier<Directory> {
  Directory build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Directory, Directory>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Directory, Directory>,
              Directory,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Global concurrency limit (spec-08 §8.1: default 3, range 1–5).

@ProviderFor(MaxParallelDownloads)
final maxParallelDownloadsProvider = MaxParallelDownloadsProvider._();

/// Global concurrency limit (spec-08 §8.1: default 3, range 1–5).
final class MaxParallelDownloadsProvider
    extends $NotifierProvider<MaxParallelDownloads, int> {
  /// Global concurrency limit (spec-08 §8.1: default 3, range 1–5).
  MaxParallelDownloadsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'maxParallelDownloadsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$maxParallelDownloadsHash();

  @$internal
  @override
  MaxParallelDownloads create() => MaxParallelDownloads();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$maxParallelDownloadsHash() =>
    r'70d57353353b481796b802d2b768baa319ab9271';

/// Global concurrency limit (spec-08 §8.1: default 3, range 1–5).

abstract class _$MaxParallelDownloads extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The download manager (spec-08 §8.1): an Android foreground service isolate, in-process elsewhere.

@ProviderFor(downloadService)
final downloadServiceProvider = DownloadServiceProvider._();

/// The download manager (spec-08 §8.1): an Android foreground service isolate, in-process elsewhere.

final class DownloadServiceProvider
    extends
        $FunctionalProvider<
          AsyncValue<DownloadService>,
          DownloadService,
          FutureOr<DownloadService>
        >
    with $FutureModifier<DownloadService>, $FutureProvider<DownloadService> {
  /// The download manager (spec-08 §8.1): an Android foreground service isolate, in-process elsewhere.
  DownloadServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadServiceHash();

  @$internal
  @override
  $FutureProviderElement<DownloadService> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<DownloadService> create(Ref ref) {
    return downloadService(ref);
  }
}

String _$downloadServiceHash() => r'd6321aaf1d6a280e03fe306b510dffd085954059';

/// Current queue; updates with throttled progress, so watch it with `select` outside the downloads page.

@ProviderFor(DownloadTasks)
final downloadTasksProvider = DownloadTasksProvider._();

/// Current queue; updates with throttled progress, so watch it with `select` outside the downloads page.
final class DownloadTasksProvider
    extends $AsyncNotifierProvider<DownloadTasks, DownloadQueue> {
  /// Current queue; updates with throttled progress, so watch it with `select` outside the downloads page.
  DownloadTasksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadTasksProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadTasksHash();

  @$internal
  @override
  DownloadTasks create() => DownloadTasks();
}

String _$downloadTasksHash() => r'cd73b28a89557cfca02622d7437079b4929a9777';

/// Current queue; updates with throttled progress, so watch it with `select` outside the downloads page.

abstract class _$DownloadTasks extends $AsyncNotifier<DownloadQueue> {
  FutureOr<DownloadQueue> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<DownloadQueue>, DownloadQueue>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<DownloadQueue>, DownloadQueue>,
              AsyncValue<DownloadQueue>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Active (queued + running) tasks, for badges.

@ProviderFor(activeDownloadCount)
final activeDownloadCountProvider = ActiveDownloadCountProvider._();

/// Active (queued + running) tasks, for badges.

final class ActiveDownloadCountProvider
    extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  /// Active (queued + running) tasks, for badges.
  ActiveDownloadCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeDownloadCountProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeDownloadCountHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return activeDownloadCount(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$activeDownloadCountHash() =>
    r'ca19ad8d4b6e939f8ebfd15306b2b88b619d31af';

/// The task of one media item, if any.

@ProviderFor(itemDownloadTask)
final itemDownloadTaskProvider = ItemDownloadTaskFamily._();

/// The task of one media item, if any.

final class ItemDownloadTaskProvider
    extends $FunctionalProvider<DownloadTask?, DownloadTask?, DownloadTask?>
    with $Provider<DownloadTask?> {
  /// The task of one media item, if any.
  ItemDownloadTaskProvider._({
    required ItemDownloadTaskFamily super.from,
    required (String, String, int) super.argument,
  }) : super(
         retry: null,
         name: r'itemDownloadTaskProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$itemDownloadTaskHash();

  @override
  String toString() {
    return r'itemDownloadTaskProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $ProviderElement<DownloadTask?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DownloadTask? create(Ref ref) {
    final argument = this.argument as (String, String, int);
    return itemDownloadTask(ref, argument.$1, argument.$2, argument.$3);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DownloadTask? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DownloadTask?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ItemDownloadTaskProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$itemDownloadTaskHash() => r'67bc688b05b206e533a6ca8f3093939d03e94df9';

/// The task of one media item, if any.

final class ItemDownloadTaskFamily extends $Family
    with $FunctionalFamilyOverride<DownloadTask?, (String, String, int)> {
  ItemDownloadTaskFamily._()
    : super(
        retry: null,
        name: r'itemDownloadTaskProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The task of one media item, if any.

  ItemDownloadTaskProvider call(String supplier, String id, int itemIndex) =>
      ItemDownloadTaskProvider._(
        argument: (supplier, id, itemIndex),
        from: this,
      );

  @override
  String toString() => r'itemDownloadTaskProvider';
}

/// Bumped to scan everything again (e.g. files changed outside the app); single contents are refreshed with
/// [refreshOfflineContent].

@ProviderFor(OfflineRevision)
final offlineRevisionProvider = OfflineRevisionProvider._();

/// Bumped to scan everything again (e.g. files changed outside the app); single contents are refreshed with
/// [refreshOfflineContent].
final class OfflineRevisionProvider
    extends $NotifierProvider<OfflineRevision, int> {
  /// Bumped to scan everything again (e.g. files changed outside the app); single contents are refreshed with
  /// [refreshOfflineContent].
  OfflineRevisionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'offlineRevisionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$offlineRevisionHash();

  @$internal
  @override
  OfflineRevision create() => OfflineRevision();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$offlineRevisionHash() => r'199690f3eee3ae3ed280eb136f8bb166d8933f17';

/// Bumped to scan everything again (e.g. files changed outside the app); single contents are refreshed with
/// [refreshOfflineContent].

abstract class _$OfflineRevision extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(offlineStorage)
final offlineStorageProvider = OfflineStorageProvider._();

final class OfflineStorageProvider
    extends $FunctionalProvider<OfflineStorage, OfflineStorage, OfflineStorage>
    with $Provider<OfflineStorage> {
  OfflineStorageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'offlineStorageProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$offlineStorageHash();

  @$internal
  @override
  $ProviderElement<OfflineStorage> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  OfflineStorage create(Ref ref) {
    return offlineStorage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OfflineStorage value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OfflineStorage>(value),
    );
  }
}

String _$offlineStorageHash() => r'10e8344f9ed94e02891185231d8c7da2ecbbf798';

/// Downloaded contents, newest first (folders only).

@ProviderFor(offlineContentIds)
final offlineContentIdsProvider = OfflineContentIdsProvider._();

/// Downloaded contents, newest first (folders only).

final class OfflineContentIdsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<OfflineContentId>>,
          List<OfflineContentId>,
          FutureOr<List<OfflineContentId>>
        >
    with
        $FutureModifier<List<OfflineContentId>>,
        $FutureProvider<List<OfflineContentId>> {
  /// Downloaded contents, newest first (folders only).
  OfflineContentIdsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'offlineContentIdsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$offlineContentIdsHash();

  @$internal
  @override
  $FutureProviderElement<List<OfflineContentId>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<OfflineContentId>> create(Ref ref) {
    return offlineContentIds(ref);
  }
}

String _$offlineContentIdsHash() => r'172f64b7fc3ddb1c9c8a0a58e98da5d3e9676a17';

/// Details and finished items of one downloaded content.

@ProviderFor(offlineContent)
final offlineContentProvider = OfflineContentFamily._();

/// Details and finished items of one downloaded content.

final class OfflineContentProvider
    extends
        $FunctionalProvider<
          AsyncValue<DownloadedContent?>,
          DownloadedContent?,
          FutureOr<DownloadedContent?>
        >
    with
        $FutureModifier<DownloadedContent?>,
        $FutureProvider<DownloadedContent?> {
  /// Details and finished items of one downloaded content.
  OfflineContentProvider._({
    required OfflineContentFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'offlineContentProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$offlineContentHash();

  @override
  String toString() {
    return r'offlineContentProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<DownloadedContent?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<DownloadedContent?> create(Ref ref) {
    final argument = this.argument as (String, String);
    return offlineContent(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is OfflineContentProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$offlineContentHash() => r'02d59a49a4288901f56bdf733144e74e1f10e5ca';

/// Details and finished items of one downloaded content.

final class OfflineContentFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<DownloadedContent?>,
          (String, String)
        > {
  OfflineContentFamily._()
    : super(
        retry: null,
        name: r'offlineContentProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Details and finished items of one downloaded content.

  OfflineContentProvider call(String supplier, String id) =>
      OfflineContentProvider._(argument: (supplier, id), from: this);

  @override
  String toString() => r'offlineContentProvider';
}

/// Disk usage of one downloaded content; loaded apart from its items (it stats every file).

@ProviderFor(offlineContentSize)
final offlineContentSizeProvider = OfflineContentSizeFamily._();

/// Disk usage of one downloaded content; loaded apart from its items (it stats every file).

final class OfflineContentSizeProvider
    extends $FunctionalProvider<AsyncValue<int>, int, FutureOr<int>>
    with $FutureModifier<int>, $FutureProvider<int> {
  /// Disk usage of one downloaded content; loaded apart from its items (it stats every file).
  OfflineContentSizeProvider._({
    required OfflineContentSizeFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'offlineContentSizeProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$offlineContentSizeHash();

  @override
  String toString() {
    return r'offlineContentSizeProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<int> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int> create(Ref ref) {
    final argument = this.argument as (String, String);
    return offlineContentSize(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is OfflineContentSizeProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$offlineContentSizeHash() =>
    r'459c97f450ca4407a98e3a38f388564f79e52c68';

/// Disk usage of one downloaded content; loaded apart from its items (it stats every file).

final class OfflineContentSizeFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<int>, (String, String)> {
  OfflineContentSizeFamily._()
    : super(
        retry: null,
        name: r'offlineContentSizeProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Disk usage of one downloaded content; loaded apart from its items (it stats every file).

  OfflineContentSizeProvider call(String supplier, String id) =>
      OfflineContentSizeProvider._(argument: (supplier, id), from: this);

  @override
  String toString() => r'offlineContentSizeProvider';
}

/// Every downloaded content; one content refreshed with [refreshOfflineContent] is scanned again, the others come
/// from their cached [offlineContentProvider].

@ProviderFor(offlineContents)
final offlineContentsProvider = OfflineContentsProvider._();

/// Every downloaded content; one content refreshed with [refreshOfflineContent] is scanned again, the others come
/// from their cached [offlineContentProvider].

final class OfflineContentsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<DownloadedContent>>,
          List<DownloadedContent>,
          FutureOr<List<DownloadedContent>>
        >
    with
        $FutureModifier<List<DownloadedContent>>,
        $FutureProvider<List<DownloadedContent>> {
  /// Every downloaded content; one content refreshed with [refreshOfflineContent] is scanned again, the others come
  /// from their cached [offlineContentProvider].
  OfflineContentsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'offlineContentsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$offlineContentsHash();

  @$internal
  @override
  $FutureProviderElement<List<DownloadedContent>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<DownloadedContent>> create(Ref ref) {
    return offlineContents(ref);
  }
}

String _$offlineContentsHash() => r'5b9dfa0369a5494f306c951682dbafd7436b5914';

/// Deletes downloaded files after canceling their tasks, then refreshes what is available offline. Kept alive:
/// buttons call it with `ref.read` and the work continues after awaits.

@ProviderFor(OfflineFiles)
final offlineFilesProvider = OfflineFilesProvider._();

/// Deletes downloaded files after canceling their tasks, then refreshes what is available offline. Kept alive:
/// buttons call it with `ref.read` and the work continues after awaits.
final class OfflineFilesProvider extends $NotifierProvider<OfflineFiles, void> {
  /// Deletes downloaded files after canceling their tasks, then refreshes what is available offline. Kept alive:
  /// buttons call it with `ref.read` and the work continues after awaits.
  OfflineFilesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'offlineFilesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$offlineFilesHash();

  @$internal
  @override
  OfflineFiles create() => OfflineFiles();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$offlineFilesHash() => r'e13c95ac0c9893fc8fc35fce54e30082d14c1d0f';

/// Deletes downloaded files after canceling their tasks, then refreshes what is available offline. Kept alive:
/// buttons call it with `ref.read` and the work continues after awaits.

abstract class _$OfflineFiles extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
