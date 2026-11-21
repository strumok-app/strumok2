// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profiles_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Device-wide list of profiles (spec-05 §5.1). The first launch creates a default profile.

@ProviderFor(Profiles)
final profilesProvider = ProfilesProvider._();

/// Device-wide list of profiles (spec-05 §5.1). The first launch creates a default profile.
final class ProfilesProvider extends $NotifierProvider<Profiles, List<Profile>> {
  /// Device-wide list of profiles (spec-05 §5.1). The first launch creates a default profile.
  ProfilesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profilesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profilesHash();

  @$internal
  @override
  Profiles create() => Profiles();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<Profile> value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<List<Profile>>(value));
  }
}

String _$profilesHash() => r'769018e8180f7a529b55e6c6acc320a71b0116ff';

/// Device-wide list of profiles (spec-05 §5.1). The first launch creates a default profile.

abstract class _$Profiles extends $Notifier<List<Profile>> {
  List<Profile> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<List<Profile>, List<Profile>>;
    final element =
        ref.element
            as $ClassProviderElement<AnyNotifier<List<Profile>, List<Profile>>, List<Profile>, Object?, Object?>;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(ActiveProfile)
final activeProfileProvider = ActiveProfileProvider._();

final class ActiveProfileProvider extends $NotifierProvider<ActiveProfile, Profile> {
  ActiveProfileProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeProfileProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeProfileHash();

  @$internal
  @override
  ActiveProfile create() => ActiveProfile();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Profile value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<Profile>(value));
  }
}

String _$activeProfileHash() => r'0a21fa57153039ad83f5baa49267aab11058953a';

abstract class _$ActiveProfile extends $Notifier<Profile> {
  Profile build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Profile, Profile>;
    final element = ref.element as $ClassProviderElement<AnyNotifier<Profile, Profile>, Profile, Object?, Object?>;
    return element.handleCreate(ref, build);
  }
}

/// Only the id: consumers that hold per-profile resources must not rebuild on rename.

@ProviderFor(activeProfileId)
final activeProfileIdProvider = ActiveProfileIdProvider._();

/// Only the id: consumers that hold per-profile resources must not rebuild on rename.

final class ActiveProfileIdProvider extends $FunctionalProvider<String, String, String> with $Provider<String> {
  /// Only the id: consumers that hold per-profile resources must not rebuild on rename.
  ActiveProfileIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeProfileIdProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeProfileIdHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return activeProfileId(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<String>(value));
  }
}

String _$activeProfileIdHash() => r'7c600d24b9dd4e181c90cdfe76bae9efdb80ff24';

@ProviderFor(ProfileAskOnStartup)
final profileAskOnStartupProvider = ProfileAskOnStartupProvider._();

final class ProfileAskOnStartupProvider extends $NotifierProvider<ProfileAskOnStartup, bool> {
  ProfileAskOnStartupProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileAskOnStartupProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileAskOnStartupHash();

  @$internal
  @override
  ProfileAskOnStartup create() => ProfileAskOnStartup();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<bool>(value));
  }
}

String _$profileAskOnStartupHash() => r'c64954ad014faf1e72758a469f2f99b53e9b2c1d';

abstract class _$ProfileAskOnStartup extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element = ref.element as $ClassProviderElement<AnyNotifier<bool, bool>, bool, Object?, Object?>;
    return element.handleCreate(ref, build);
  }
}

/// True until a profile is picked in this app run, when the picker applies (≥ 2 profiles, spec-05 §5.4).

@ProviderFor(ProfilePickPending)
final profilePickPendingProvider = ProfilePickPendingProvider._();

/// True until a profile is picked in this app run, when the picker applies (≥ 2 profiles, spec-05 §5.4).
final class ProfilePickPendingProvider extends $NotifierProvider<ProfilePickPending, bool> {
  /// True until a profile is picked in this app run, when the picker applies (≥ 2 profiles, spec-05 §5.4).
  ProfilePickPendingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profilePickPendingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profilePickPendingHash();

  @$internal
  @override
  ProfilePickPending create() => ProfilePickPending();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<bool>(value));
  }
}

String _$profilePickPendingHash() => r'15ec6421ac3e625c586dd51d2e72023b7c523d1c';

/// True until a profile is picked in this app run, when the picker applies (≥ 2 profiles, spec-05 §5.4).

abstract class _$ProfilePickPending extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element = ref.element as $ClassProviderElement<AnyNotifier<bool, bool>, bool, Object?, Object?>;
    return element.handleCreate(ref, build);
  }
}
