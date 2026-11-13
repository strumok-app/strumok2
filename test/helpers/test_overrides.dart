import 'dart:io';

import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:strumok/core/network/http_client.dart';
import 'package:strumok/core/network/image_cache.dart';
import 'package:strumok/core/platform/app_paths.dart';
import 'package:strumok/core/platform/device_class.dart';
import 'package:strumok/core/storage/app_preferences.dart';
import 'package:strumok/features/collection/data/collection_repository.dart';
import 'package:strumok/features/suppliers/data/supplier_registry.dart';
import 'package:strumok/features/suppliers/domain/ffi_bundle_info.dart';
import 'package:strumok/features/updates/presentation/update_providers.dart';

typedef PageFetcher = Future<List<ContentInfo>> Function(String key, int page);

class FakeSupplier implements ContentSupplier {
  @override
  final String name;
  @override
  final Set<String> channels;
  @override
  final Set<String> defaultChannels;
  @override
  final Set<ContentLanguage> supportedLanguages;
  @override
  final Set<ContentType> supportedTypes;

  final PageFetcher? onLoadChannel;
  final PageFetcher? onSearch;
  final Map<String, ContentDetails> details;
  final calls = <String>[];

  FakeSupplier(
    this.name, {
    this.channels = const {'a', 'b', 'c'},
    this.defaultChannels = const {'a'},
    this.supportedLanguages = const {ContentLanguage.uk},
    this.supportedTypes = const {ContentType.movie},
    this.onLoadChannel,
    this.onSearch,
    this.details = const {},
  });

  @override
  Future<ContentDetails?> detailsById(String id) async {
    calls.add('details:$id');
    return details[id];
  }

  @override
  Future<List<ContentInfo>> loadChannel(String channel, {int page = 1}) async {
    calls.add('channel:$channel:$page');
    return onLoadChannel?.call(channel, page) ?? const [];
  }

  @override
  Future<List<ContentInfo>> search(String query, {int page = 1}) async {
    calls.add('search:$query:$page');
    return onSearch?.call(query, page) ?? const [];
  }
}

class FakeInfo implements ContentInfo {
  @override
  final String supplier;
  @override
  final String id;
  @override
  final String title;
  @override
  final String? secondaryTitle;
  @override
  final String image;

  const FakeInfo(this.supplier, this.id, {String? title, this.secondaryTitle, this.image = ''})
    : title = title ?? 'Title $id';
}

/// `count` items for pages 1..[pages], then an empty page.
PageFetcher pagesOf(String supplier, {int pages = 2, int count = 3}) =>
    (key, page) async =>
        page > pages ? const [] : [for (var i = 0; i < count; i++) FakeInfo(supplier, '$key-$page-$i')];

class FakeMediaItem implements ContentMediaItem {
  @override
  final int number;
  @override
  final String title;
  @override
  final String? section;
  @override
  String? get image => null;
  @override
  Future<List<ContentMediaItemSource>> get sources async => const [];

  const FakeMediaItem(this.number, this.title, {this.section});
}

class FakeDetails implements ContentDetails {
  @override
  final String supplier;
  @override
  final String id;
  @override
  final String title;
  @override
  final MediaType mediaType;
  @override
  final List<ContentInfo> similar;
  final Future<List<ContentMediaItem>> Function() loadItems;

  FakeDetails(
    this.supplier,
    this.id, {
    this.title = 'Fake title',
    this.mediaType = MediaType.video,
    this.similar = const [],
    Future<List<ContentMediaItem>> Function()? loadItems,
  }) : loadItems = loadItems ?? (() async => const []);

  @override
  String? get originalTitle => 'Original';
  @override
  String get image => '';
  @override
  String get description => 'Description';
  @override
  List<String> get additionalInfo => const ['2024', 'Drama'];
  @override
  Future<List<ContentMediaItem>> get mediaItems => loadItems();
}

/// Never loads images (no network/disk in tests).
class FakeCacheManager extends Fake implements BaseCacheManager {
  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) => const Stream.empty();
}

class FakeBundle implements ContentSupplierBundle {
  @override
  final List<ContentSupplier> suppliers;
  var unloaded = false;

  FakeBundle(this.suppliers);

  @override
  Future<void> load() async {}

  @override
  void unload() => unloaded = true;
}

FfiBundleInfo bundleInfo(String version, {String url = 'https://example.com/lib.so'}) => FfiBundleInfo.fromJson({
  'name': 'strumok_suppliers',
  'version': version,
  'downloadUrl': {'linux': url},
});

final defaultTestBundle = SupplierBundleReady(FakeBundle([FakeSupplier('dummy')]), bundleInfo('4.0.0'));

Future<AppPreferences> createTestPreferences([Map<String, Object> values = const {}]) async {
  SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.withData(values);
  return AppPreferences.create();
}

/// Root overrides equivalent to `bootstrap()` with fakes.
Future<List<Override>> testOverrides({
  DeviceClass deviceClass = DeviceClass.desktop,
  SupplierBundleState? bundle,
  AppPreferences? prefs,
  http.Client? client,
  String appVersion = '1.0.0',
}) async {
  final tmp = Directory.systemTemp.createTempSync('strumok_test');
  final paths = AppPaths(support: tmp, cache: Directory('${tmp.path}/cache'), temp: Directory('${tmp.path}/tmp'));
  return [
    appPreferencesProvider.overrideWithValue(prefs ?? await createTestPreferences()),
    appPathsProvider.overrideWithValue(paths),
    deviceClassProvider.overrideWithValue(deviceClass),
    currentAppVersionProvider.overrideWithValue(appVersion),
    httpClientProvider.overrideWithValue(client ?? MockClient((_) async => http.Response('', 404))),
    bundleDownloadKeyProvider.overrideWithValue('linux'),
    initialSupplierBundleProvider.overrideWithValue(bundle ?? defaultTestBundle),
    imageCacheManagerProvider.overrideWithValue(FakeCacheManager()),
    collectionDatabaseFactoryProvider.overrideWithValue(newDatabaseFactoryMemory()),
  ];
}
