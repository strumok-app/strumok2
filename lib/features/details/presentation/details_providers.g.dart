// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'details_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Supplier details; in offline mode (or when the supplier fails and the content is downloaded) the details saved
/// with the download (spec-08 §8.4).

@ProviderFor(contentDetails)
final contentDetailsProvider = ContentDetailsFamily._();

/// Supplier details; in offline mode (or when the supplier fails and the content is downloaded) the details saved
/// with the download (spec-08 §8.4).

final class ContentDetailsProvider
    extends
        $FunctionalProvider<
          AsyncValue<ContentDetails>,
          ContentDetails,
          FutureOr<ContentDetails>
        >
    with $FutureModifier<ContentDetails>, $FutureProvider<ContentDetails> {
  /// Supplier details; in offline mode (or when the supplier fails and the content is downloaded) the details saved
  /// with the download (spec-08 §8.4).
  ContentDetailsProvider._({
    required ContentDetailsFamily super.from,
    required (String, String) super.argument,
  }) : super(
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
  $FutureProviderElement<ContentDetails> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

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

String _$contentDetailsHash() => r'f45a70ffc5d4baa1003abbb7be060aee73c50ea9';

/// Supplier details; in offline mode (or when the supplier fails and the content is downloaded) the details saved
/// with the download (spec-08 §8.4).

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

  /// Supplier details; in offline mode (or when the supplier fails and the content is downloaded) the details saved
  /// with the download (spec-08 §8.4).

  ContentDetailsProvider call(String supplier, String id) =>
      ContentDetailsProvider._(argument: (supplier, id), from: this);

  @override
  String toString() => r'contentDetailsProvider';
}

/// Lazily loaded items (spec-02 §2.3) with their downloaded sources listed first (spec-08 §8.4).
/// Offline details list only downloaded items, so collection progress is keyed by [ContentMediaItem.number].

@ProviderFor(mediaItems)
final mediaItemsProvider = MediaItemsFamily._();

/// Lazily loaded items (spec-02 §2.3) with their downloaded sources listed first (spec-08 §8.4).
/// Offline details list only downloaded items, so collection progress is keyed by [ContentMediaItem.number].

final class MediaItemsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ContentMediaItem>>,
          List<ContentMediaItem>,
          FutureOr<List<ContentMediaItem>>
        >
    with
        $FutureModifier<List<ContentMediaItem>>,
        $FutureProvider<List<ContentMediaItem>> {
  /// Lazily loaded items (spec-02 §2.3) with their downloaded sources listed first (spec-08 §8.4).
  /// Offline details list only downloaded items, so collection progress is keyed by [ContentMediaItem.number].
  MediaItemsProvider._({
    required MediaItemsFamily super.from,
    required (String, String) super.argument,
  }) : super(
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
  $FutureProviderElement<List<ContentMediaItem>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

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

String _$mediaItemsHash() => r'9edf7dd219e60c5f81a82a7633aad196a44bc5e0';

/// Lazily loaded items (spec-02 §2.3) with their downloaded sources listed first (spec-08 §8.4).
/// Offline details list only downloaded items, so collection progress is keyed by [ContentMediaItem.number].

final class MediaItemsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<ContentMediaItem>>,
          (String, String)
        > {
  MediaItemsFamily._()
    : super(
        retry: null,
        name: r'mediaItemsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Lazily loaded items (spec-02 §2.3) with their downloaded sources listed first (spec-08 §8.4).
  /// Offline details list only downloaded items, so collection progress is keyed by [ContentMediaItem.number].

  MediaItemsProvider call(String supplier, String id) =>
      MediaItemsProvider._(argument: (supplier, id), from: this);

  @override
  String toString() => r'mediaItemsProvider';
}
