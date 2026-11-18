// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'floating_player.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether the session is shown in the in-app mini player (spec-06 §6.9); hidden whenever the session ends.

@ProviderFor(FloatingPlayer)
final floatingPlayerProvider = FloatingPlayerProvider._();

/// Whether the session is shown in the in-app mini player (spec-06 §6.9); hidden whenever the session ends.
final class FloatingPlayerProvider extends $NotifierProvider<FloatingPlayer, bool> {
  /// Whether the session is shown in the in-app mini player (spec-06 §6.9); hidden whenever the session ends.
  FloatingPlayerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'floatingPlayerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$floatingPlayerHash();

  @$internal
  @override
  FloatingPlayer create() => FloatingPlayer();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<bool>(value));
  }
}

String _$floatingPlayerHash() => r'1dc55b16c3f327f9f9fd06f0e1d820225f0621ef';

/// Whether the session is shown in the in-app mini player (spec-06 §6.9); hidden whenever the session ends.

abstract class _$FloatingPlayer extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element = ref.element as $ClassProviderElement<AnyNotifier<bool, bool>, bool, Object?, Object?>;
    return element.handleCreate(ref, build);
  }
}
