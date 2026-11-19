// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Enabled suppliers in user order, each with its selected channels in supplier order (spec-01 Home).

@ProviderFor(homeRows)
final homeRowsProvider = HomeRowsProvider._();

/// Enabled suppliers in user order, each with its selected channels in supplier order (spec-01 Home).

final class HomeRowsProvider
    extends $FunctionalProvider<List<HomeRow>, List<HomeRow>, List<HomeRow>>
    with $Provider<List<HomeRow>> {
  /// Enabled suppliers in user order, each with its selected channels in supplier order (spec-01 Home).
  HomeRowsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'homeRowsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$homeRowsHash();

  @$internal
  @override
  $ProviderElement<List<HomeRow>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<HomeRow> create(Ref ref) {
    return homeRows(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<HomeRow> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<HomeRow>>(value),
    );
  }
}

String _$homeRowsHash() => r'2fd4a01cfe5be894dddff1223ee2aea85250580d';

/// One recommendation row; kept alive so Home keeps its rows when navigating away and back.

@ProviderFor(ChannelItems)
final channelItemsProvider = ChannelItemsFamily._();

/// One recommendation row; kept alive so Home keeps its rows when navigating away and back.
final class ChannelItemsProvider
    extends $NotifierProvider<ChannelItems, PagedItems<ContentInfo>> {
  /// One recommendation row; kept alive so Home keeps its rows when navigating away and back.
  ChannelItemsProvider._({
    required ChannelItemsFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'channelItemsProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$channelItemsHash();

  @override
  String toString() {
    return r'channelItemsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  ChannelItems create() => ChannelItems();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PagedItems<ContentInfo> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PagedItems<ContentInfo>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ChannelItemsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$channelItemsHash() => r'ec6b25cbf9a8c641952daba5e447e0879e4ee956';

/// One recommendation row; kept alive so Home keeps its rows when navigating away and back.

final class ChannelItemsFamily extends $Family
    with
        $ClassFamilyOverride<
          ChannelItems,
          PagedItems<ContentInfo>,
          PagedItems<ContentInfo>,
          PagedItems<ContentInfo>,
          (String, String)
        > {
  ChannelItemsFamily._()
    : super(
        retry: null,
        name: r'channelItemsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// One recommendation row; kept alive so Home keeps its rows when navigating away and back.

  ChannelItemsProvider call(String supplier, String channel) =>
      ChannelItemsProvider._(argument: (supplier, channel), from: this);

  @override
  String toString() => r'channelItemsProvider';
}

/// One recommendation row; kept alive so Home keeps its rows when navigating away and back.

abstract class _$ChannelItems extends $Notifier<PagedItems<ContentInfo>> {
  late final _$args = ref.$arg as (String, String);
  String get supplier => _$args.$1;
  String get channel => _$args.$2;

  PagedItems<ContentInfo> build(String supplier, String channel);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<PagedItems<ContentInfo>, PagedItems<ContentInfo>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PagedItems<ContentInfo>, PagedItems<ContentInfo>>,
              PagedItems<ContentInfo>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args.$1, _$args.$2));
  }
}
