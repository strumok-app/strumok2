// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subtitle_size.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Subtitle font size in logical pixels (spec-09 key `video_player_subtitles_size`).

@ProviderFor(SubtitleSize)
final subtitleSizeProvider = SubtitleSizeProvider._();

/// Subtitle font size in logical pixels (spec-09 key `video_player_subtitles_size`).
final class SubtitleSizeProvider extends $NotifierProvider<SubtitleSize, double> {
  /// Subtitle font size in logical pixels (spec-09 key `video_player_subtitles_size`).
  SubtitleSizeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'subtitleSizeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$subtitleSizeHash();

  @$internal
  @override
  SubtitleSize create() => SubtitleSize();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(double value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<double>(value));
  }
}

String _$subtitleSizeHash() => r'74648612e4b6fec8df4b586f84faad02d64bc1a2';

/// Subtitle font size in logical pixels (spec-09 key `video_player_subtitles_size`).

abstract class _$SubtitleSize extends $Notifier<double> {
  double build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<double, double>;
    final element = ref.element as $ClassProviderElement<AnyNotifier<double, double>, double, Object?, Object?>;
    return element.handleCreate(ref, build);
  }
}
