// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'details_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(contentDetails)
final contentDetailsProvider = ContentDetailsFamily._();

final class ContentDetailsProvider
    extends $FunctionalProvider<AsyncValue<ContentDetails>, ContentDetails, FutureOr<ContentDetails>>
    with $FutureModifier<ContentDetails>, $FutureProvider<ContentDetails> {
  ContentDetailsProvider._({required ContentDetailsFamily super.from, required (String, String) super.argument})
    : super(
        retry: null,
        name: r'contentDetailsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$contentDetailsHash();

  @override
  String toString() {
    return r'contentDetailsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<ContentDetails> $createElement($ProviderPointer pointer) => $FutureProviderElement(pointer);

  @override
  FutureOr<ContentDetails> create(Ref ref) {
    final argument = this.argument as (String, String);
    return contentDetails(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is ContentDetailsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$contentDetailsHash() => r'a1598460d164f708abba389faeabcb6e7208d308';

final class ContentDetailsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ContentDetails>, (String, String)> {
  ContentDetailsFamily._()
    : super(
        retry: null,
        name: r'contentDetailsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ContentDetailsProvider call(String supplier, String id) =>
      ContentDetailsProvider._(argument: (supplier, id), from: this);

  @override
  String toString() => r'contentDetailsProvider';
}

/// Lazily loaded items (spec-02 §2.3); list index is the item number stored by the collection.

@ProviderFor(mediaItems)
final mediaItemsProvider = MediaItemsFamily._();

/// Lazily loaded items (spec-02 §2.3); list index is the item number stored by the collection.

final class MediaItemsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ContentMediaItem>>,
          List<ContentMediaItem>,
          FutureOr<List<ContentMediaItem>>
        >
    with $FutureModifier<List<ContentMediaItem>>, $FutureProvider<List<ContentMediaItem>> {
  /// Lazily loaded items (spec-02 §2.3); list index is the item number stored by the collection.
  MediaItemsProvider._({required MediaItemsFamily super.from, required (String, String) super.argument})
    : super(
        retry: null,
        name: r'mediaItemsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mediaItemsHash();

  @override
  String toString() {
    return r'mediaItemsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<ContentMediaItem>> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<ContentMediaItem>> create(Ref ref) {
    final argument = this.argument as (String, String);
    return mediaItems(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is MediaItemsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$mediaItemsHash() => r'e388e062dfb2785e351cc201f433658a39fc8fc2';

/// Lazily loaded items (spec-02 §2.3); list index is the item number stored by the collection.

final class MediaItemsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<ContentMediaItem>>, (String, String)> {
  MediaItemsFamily._()
    : super(
        retry: null,
        name: r'mediaItemsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Lazily loaded items (spec-02 §2.3); list index is the item number stored by the collection.

  MediaItemsProvider call(String supplier, String id) => MediaItemsProvider._(argument: (supplier, id), from: this);

  @override
  String toString() => r'mediaItemsProvider';
}
