// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'manga_reader_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// UI-agnostic reader (spec-07): loads chapters, translations and pages, remembers the chapter, translation and
/// page in the collection (spec-03 §3.3).

@ProviderFor(MangaReaderController)
final mangaReaderControllerProvider = MangaReaderControllerFamily._();

/// UI-agnostic reader (spec-07): loads chapters, translations and pages, remembers the chapter, translation and
/// page in the collection (spec-03 §3.3).
final class MangaReaderControllerProvider extends $NotifierProvider<MangaReaderController, MangaReaderState> {
  /// UI-agnostic reader (spec-07): loads chapters, translations and pages, remembers the chapter, translation and
  /// page in the collection (spec-03 §3.3).
  MangaReaderControllerProvider._({
    required MangaReaderControllerFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'mangaReaderControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$mangaReaderControllerHash();

  @override
  String toString() {
    return r'mangaReaderControllerProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  MangaReaderController create() => MangaReaderController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MangaReaderState value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<MangaReaderState>(value));
  }

  @override
  bool operator ==(Object other) {
    return other is MangaReaderControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$mangaReaderControllerHash() => r'fd4ad9e485ffb7fc7b13cbf8c195b4b34c2af9f5';

/// UI-agnostic reader (spec-07): loads chapters, translations and pages, remembers the chapter, translation and
/// page in the collection (spec-03 §3.3).

final class MangaReaderControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          MangaReaderController,
          MangaReaderState,
          MangaReaderState,
          MangaReaderState,
          (String, String)
        > {
  MangaReaderControllerFamily._()
    : super(
        retry: null,
        name: r'mangaReaderControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// UI-agnostic reader (spec-07): loads chapters, translations and pages, remembers the chapter, translation and
  /// page in the collection (spec-03 §3.3).

  MangaReaderControllerProvider call(String supplier, String id) =>
      MangaReaderControllerProvider._(argument: (supplier, id), from: this);

  @override
  String toString() => r'mangaReaderControllerProvider';
}

/// UI-agnostic reader (spec-07): loads chapters, translations and pages, remembers the chapter, translation and
/// page in the collection (spec-03 §3.3).

abstract class _$MangaReaderController extends $Notifier<MangaReaderState> {
  late final _$args = ref.$arg as (String, String);
  String get supplier => _$args.$1;
  String get id => _$args.$2;

  MangaReaderState build(String supplier, String id);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<MangaReaderState, MangaReaderState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MangaReaderState, MangaReaderState>,
              MangaReaderState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args.$1, _$args.$2));
  }
}
