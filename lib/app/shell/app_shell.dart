import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization.dart';
import '../../core/platform/device_class.dart';
import '../router.dart';
import 'account_menu.dart';

/// Below this width the shell uses a bottom navigation bar, otherwise a side rail (spec-01).
const bottomNavMaxWidth = 450.0;

const _destinations = [AppRoutes.home, AppRoutes.search, AppRoutes.collection];

class AppShell extends ConsumerStatefulWidget {
  final String location;
  final Widget child;

  const AppShell({super.key, required this.location, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _lastIndex = 0;

  int? get _currentIndex {
    final index = _destinations.indexOf(widget.location);
    return index < 0 ? null : index;
  }

  void _onDestinationSelected(int index) => context.go(_destinations[index]);

  void _onBack() {
    final router = GoRouter.of(context);
    router.canPop() ? router.pop() : router.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex;
    if (currentIndex != null) _lastIndex = currentIndex;

    final isTv = ref.watch(deviceClassProvider) == DeviceClass.tv;
    final showBack = !isTv && currentIndex == null;
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;

    final useBottomNav = MediaQuery.sizeOf(context).width < bottomNavMaxWidth;
    if (useBottomNav) {
      return Scaffold(
        backgroundColor: colors.surfaceContainer,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: showBack ? BackButton(onPressed: _onBack) : null,
          title: Text(l10n.appTitle),
          actions: const [AccountMenu(), SizedBox(width: 8)],
        ),
        body: _ContentZone(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24), bottom: Radius.circular(24)),
          child: widget.child,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _lastIndex,
          // Labels are shown as tooltips (NavigationDestination.tooltip defaults to its label).
          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
          onDestinationSelected: _onDestinationSelected,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: l10n.navHome,
            ),
            NavigationDestination(icon: const Icon(Icons.search), label: l10n.navSearch),
            NavigationDestination(
              icon: const Icon(Icons.favorite_border),
              selectedIcon: const Icon(Icons.favorite),
              label: l10n.navCollection,
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.surfaceContainer,
      body: SafeArea(
        child: Row(
          children: [
            NavigationRail(
              selectedIndex: currentIndex,
              onDestinationSelected: _onDestinationSelected,
              labelType: NavigationRailLabelType.none,
              // Fixed slot so destinations don't shift when the back button appears.
              leading: isTv
                  ? null
                  : SizedBox.square(
                      dimension: kMinInteractiveDimension,
                      child: showBack ? BackButton(onPressed: _onBack) : null,
                    ),
              trailing: const Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(padding: EdgeInsets.only(bottom: 16), child: AccountMenu()),
                ),
              ),
              destinations: [
                NavigationRailDestination(
                  icon: _RailIcon(Icons.home_outlined, tooltip: l10n.navHome),
                  selectedIcon: _RailIcon(Icons.home, tooltip: l10n.navHome),
                  label: Text(l10n.navHome),
                ),
                NavigationRailDestination(
                  icon: _RailIcon(Icons.search, tooltip: l10n.navSearch),
                  label: Text(l10n.navSearch),
                ),
                NavigationRailDestination(
                  icon: _RailIcon(Icons.favorite_border, tooltip: l10n.navCollection),
                  selectedIcon: _RailIcon(Icons.favorite, tooltip: l10n.navCollection),
                  label: Text(l10n.navCollection),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
                child: _ContentZone(borderRadius: const BorderRadius.all(Radius.circular(24)), child: widget.child),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rail icon with its (hidden) destination label as tooltip; the label still provides semantics.
class _RailIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;

  const _RailIcon(this.icon, {required this.tooltip});

  @override
  Widget build(BuildContext context) => Tooltip(message: tooltip, excludeFromSemantics: true, child: Icon(icon));
}

/// Page area on `surface`, set apart from the navigation chrome (`surfaceContainer`) by tone only.
class _ContentZone extends StatelessWidget {
  final BorderRadius borderRadius;
  final Widget child;

  const _ContentZone({required this.borderRadius, required this.child});

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: borderRadius,
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}
