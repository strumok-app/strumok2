// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_theme.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controls sit on video: the dark variant of the user's color scheme whatever the app brightness, so accents
/// (sliders, progress, focus) stay visible on black (e.g. the monochrome scheme is black on light). Side sheets
/// are routes and keep the app theme.

@ProviderFor(playerTheme)
final playerThemeProvider = PlayerThemeProvider._();

/// Controls sit on video: the dark variant of the user's color scheme whatever the app brightness, so accents
/// (sliders, progress, focus) stay visible on black (e.g. the monochrome scheme is black on light). Side sheets
/// are routes and keep the app theme.

final class PlayerThemeProvider
    extends $FunctionalProvider<ThemeData, ThemeData, ThemeData>
    with $Provider<ThemeData> {
  /// Controls sit on video: the dark variant of the user's color scheme whatever the app brightness, so accents
  /// (sliders, progress, focus) stay visible on black (e.g. the monochrome scheme is black on light). Side sheets
  /// are routes and keep the app theme.
  PlayerThemeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'playerThemeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$playerThemeHash();

  @$internal
  @override
  $ProviderElement<ThemeData> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ThemeData create(Ref ref) {
    return playerTheme(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ThemeData value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ThemeData>(value),
    );
  }
}

String _$playerThemeHash() => r'e1d88f6bcd915872100492389382bafddce2295b';
