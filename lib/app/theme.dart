import 'package:flutter/material.dart';

/// Names are persisted by settings (spec-01 §Theming); keep legacy names.
enum AppColorScheme {
  olive(Color(0xFF6B7A2F)),
  // YouTube-like: vivid red accents on neutral surfaces.
  crimson(Color(0xFFE62117), variant: DynamicSchemeVariant.fidelity, neutralSurfaces: true, seedPrimary: true),
  monochrome(Color(0xFF808080), variant: DynamicSchemeVariant.monochrome),
  khaki(Color(0xFFC3B091), variant: DynamicSchemeVariant.fidelity),
  amber(Color(0xFFFFB300), variant: DynamicSchemeVariant.fidelity),
  electricViolet(Color(0xFF7C4DFF), variant: DynamicSchemeVariant.fidelity),
  cobalt(Color(0xFF1E88E5), variant: DynamicSchemeVariant.fidelity),
  neonCyan(Color(0xFF00E5FF), variant: DynamicSchemeVariant.fidelity);

  final Color seed;
  final DynamicSchemeVariant variant;
  final bool neutralSurfaces;
  // Use the seed itself as primary and error/badge color (M3 would lighten them to pastel in dark mode).
  final bool seedPrimary;

  const AppColorScheme(
    this.seed, {
    this.variant = DynamicSchemeVariant.tonalSpot,
    this.neutralSurfaces = false,
    this.seedPrimary = false,
  });

  static const defaultScheme = AppColorScheme.olive;
}

ColorScheme buildColorScheme(AppColorScheme scheme, Brightness brightness) {
  var cs = ColorScheme.fromSeed(seedColor: scheme.seed, brightness: brightness, dynamicSchemeVariant: scheme.variant);
  if (scheme.neutralSurfaces) {
    final neutral = ColorScheme.fromSeed(
      seedColor: AppColorScheme.monochrome.seed,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
    );
    cs = cs.copyWith(
      surface: neutral.surface,
      onSurface: neutral.onSurface,
      onSurfaceVariant: neutral.onSurfaceVariant,
      surfaceDim: neutral.surfaceDim,
      surfaceBright: neutral.surfaceBright,
      surfaceContainerLowest: neutral.surfaceContainerLowest,
      surfaceContainerLow: neutral.surfaceContainerLow,
      surfaceContainer: neutral.surfaceContainer,
      surfaceContainerHigh: neutral.surfaceContainerHigh,
      surfaceContainerHighest: neutral.surfaceContainerHighest,
      outline: neutral.outline,
      outlineVariant: neutral.outlineVariant,
      inverseSurface: neutral.inverseSurface,
      onInverseSurface: neutral.onInverseSurface,
      secondaryContainer: neutral.secondaryContainer,
      onSecondaryContainer: neutral.onSecondaryContainer,
    );
  }
  if (scheme.seedPrimary) {
    cs = cs.copyWith(primary: scheme.seed, onPrimary: cs.onSurface, error: scheme.seed, onError: cs.onSurface);
  }
  return cs;
}

ThemeData buildTheme(AppColorScheme scheme, Brightness brightness) => _flatTheme(buildColorScheme(scheme, brightness));

const _radius = BorderRadius.all(Radius.circular(16));
const _controlRadius = BorderRadius.all(Radius.circular(12));

/// Flat look: zones are separated by surface tones, never by dividers or shadows.
/// Borders are reserved for outlined controls; focus uses the default Material state layers.
ThemeData _flatTheme(ColorScheme cs) {
  // All buttons are pills: fully rounded left/right ends (radius = height / 2).
  const flatButton = ButtonStyle(elevation: WidgetStatePropertyAll(0), shape: WidgetStatePropertyAll(StadiumBorder()));

  return ThemeData(
    colorScheme: cs,
    useMaterial3: true,
    scaffoldBackgroundColor: cs.surface,
    canvasColor: cs.surface,
    shadowColor: Colors.transparent,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: cs.surfaceContainer,
      foregroundColor: cs.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: cs.surfaceContainer,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      indicatorColor: cs.secondaryContainer,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      indicatorColor: cs.secondaryContainer,
    ),
    cardTheme: CardThemeData(
      color: cs.surfaceContainerLow,
      elevation: 0,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: _radius),
      clipBehavior: Clip.antiAlias,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: cs.surfaceContainerHigh,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(28))),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: cs.surfaceContainerHigh,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: _controlRadius),
      backgroundColor: cs.inverseSurface,
      contentTextStyle: TextStyle(color: cs.onInverseSurface),
      actionTextColor: cs.inversePrimary,
    ),
    // Dividers are not used as separators; keep any framework-internal ones invisible.
    dividerTheme: const DividerThemeData(color: Colors.transparent, space: 16, thickness: 0),
    listTileTheme: ListTileThemeData(
      shape: const RoundedRectangleBorder(borderRadius: _controlRadius),
      selectedTileColor: cs.secondaryContainer,
      selectedColor: cs.onSecondaryContainer,
    ),
    hoverColor: cs.onSurface.withValues(alpha: 0.06),
    filledButtonTheme: const FilledButtonThemeData(style: flatButton),
    elevatedButtonTheme: const ElevatedButtonThemeData(style: flatButton),
    textButtonTheme: const TextButtonThemeData(style: flatButton),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: flatButton.copyWith(side: WidgetStatePropertyAll(BorderSide(color: cs.outlineVariant))),
    ),
    iconButtonTheme: const IconButtonThemeData(style: ButtonStyle(shape: WidgetStatePropertyAll(StadiumBorder()))),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: const WidgetStatePropertyAll(StadiumBorder()),
        side: WidgetStatePropertyAll(BorderSide(color: cs.outlineVariant)),
      ),
    ),
    // Selected tab is a tonal pill; no underline or divider.
    tabBarTheme: TabBarThemeData(
      dividerColor: Colors.transparent,
      indicatorSize: TabBarIndicatorSize.tab,
      indicator: BoxDecoration(color: cs.secondaryContainer, borderRadius: _controlRadius),
      labelColor: cs.onSecondaryContainer,
      unselectedLabelColor: cs.onSurfaceVariant,
      splashBorderRadius: _controlRadius,
      labelPadding: const EdgeInsets.symmetric(horizontal: 16),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: cs.surfaceContainerHighest,
      selectedColor: cs.secondaryContainer,
      side: BorderSide.none,
      shape: const RoundedRectangleBorder(borderRadius: _controlRadius),
      elevation: 0,
      pressElevation: 0,
    ),
    switchTheme: const SwitchThemeData(trackOutlineColor: WidgetStatePropertyAll(Colors.transparent)),
    textSelectionTheme: TextSelectionThemeData(cursorColor: cs.onSurface),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cs.surfaceContainerHighest,
      border: const OutlineInputBorder(borderRadius: _controlRadius, borderSide: BorderSide.none),
      enabledBorder: const OutlineInputBorder(borderRadius: _controlRadius, borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: _controlRadius,
        borderSide: BorderSide(color: cs.primary, width: 2),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      linearTrackColor: cs.surfaceContainerHighest,
      borderRadius: const BorderRadius.all(Radius.circular(4)),
    ),
  );
}

/// A flat zone separated from its surroundings only by its background tone.
class SurfaceZone extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  const SurfaceZone({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color});

  @override
  Widget build(BuildContext context) => Material(
    color: color ?? Theme.of(context).colorScheme.surfaceContainerLow,
    borderRadius: _radius,
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: padding, child: child),
  );
}
