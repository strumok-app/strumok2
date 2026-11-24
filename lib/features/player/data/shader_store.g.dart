// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shader_store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(shaderStore)
final shaderStoreProvider = ShaderStoreProvider._();

final class ShaderStoreProvider extends $FunctionalProvider<ShaderStore, ShaderStore, ShaderStore>
    with $Provider<ShaderStore> {
  ShaderStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shaderStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shaderStoreHash();

  @$internal
  @override
  $ProviderElement<ShaderStore> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  ShaderStore create(Ref ref) {
    return shaderStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ShaderStore value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<ShaderStore>(value));
  }
}

String _$shaderStoreHash() => r'f5ab61509ab649935f5cb492aee7025a76d2ed6e';
