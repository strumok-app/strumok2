// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'single_instance.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The lock of the running desktop instance; null on Android (the system keeps one activity task).

@ProviderFor(singleInstance)
final singleInstanceProvider = SingleInstanceProvider._();

/// The lock of the running desktop instance; null on Android (the system keeps one activity task).

final class SingleInstanceProvider
    extends
        $FunctionalProvider<SingleInstance?, SingleInstance?, SingleInstance?>
    with $Provider<SingleInstance?> {
  /// The lock of the running desktop instance; null on Android (the system keeps one activity task).
  SingleInstanceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'singleInstanceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$singleInstanceHash();

  @$internal
  @override
  $ProviderElement<SingleInstance?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SingleInstance? create(Ref ref) {
    return singleInstance(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SingleInstance? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SingleInstance?>(value),
    );
  }
}

String _$singleInstanceHash() => r'23aba48a9f593894e7661bd196833165920c4420';
