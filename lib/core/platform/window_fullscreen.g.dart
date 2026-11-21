// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'window_fullscreen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(windowFullscreen)
final windowFullscreenProvider = WindowFullscreenProvider._();

final class WindowFullscreenProvider extends $FunctionalProvider<WindowFullscreen, WindowFullscreen, WindowFullscreen>
    with $Provider<WindowFullscreen> {
  WindowFullscreenProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'windowFullscreenProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$windowFullscreenHash();

  @$internal
  @override
  $ProviderElement<WindowFullscreen> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  WindowFullscreen create(Ref ref) {
    return windowFullscreen(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WindowFullscreen value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<WindowFullscreen>(value));
  }
}

String _$windowFullscreenHash() => r'83c9fbf531eaa81dcbb651ee74583a361bb41727';
