// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pip.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Overridden in `bootstrap()` with [createPip].

@ProviderFor(pip)
final pipProvider = PipProvider._();

/// Overridden in `bootstrap()` with [createPip].

final class PipProvider extends $FunctionalProvider<Pip, Pip, Pip> with $Provider<Pip> {
  /// Overridden in `bootstrap()` with [createPip].
  PipProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pipProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pipHash();

  @$internal
  @override
  $ProviderElement<Pip> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  Pip create(Ref ref) {
    return pip(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Pip value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<Pip>(value));
  }
}

String _$pipHash() => r'2c4acdb16cab04f042571ce0a3bc8079eb090fbe';
