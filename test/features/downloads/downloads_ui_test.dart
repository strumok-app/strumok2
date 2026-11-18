import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:strumok/app/router.dart';
import 'package:strumok/core/platform/background_permissions.dart';
import 'package:strumok/core/platform/device_class.dart';
import 'package:strumok/core/storage/app_preferences.dart';
import 'package:strumok/core/storage/offline_mode.dart';
import 'package:strumok/features/downloads/data/download_engine.dart';
import 'package:strumok/features/downloads/data/download_service.dart';
import 'package:strumok/features/downloads/domain/download_queue.dart';
import 'package:strumok/features/downloads/domain/download_task.dart';
import 'package:strumok/features/downloads/presentation/downloads_providers.dart';
import 'package:strumok/features/downloads/presentation/widgets/download_widgets.dart';
import 'package:strumok/features/manga/presentation/manga_reader_controller.dart';
import 'package:strumok/features/player/presentation/player_controller.dart';
import 'package:strumok/features/settings/presentation/settings_page.dart';
import 'package:strumok/features/suppliers/data/supplier_registry.dart';

import '../../helpers/fake_downloads.dart';
import '../../helpers/fake_player.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_overrides.dart';

class FakePermissions implements BackgroundPermissions {
  final calls = <String>[];

  @override
  Future<bool> get canRequestBatteryExemption async => true;

  @override
  Future<void> requestNotifications() async => calls.add('notifications');

  @override
  Future<void> requestBatteryExemption() async => calls.add('battery');
}

FakeMediaItem episode(int n, {String? section}) => FakeMediaItem(
  n,
  'Episode ${n + 1}',
  section: section,
  sourceList: [
    FakeVideoSource('A', url: 'https://a.example/$n.m3u8'),
    FakeVideoSource('B'),
    FakeSubtitleSource('UA subs'),
  ],
);

void main() {
  late FakeRunner runner;
  late MemoryQueueStore store;
  late FakePermissions permissions;
  late ProviderContainer container;
  late FakeVideoBackend backend;

  Directory folder() => container.read(downloadsFolderProvider);

  DownloadQueue queue() => container.read(downloadTasksProvider).value!;

  /// Lets real file IO (offline storage) complete; it does not run in the widget test's fake-async zone.
  Future<void> settle(WidgetTester tester, {bool animations = true}) async {
    // Each IO step (open, write, close, list…) needs a real event-loop turn followed by a pump; spinners shown
    // meanwhile would keep pumpAndSettle from settling.
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
      await tester.pump(const Duration(milliseconds: 16));
    }
    if (animations) await tester.pumpAndSettle();
  }

  void put(String relative, [List<int> bytes = const [1, 2, 3]]) => File(p.join(folder().path, relative))
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes);

  void putDetails(String supplier, String id, Map<String, Object?> json) =>
      put(p.join('${supplier}_${Uri.encodeComponent(id)}', 'details.json'), utf8.encode(jsonEncode(json)));

  Future<void> start(
    WidgetTester tester, {
    List<FakeMediaItem>? items,
    MediaType mediaType = MediaType.video,
    Map<String, Object> prefs = const {AppPreferences.downloadsBatteryPromptShown: true},
    FakeSupplier? supplier,
    DeviceClass deviceClass = DeviceClass.desktop,
    DirectoryPicker? picker,
  }) async {
    runner = FakeRunner();
    store = MemoryQueueStore();
    permissions = FakePermissions();
    final details = FakeDetails(
      'alpha',
      'm1',
      title: 'Show',
      mediaType: mediaType,
      loadItems: () async => items ?? [episode(0), episode(1), episode(2)],
    );
    container = await pumpApp(
      tester,
      deviceClass: deviceClass,
      prefs: await createTestPreferences(prefs),
      bundle: SupplierBundleReady(
        FakeBundle([
          supplier ?? FakeSupplier('alpha', details: {'m1': details}),
        ]),
        bundleInfo('4.0.0'),
      ),
      videoBackend: () => backend = FakeVideoBackend(),
      extraOverrides: [
        downloadServiceProvider.overrideWith(
          (ref) => InProcessDownloadService.start(
            DownloadEngine(store: store, runner: runner, progressInterval: Duration.zero),
          ),
        ),
        backgroundPermissionsProvider.overrideWithValue(permissions),
        if (picker != null) directoryPickerProvider.overrideWithValue(picker),
      ],
    );
    await settle(tester);
  }

  Future<void> go(WidgetTester tester, String route) async {
    unawaited(container.read(routerProvider).push(route));
    await settle(tester);
  }

  testAppWidgets('details: "download all" queues every episode with the chosen source, one at a time', (tester) async {
    await start(tester, prefs: const {});
    await go(tester, AppRoutes.details('alpha', 'm1'));

    await tester.tap(find.byKey(const Key('downloadButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('download-all')));
    await settle(tester);
    expect(find.text('UA subs'), findsNothing, reason: 'only video sources are offered');
    await tester.tap(find.byKey(const ValueKey('download-source-1')));
    await settle(tester);
    // Asked once before the first download.
    expect(find.text('Завантаження у фоні'), findsOneWidget);
    await tester.tap(find.text('Дозволити'));
    await settle(tester);

    expect(queue().tasks.map((t) => (t.id, t.request.sourceName, t.request.itemTitle)), [
      ('alpha_m1_0', 'B', 'Episode 1'),
      ('alpha_m1_1', 'B', 'Episode 2'),
      ('alpha_m1_2', 'B', 'Episode 3'),
    ]);
    expect(queue().tasks.first.request.root, folder().path);
    expect(runner.started, ['alpha_m1_0'], reason: 'a show downloads in order, one episode at a time');
    expect(permissions.calls, ['notifications', 'battery']);
    expect(find.text('Додано до завантажень: 3'), findsOneWidget);

    final details = File(p.join(folder().path, 'alpha_m1', 'details.json'));
    expect(jsonDecode(details.readAsStringSync()), containsPair('title', 'Show'));

    // The sheet closed itself; the queue indicator is on the account avatar.
    expect(find.byKey(const ValueKey('download-source-1')), findsNothing);
    expect(find.descendant(of: find.byKey(const Key('downloadsBadge')), matching: find.text('3')), findsOneWidget);
  });

  testAppWidgets('details: a season or a single episode, with the collection subtitles', (tester) async {
    await start(
      tester,
      items: [
        episode(0, section: 'S1'),
        episode(1, section: 'S1'),
        episode(2, section: 'S2'),
      ],
    );
    await go(tester, AppRoutes.details('alpha', 'm1'));
    await tester.tap(find.byKey(const Key('downloadButton')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('download-section-1')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('download-source-0')));
    await settle(tester);
    expect(queue().tasks.map((t) => t.id), ['alpha_m1_2']);

    await tester.tap(find.byKey(const Key('downloadButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('download-pick')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mediaItem-1')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('download-source-0')));
    await settle(tester);
    expect(queue().tasks.map((t) => (t.id, t.request.sourceName)), [('alpha_m1_2', 'A'), ('alpha_m1_1', 'A')]);
  });

  testAppWidgets('details: downloaded episodes can be deleted from the episode list', (tester) async {
    await start(tester);
    putDetails('alpha', 'm1', {'title': 'Show', 'mediaType': 'video'});
    put('alpha_m1/1/B.mp4');
    put('alpha_m1/2/B.mp4');
    container.read(offlineRevisionProvider.notifier).bump();
    await go(tester, AppRoutes.details('alpha', 'm1'));

    await tester.tap(find.byKey(const Key('mediaItemsButton')));
    await settle(tester);
    expect(find.byKey(const ValueKey('deleteDownload-0')), findsNothing);
    expect(find.byKey(const ValueKey('deleteDownload-1')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('deleteDownload-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmDeleteDownload')));
    await settle(tester);
    expect(File(p.join(folder().path, 'alpha_m1', '1', 'B.mp4')).existsSync(), isFalse);
    expect(find.byKey(const ValueKey('deleteDownload-1')), findsNothing);
    expect(find.byKey(const ValueKey('deleteDownload-2')), findsOneWidget);
  });

  testAppWidgets('downloads page: queue with cancel / retry and downloaded contents with delete', (tester) async {
    await start(tester);
    final service = await container.read(downloadServiceProvider.future);
    await service.send(
      EnqueueDownloads([downloadRequest('a', 0, root: folder().path), downloadRequest('b', 0, root: folder().path)]),
    );
    // Running tasks with progress: no endless indeterminate bars.
    runner.runs['alpha_a_0']!.progress(0.1, 100);
    runner.runs['alpha_b_0']!.progress(0.2, 100);
    putDetails('alpha', 'm1', {'title': 'Show', 'mediaType': 'video'});
    put('alpha_m1/0/B.mp4', List.filled(3 * 1024 * 1024, 0));
    await go(tester, AppRoutes.downloads);

    expect(find.byKey(downloadTaskKey('alpha_a_0')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cancelDownload-alpha_a_0')));
    await tester.pumpAndSettle();
    expect(queue()['alpha_a_0']!.state, DownloadState.canceled);
    expect(find.text('0 · Скасовано'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('retryDownload-alpha_a_0')));
    await tester.pump();
    expect(queue()['alpha_a_0']!.state, DownloadState.started);
    runner.runs['alpha_a_0']!.progress(0.5, 1000);
    await tester.pumpAndSettle();
    expect(find.textContaining('50% · '), findsOneWidget);

    expect(find.text('Show'), findsOneWidget);
    expect(find.text('1 серія · 3.0 МБ · alpha'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('deleteContent-alpha_m1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmDeleteDownload')));
    await settle(tester);
    expect(Directory(p.join(folder().path, 'alpha_m1')).existsSync(), isFalse);
    expect(find.text('Тут з’являтимуться завантажені фільми, серіали та манга'), findsOneWidget);
  });

  testAppWidgets('settings: parallel downloads, folder and offline mode', (tester) async {
    final picked = Directory.systemTemp.createTempSync('picked');
    addTearDown(() => picked.deleteSync(recursive: true));
    await start(tester, picker: ({initialDirectory}) async => picked.path);
    await go(tester, AppRoutes.settings);

    final settingsList = find.descendant(of: find.byType(SettingsPage), matching: find.byType(Scrollable)).first;
    final change = find.byKey(const Key('downloadsFolderChange'));
    Future<void> reveal(Finder finder) async {
      await tester.scrollUntilVisible(finder, 100, scrollable: settingsList);
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
    }

    await reveal(change);
    await tester.tap(change);
    await tester.pumpAndSettle();
    expect(folder().path, picked.path);
    expect(container.read(appPreferencesProvider).getString(AppPreferences.offlineDownloadsDirectory), picked.path);
    expect(find.text(picked.path), findsOneWidget);
    await tester.tap(find.byKey(const Key('downloadsFolderReset')));
    await tester.pumpAndSettle();
    expect(folder().path, isNot(picked.path));

    final stepper = find.byKey(const Key('maxParallelDownloads'));
    await reveal(stepper);
    await tester.tap(find.descendant(of: stepper, matching: find.byIcon(Icons.add)));
    await tester.pumpAndSettle();
    expect(container.read(appPreferencesProvider).getInt(AppPreferences.downloadsMaxParallel), 4);
    expect(queue().maxConcurrent, 4);

    await reveal(find.byKey(const Key('offlineModeSwitch')));
    await tester.tap(find.byKey(const Key('offlineModeSwitch')));
    await tester.pumpAndSettle();
    expect(container.read(offlineModeProvider), isTrue);
  });

  testAppWidgets('offline mode: Home lists downloads, Search explains, details and player use local files', (
    tester,
  ) async {
    await start(tester, prefs: {AppPreferences.offlineMode: true, AppPreferences.downloadsBatteryPromptShown: true});
    putDetails('alpha', 'm1', {'title': 'Offline show', 'mediaType': 'video', 'description': 'Saved'});
    put('alpha_m1/2/Server%201.mp4');
    container.read(offlineRevisionProvider.notifier).bump();
    await settle(tester);

    expect(find.text('Завантажене'), findsOneWidget);
    expect(find.text('Offline show'), findsOneWidget);

    container.read(routerProvider).go(AppRoutes.search);
    await settle(tester);
    expect(find.text('Пошук недоступний в офлайн-режимі'), findsOneWidget);

    await go(tester, AppRoutes.details('alpha', 'm1'));
    expect(find.text('Offline show'), findsOneWidget);
    expect(find.byKey(const Key('downloadButton')), findsNothing);

    await go(tester, AppRoutes.video('alpha', 'm1'));
    final session = container.read(playerControllerProvider)!;
    expect(session.items.map((i) => (i.number, i.title)), [(2, 'Серія 3')]);
    expect(backend.opened.single.link, Uri.file(p.join(folder().path, 'alpha_m1', '2', 'Server%201.mp4')));
    expect(session.source!.description, 'Server 1');
  });

  testAppWidgets('online: the downloaded source is listed first and played', (tester) async {
    await start(tester);
    putDetails('alpha', 'm1', {'title': 'Show', 'mediaType': 'video'});
    put('alpha_m1/1/B.mp4');
    container.read(offlineRevisionProvider.notifier).bump();
    await go(tester, AppRoutes.video('alpha', 'm1', item: 1));

    final session = container.read(playerControllerProvider)!;
    expect(session.sources.map((s) => (isLocalSource(s), s.description)), [(true, 'B'), (false, 'A'), (false, 'B')]);
    expect(backend.opened.single.link.scheme, 'file');

    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.pumpAndSettle();
    expect(find.byType(DownloadedMark), findsOneWidget);
  });

  testAppWidgets('TV: the queue is operable with the D-pad only', (tester) async {
    await start(tester, deviceClass: DeviceClass.tv);
    final service = await container.read(downloadServiceProvider.future);
    await service.send(EnqueueDownloads([downloadRequest('a', 0, root: folder().path)]));
    runner.runs['alpha_a_0']!.progress(0.3, 100);
    await go(tester, AppRoutes.downloads);

    final focused = FocusManager.instance.primaryFocus!.context!;
    expect(focused.findAncestorWidgetOfExactType<TextButton>()?.key, const Key('cancelAllDownloads'));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus!.context!.findAncestorWidgetOfExactType<IconButton>()?.key,
      const ValueKey('cancelDownload-alpha_a_0'),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(queue()['alpha_a_0']!.state, DownloadState.canceled);
  });

  testAppWidgets('offline mode: downloaded manga pages are read from disk', (tester) async {
    await start(
      tester,
      mediaType: MediaType.manga,
      prefs: {AppPreferences.offlineMode: true, AppPreferences.downloadsBatteryPromptShown: true},
    );
    putDetails('alpha', 'm1', {'title': 'Manga', 'mediaType': 'manga'});
    put('alpha_m1/4/pages_UA/0002.png');
    put('alpha_m1/4/pages_UA/0001.png');
    container.read(offlineRevisionProvider.notifier).bump();
    unawaited(container.read(routerProvider).push(AppRoutes.manga('alpha', 'm1')));
    // Page images keep loading (and spinning) while the files are read.
    await settle(tester, animations: false);

    final reader = container.read(mangaReaderControllerProvider('alpha', 'm1'));
    expect(reader.items.map((i) => (i.number, i.title)), [(4, 'Розділ 5')]);
    expect(reader.source!.description, 'UA');
    expect(reader.pages.map(p.basename), ['0001.png', '0002.png']);
    expect(p.isAbsolute(reader.pages.first), isTrue);
  });

  testAppWidgets('Home suggests offline mode when nothing loads', (tester) async {
    final supplier = FakeSupplier('alpha', onLoadChannel: (_, _) async => throw const SocketException('offline'));
    await start(tester, supplier: supplier);
    expect(find.byKey(const Key('offlineSuggestion')), findsOneWidget);
    await tester.tap(find.text('Увімкнути офлайн-режим'));
    await settle(tester);
    expect(container.read(offlineModeProvider), isTrue);
    expect(find.text('Немає завантаженого. Вимкніть офлайн-режим, щоб переглядати каталог.'), findsOneWidget);
  });
}
