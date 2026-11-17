// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'manga_page_images.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(mangaPageImages)
final mangaPageImagesProvider = MangaPageImagesProvider._();

final class MangaPageImagesProvider extends $FunctionalProvider<MangaPageImages, MangaPageImages, MangaPageImages>
    with $Provider<MangaPageImages> {
  MangaPageImagesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mangaPageImagesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mangaPageImagesHash();

  @$internal
  @override
  $ProviderElement<MangaPageImages> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  MangaPageImages create(Ref ref) {
    return mangaPageImages(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MangaPageImages value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<MangaPageImages>(value));
  }
}

String _$mangaPageImagesHash() => r'898a35b6eb145d64024fed742e146f799fe827a4';
