// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subtitle_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(subtitleRepository)
final subtitleRepositoryProvider = SubtitleRepositoryProvider._();

final class SubtitleRepositoryProvider
    extends
        $FunctionalProvider<
          SubtitleRepository,
          SubtitleRepository,
          SubtitleRepository
        >
    with $Provider<SubtitleRepository> {
  SubtitleRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'subtitleRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$subtitleRepositoryHash();

  @$internal
  @override
  $ProviderElement<SubtitleRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SubtitleRepository create(Ref ref) {
    return subtitleRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SubtitleRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SubtitleRepository>(value),
    );
  }
}

String _$subtitleRepositoryHash() =>
    r'f29eb0d292c871c31de8539d44a269b08ec239eb';
