import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/localization.dart';
import 'router.dart';
import 'theme.dart';
import 'theme_settings.dart';

class StrumokApp extends ConsumerWidget {
  const StrumokApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final scheme = ref.watch(themeColorSchemeProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(scheme, Brightness.light),
      darkTheme: buildTheme(scheme, Brightness.dark),
      themeMode: ref.watch(themeBrightnessProvider),
      locale: ref.watch(appLocaleProvider),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      scrollBehavior: const _AppScrollBehavior(),
      shortcuts: {
        ...WidgetsApp.defaultShortcuts,
        const SingleActivator(LogicalKeyboardKey.select): const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.escape): const _BackIntent(),
      },
      actions: {...WidgetsApp.defaultActions, _BackIntent: _BackAction(router)},
      routerConfig: router,
    );
  }
}

class _BackIntent extends Intent {
  const _BackIntent();
}

/// Escape (desktop, FORCE_TV_MODE) closes the closest dismissible overlay; otherwise pops the route.
class _BackAction extends Action<_BackIntent> {
  final GoRouter router;

  _BackAction(this.router);

  @override
  void invoke(_BackIntent intent) {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext != null) {
      final dismiss = Actions.maybeFind<DismissIntent>(focusContext);
      if (dismiss != null && dismiss.isEnabled(const DismissIntent())) {
        Actions.invoke(focusContext, const DismissIntent());
        return;
      }
    }
    if (router.canPop()) router.pop();
  }
}

class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}
