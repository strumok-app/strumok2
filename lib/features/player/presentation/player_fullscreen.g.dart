// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_fullscreen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Desktop window full screen while in the player; left when the player closes.

@ProviderFor(PlayerFullscreen)
final playerFullscreenProvider = PlayerFullscreenProvider._();

/// Desktop window full screen while in the player; left when the player closes.
final class PlayerFullscreenProvider extends $NotifierProvider<PlayerFullscreen, bool> {
  /// Desktop window full screen while in the player; left when the player closes.
  PlayerFullscreenProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'playerFullscreenProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$playerFullscreenHash();

  @$internal
  @override
  PlayerFullscreen create() => PlayerFullscreen();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<bool>(value));
  }
}

String _$playerFullscreenHash() => r'a24e6adaeada604b205b6fa780761a078b3bb9d6';

/// Desktop window full screen while in the player; left when the player closes.

abstract class _$PlayerFullscreen extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element = ref.element as $ClassProviderElement<AnyNotifier<bool, bool>, bool, Object?, Object?>;
    return element.handleCreate(ref, build);
  }
}
