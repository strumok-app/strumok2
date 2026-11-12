import 'package:flutter/material.dart';

/// Names are persisted by settings (spec-01 §Theming); keep legacy names.
enum AppColorScheme {
  olive(Color(0xFF6B7A2F)),
  crimson(Color(0xFFB0213A)),
  monochrome(Color(0xFF808080), variant: DynamicSchemeVariant.monochrome);

  final Color seed;
  final DynamicSchemeVariant variant;

  const AppColorScheme(this.seed, {this.variant = DynamicSchemeVariant.tonalSpot});

  static const defaultScheme = AppColorScheme.olive;
}

ThemeData buildTheme(AppColorScheme scheme, Brightness brightness) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: scheme.seed,
    brightness: brightness,
    dynamicSchemeVariant: scheme.variant,
  );
  return _flatTheme(colorScheme);
}

const _radius = BorderRadius.all(Radius.circular(16));
const _controlRadius = BorderRadius.all(Radius.circular(12));

/// Flat look: zones are separated by surface tones, never by dividers or shadows.
/// Borders are reserved for focus rings and outlined buttons.
ThemeData _flatTheme(ColorScheme cs) {
  final focusRing = BorderSide(color: cs.onSurface, width: 2, strokeAlign: BorderSide.strokeAlignOutside);
  WidgetStateProperty<BorderSide?> focusSide([BorderSide? otherwise]) =>
      WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.focused) ? focusRing : otherwise);
  final flatButton = ButtonStyle(
    elevation: const WidgetStatePropertyAll(0),
    shape: const WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: _controlRadius)),
    side: focusSide(),
  );

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
    // Focus on tiles is shown as a stronger background tone (tiles have no border).
    focusColor: cs.onSurface.withValues(alpha: 0.14),
    hoverColor: cs.onSurface.withValues(alpha: 0.06),
    filledButtonTheme: FilledButtonThemeData(style: flatButton),
    elevatedButtonTheme: ElevatedButtonThemeData(style: flatButton),
    textButtonTheme: TextButtonThemeData(style: flatButton),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: flatButton.copyWith(side: focusSide(BorderSide(color: cs.outlineVariant))),
    ),
    iconButtonTheme: IconButtonThemeData(style: ButtonStyle(side: focusSide())),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(side: focusSide(BorderSide(color: cs.outlineVariant))),
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
      side: WidgetStateBorderSide.resolveWith(
        (states) => states.contains(WidgetState.focused) ? focusRing : BorderSide.none,
      ),
      shape: const RoundedRectangleBorder(borderRadius: _controlRadius),
      elevation: 0,
      pressElevation: 0,
    ),
    switchTheme: SwitchThemeData(
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.focused) ? cs.onSurface : Colors.transparent,
      ),
    ),
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
