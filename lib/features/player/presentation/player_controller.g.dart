// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(videoBackendFactory)
final videoBackendFactoryProvider = VideoBackendFactoryProvider._();

final class VideoBackendFactoryProvider
    extends $FunctionalProvider<VideoBackend Function(), VideoBackend Function(), VideoBackend Function()>
    with $Provider<VideoBackend Function()> {
  VideoBackendFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoBackendFactoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoBackendFactoryHash();

  @$internal
  @override
  $ProviderElement<VideoBackend Function()> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  VideoBackend Function() create(Ref ref) {
    return videoBackendFactory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VideoBackend Function() value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<VideoBackend Function()>(value));
  }
}

String _$videoBackendFactoryHash() => r'506e30b37416763370b86454c667e80d70da4208';

/// UI-agnostic player (spec-06 §6.1–6.2): loads items and sources, drives the backend, saves progress.
/// Kept alive so the session can outlive the player route (floating player / PiP, M6).

@ProviderFor(PlayerController)
final playerControllerProvider = PlayerControllerProvider._();

/// UI-agnostic player (spec-06 §6.1–6.2): loads items and sources, drives the backend, saves progress.
/// Kept alive so the session can outlive the player route (floating player / PiP, M6).
final class PlayerControllerProvider extends $NotifierProvider<PlayerController, PlayerSession?> {
  /// UI-agnostic player (spec-06 §6.1–6.2): loads items and sources, drives the backend, saves progress.
  /// Kept alive so the session can outlive the player route (floating player / PiP, M6).
  PlayerControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'playerControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$playerControllerHash();

  @$internal
  @override
  PlayerController create() => PlayerController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlayerSession? value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<PlayerSession?>(value));
  }
}

String _$playerControllerHash() => r'4c9a7c14c909c5a9a9ebedc57bb4080b5309e5b6';

/// UI-agnostic player (spec-06 §6.1–6.2): loads items and sources, drives the backend, saves progress.
/// Kept alive so the session can outlive the player route (floating player / PiP, M6).

abstract class _$PlayerController extends $Notifier<PlayerSession?> {
  PlayerSession? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<PlayerSession?, PlayerSession?>;
    final element =
        ref.element
            as $ClassProviderElement<AnyNotifier<PlayerSession?, PlayerSession?>, PlayerSession?, Object?, Object?>;
    return element.handleCreate(ref, build);
  }
}
