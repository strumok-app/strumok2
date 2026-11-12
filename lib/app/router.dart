import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/config.dart';
import '../core/localization.dart';
import '../features/collection/presentation/collection_page.dart';
import '../features/details/presentation/details_page.dart';
import '../features/downloads/presentation/downloads_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/manga/presentation/manga_reader_page.dart';
import '../features/player/presentation/player_page.dart';
import '../features/search/presentation/search_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/settings/presentation/suppliers_settings_page.dart';
import '../features/suppliers/data/supplier_registry.dart';
import '../features/suppliers/presentation/supplier_install_page.dart';
import '../features/updates/presentation/widgets/update_notice_listener.dart';
import 'shell/app_shell.dart';

part 'router.g.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const search = '/search';
  static const collection = '/collection';
  static const settings = '/settings';
  static const settingsSuppliers = '/settings/suppliers';
  static const downloads = '/downloads';
  static const install = '/install';

  static String details(String supplier, String id) => '/content/${_seg(supplier)}/${_seg(id)}';
  static String video(String supplier, String id, {int? item}) => '/video/${_seg(supplier)}/${_seg(id)}${_item(item)}';
  static String manga(String supplier, String id, {int? item}) => '/manga/${_seg(supplier)}/${_seg(id)}${_item(item)}';

  static String _seg(String value) => Uri.encodeComponent(value);
  static String _item(int? item) => item == null ? '' : '?item=$item';
}

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  // Startup guard (spec-01, spec-11 §11.1): no usable bundle -> install prompt; leaves it once activated.
  bool needsInstall() => !AppConfig.hasDevSupplierLib && ref.read(supplierRegistryProvider) is SupplierBundleMissing;
  final registryChanges = ValueNotifier(0);
  ref.listen(supplierRegistryProvider, (_, _) => registryChanges.value++);

  final router = GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: registryChanges,
    redirect: (context, state) {
      final atInstall = state.matchedLocation == AppRoutes.install;
      final install = needsInstall();
      if (install && !atInstall) return AppRoutes.install;
      if (!install && atInstall) return AppRoutes.home;
      return null;
    },
    errorBuilder: (context, state) => const _NotFoundPage(),
    routes: [
      GoRoute(path: AppRoutes.install, builder: (_, _) => const SupplierInstallPage()),
      ShellRoute(
        builder: (context, state, child) => UpdateNoticeListener(
          child: AppShell(location: state.uri.path, child: child),
        ),
        routes: [
          GoRoute(path: AppRoutes.home, builder: (_, _) => const HomePage()),
          GoRoute(path: AppRoutes.search, builder: (_, _) => const SearchPage()),
          GoRoute(path: AppRoutes.collection, builder: (_, _) => const CollectionPage()),
          GoRoute(
            path: '/content/:supplier/:id',
            builder: (_, state) =>
                DetailsPage(supplier: state.pathParameters['supplier']!, id: state.pathParameters['id']!),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (_, _) => const SettingsPage(),
            routes: [GoRoute(path: 'suppliers', builder: (_, _) => const SuppliersSettingsPage())],
          ),
          GoRoute(path: AppRoutes.downloads, builder: (_, _) => const DownloadsPage()),
        ],
      ),
      GoRoute(
        path: '/video/:supplier/:id',
        builder: (_, state) => PlayerPage(
          supplier: state.pathParameters['supplier']!,
          id: state.pathParameters['id']!,
          item: int.tryParse(state.uri.queryParameters['item'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/manga/:supplier/:id',
        builder: (_, state) => MangaReaderPage(
          supplier: state.pathParameters['supplier']!,
          id: state.pathParameters['id']!,
          item: int.tryParse(state.uri.queryParameters['item'] ?? ''),
        ),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  ref.onDispose(registryChanges.dispose);
  return router;
}

class _NotFoundPage extends StatelessWidget {
  const _NotFoundPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.pageNotFound, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            FilledButton(
              autofocus: true,
              onPressed: () => context.go(AppRoutes.home),
              child: Text(context.l10n.goHome),
            ),
          ],
        ),
      ),
    );
  }
}
