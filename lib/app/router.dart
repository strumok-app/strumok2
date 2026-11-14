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
import '../features/profiles/presentation/manage_profiles_page.dart';
import '../features/profiles/presentation/profile_picker_page.dart';
import '../features/profiles/presentation/profiles_providers.dart';
import '../features/search/presentation/search_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/settings/presentation/suppliers_settings_page.dart';
import '../features/suppliers/data/supplier_registry.dart';
import '../features/suppliers/presentation/supplier_install_page.dart';
import '../features/updates/presentation/widgets/update_notice_listener.dart';
import 'shell/app_shell.dart';
import 'shell/shell_page.dart';

part 'router.g.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const search = '/search';
  static const collection = '/collection';
  static const settings = '/settings';
  static const settingsSuppliers = '/settings/suppliers';
  static const settingsProfiles = '/settings/profiles';
  static const profiles = '/profiles';
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
  ref.listen(profilePickPendingProvider, (_, _) => registryChanges.value++);

  final router = GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: registryChanges,
    redirect: (context, state) {
      final atInstall = state.matchedLocation == AppRoutes.install;
      final install = needsInstall();
      if (install && !atInstall) return AppRoutes.install;
      if (!install && atInstall) return AppRoutes.home;
      // Profile picker once per app run when there are several profiles (spec-05 §5.4).
      if (!install && ref.read(profilePickPendingProvider) && state.matchedLocation != AppRoutes.profiles) {
        return AppRoutes.profiles;
      }
      return null;
    },
    errorBuilder: (context, state) => const _NotFoundPage(),
    routes: [
      GoRoute(path: AppRoutes.install, builder: (_, _) => const SupplierInstallPage()),
      GoRoute(path: AppRoutes.profiles, builder: (_, _) => const ProfilePickerPage()),
      ShellRoute(
        builder: (context, state, child) => UpdateNoticeListener(
          child: AppShell(location: state.uri.path, child: child),
        ),
        routes: [
          _shellRoute(AppRoutes.home, (_) => const HomePage()),
          _shellRoute(AppRoutes.search, (_) => const SearchPage()),
          _shellRoute(AppRoutes.collection, (_) => const CollectionPage()),
          _shellRoute(
            '/content/:supplier/:id',
            (state) => DetailsPage(supplier: state.pathParameters['supplier']!, id: state.pathParameters['id']!),
          ),
          _shellRoute(
            AppRoutes.settings,
            (_) => const SettingsPage(),
            routes: [
              _shellRoute('suppliers', (_) => const SuppliersSettingsPage()),
              _shellRoute('profiles', (_) => const ManageProfilesPage()),
            ],
          ),
          _shellRoute(AppRoutes.downloads, (_) => const DownloadsPage()),
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

/// Route inside the shell; its page lets D-pad focus leave the page for the navigation (see [ShellPage]).
GoRoute _shellRoute(String path, Widget Function(GoRouterState state) builder, {List<RouteBase> routes = const []}) =>
    GoRoute(
      path: path,
      pageBuilder: (_, state) => ShellPage(state: state, child: builder(state)),
      routes: routes,
    );

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
