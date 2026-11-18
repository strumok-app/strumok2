import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Page for routes inside the shell's nested navigator.
///
/// Flutter routes stop arrow-key traversal at their edge by default, which traps D-pad focus inside the
/// page. `parentScope` lets an unhandled arrow move on to the shell (nav rail / bottom bar, account menu).
/// Root-navigator routes (dialogs, side sheets, player) keep the default, so overlays still trap focus.
class ShellPage extends Page<void> {
  final Widget child;

  ShellPage({required GoRouterState state, required this.child})
    : super(
        key: state.pageKey,
        name: state.name ?? state.path,
        arguments: <String, String>{...state.pathParameters, ...state.uri.queryParameters},
        restorationId: state.pageKey.value,
      );

  @override
  Route<void> createRoute(BuildContext context) => _ShellPageRoute(this);
}

class _ShellPageRoute extends PageRoute<void> with MaterialRouteTransitionMixin<void> {
  _ShellPageRoute(ShellPage page)
    : super(settings: page, directionalTraversalEdgeBehavior: TraversalEdgeBehavior.parentScope);

  // Read from the current page so updates with the same key rebuild with the new child.
  ShellPage get _page => settings as ShellPage;

  // Own ink layer per page: on the shared shell Material, ink of a covered page (its fade-out frozen while
  // the route is offstage) would paint through the transparent page above.
  @override
  Widget buildContent(BuildContext context) => Material(type: MaterialType.transparency, child: _page.child);

  // With `parentScope` edges, arrows search the whole shell navigator; covered pages (kept alive) must not be
  // reachable. Built here because transitions rebuild whenever `isCurrent` changes.
  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => ExcludeFocusTraversal(
    excluding: !isCurrent,
    child: super.buildTransitions(context, animation, secondaryAnimation, child),
  );

  @override
  bool get maintainState => true;

  // Android predictive back: every page route's gesture detector claims the swipe when its route is current in
  // its own navigator. A shell page stays current in the nested navigator while the player, reader or a sheet
  // covers the shell on the root navigator, so it would pop first, unseen. Only take the gesture when the shell
  // itself is current; otherwise the covering route handles back.
  @override
  bool get popGestureEnabled {
    final shellContext = navigator?.context;
    final shellIsCurrent = shellContext == null || (ModalRoute.isCurrentOf(shellContext) ?? true);
    return shellIsCurrent && super.popGestureEnabled;
  }

  @override
  String get debugLabel => '${super.debugLabel}(${_page.name})';
}
