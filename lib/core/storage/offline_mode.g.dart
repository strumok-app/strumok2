// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_mode.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Global offline-mode switch (spec-08 §8.4, spec-09 key `offline_mode`). While on, the collection is local-only
/// and is reconciled with Firebase when it is turned off again (spec-03 §3.6).

@ProviderFor(OfflineMode)
final offlineModeProvider = OfflineModeProvider._();

/// Global offline-mode switch (spec-08 §8.4, spec-09 key `offline_mode`). While on, the collection is local-only
/// and is reconciled with Firebase when it is turned off again (spec-03 §3.6).
final class OfflineModeProvider extends $NotifierProvider<OfflineMode, bool> {
  /// Global offline-mode switch (spec-08 §8.4, spec-09 key `offline_mode`). While on, the collection is local-only
  /// and is reconciled with Firebase when it is turned off again (spec-03 §3.6).
  OfflineModeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'offlineModeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$offlineModeHash();

  @$internal
  @override
  OfflineMode create() => OfflineMode();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<bool>(value));
  }
}

String _$offlineModeHash() => r'3f0bfddb64155a0243de6ab9ae42153b105b0c71';

/// Global offline-mode switch (spec-08 §8.4, spec-09 key `offline_mode`). While on, the collection is local-only
/// and is reconciled with Firebase when it is turned off again (spec-03 §3.6).

abstract class _$OfflineMode extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element = ref.element as $ClassProviderElement<AnyNotifier<bool, bool>, bool, Object?, Object?>;
    return element.handleCreate(ref, build);
  }
}
