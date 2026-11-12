// FFI smoke test against the dummy supplier lib (spec-02, skill rust-supplier-bridge):
//   (cd packages/content_suppliers_rust/rust && cargo build --release)
//   flutter test integration_test/ffi_smoke_test.dart -d linux \
//     --dart-define=FFI_SUPPLIER_LIB_NAME=content_suppliers_rust \
//     --dart-define=FFI_SUPPLIER_LIBS_DIR=packages/content_suppliers_rust/rust/target/release
import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:strumok/app/app.dart';
import 'package:strumok/app/bootstrap.dart';
import 'package:strumok/app/router.dart';
import 'package:strumok/core/config.dart';
import 'package:strumok/features/suppliers/data/supplier_registry.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late ContentSupplier dummy;

  setUpAll(() async {
    expect(AppConfig.hasDevSupplierLib, isTrue, reason: 'FFI_SUPPLIER_LIBS_DIR must be defined');
    container = ProviderContainer(overrides: await bootstrap());
    expect(container.read(supplierRegistryProvider), isA<SupplierBundleReady>());
    dummy = container.read(suppliersProvider).singleWhere((s) => s.name == 'dummy');
  });

  tearDownAll(() => container.dispose());

  testWidgets('sync metadata', (_) async {
    expect(dummy.channels, {'dummy_channels'});
    expect(dummy.defaultChannels, {'dummy_channels'});
    expect(dummy.supportedTypes, {ContentType.movie, ContentType.anime});
    expect(dummy.supportedLanguages, {ContentLanguage.en, ContentLanguage.uk});
  });

  testWidgets('search and load_channel', (_) async {
    expect((await dummy.search('query')).single.id, 'query');
    expect((await dummy.loadChannel('dummy_channels', page: 2)).single.id, 'dummy_channels 2');
  });

  testWidgets('details, lazy media items, sources and manga pages', (_) async {
    final details = (await dummy.detailsById('id'))!;
    expect(details.mediaType, MediaType.video);
    final item = (await details.mediaItems).single;
    expect(item.section, '1,2,3');
    final sources = await item.sources;
    expect(sources.map((s) => s.kind), [FileKind.video, FileKind.subtitle, FileKind.manga]);
    expect(sources.first.headers, {'User-Agent': 'dummy'});
    expect(await (sources.last as MangaMediaItemSource).allPages, ['http://page1', 'http://page2']);
  });

  testWidgets('eager sources and load_manga_pages', (_) async {
    final eager = (await dummy.detailsById('eager_sources'))!;
    final video = (await (await eager.mediaItems).single.sources).single as VideoMediaItemSource;
    expect(await video.link, Uri.parse('http://paga'));

    final manga = (await dummy.detailsById('async_manga'))!;
    final source = (await (await manga.mediaItems).single.sources).single as MangaMediaItemSource;
    expect(await source.allPages, ['http://async_manga_async_manga']);
  });

  testWidgets('app starts in the shell with the dev bundle', (tester) async {
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const StrumokApp()));
    await tester.pumpAndSettle();
    expect(container.read(routerProvider).state.uri.path, AppRoutes.home);
  });
}
