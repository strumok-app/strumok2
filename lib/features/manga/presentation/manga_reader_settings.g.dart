// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'manga_reader_settings.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Persisted reader settings (spec-09 keys, enums stored by `.name`).

@ProviderFor(MangaReaderSettings)
final mangaReaderSettingsProvider = MangaReaderSettingsProvider._();

/// Persisted reader settings (spec-09 keys, enums stored by `.name`).
final class MangaReaderSettingsProvider
    extends $NotifierProvider<MangaReaderSettings, MangaReaderPreferences> {
  /// Persisted reader settings (spec-09 keys, enums stored by `.name`).
  MangaReaderSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mangaReaderSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mangaReaderSettingsHash();

  @$internal
  @override
  MangaReaderSettings create() => MangaReaderSettings();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MangaReaderPreferences value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MangaReaderPreferences>(value),
    );
  }
}

String _$mangaReaderSettingsHash() =>
    r'314cfd68520dcae4463925f16b46b0f5be912b06';

/// Persisted reader settings (spec-09 keys, enums stored by `.name`).

abstract class _$MangaReaderSettings extends $Notifier<MangaReaderPreferences> {
  MangaReaderPreferences build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<MangaReaderPreferences, MangaReaderPreferences>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MangaReaderPreferences, MangaReaderPreferences>,
              MangaReaderPreferences,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
