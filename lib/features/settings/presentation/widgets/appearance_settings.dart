import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../app/theme_settings.dart';
import '../../../../core/localization.dart';

class LanguageSettingsSection extends ConsumerWidget {
  static const locales = [Locale('uk'), Locale('en')];

  const LanguageSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(appLocaleProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.settingsLanguageHint, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 12),
        SegmentedButton<Locale>(
          segments: [
            for (final l in locales)
              ButtonSegment(value: l, label: Text(l.languageCode == 'uk' ? l10n.languageUk : l10n.languageEn)),
          ],
          selected: {locale},
          onSelectionChanged: (s) => ref.read(appLocaleProvider.notifier).set(s.single),
        ),
      ],
    );
  }
}

class ThemeSettingsSection extends ConsumerWidget {
  const ThemeSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final mode = ref.watch(themeBrightnessProvider);
    final scheme = ref.watch(themeColorSchemeProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<ThemeMode>(
          segments: [
            ButtonSegment(
              value: ThemeMode.light,
              icon: const Icon(Icons.light_mode_outlined),
              label: Text(l10n.settingsThemeLight),
            ),
            ButtonSegment(
              value: ThemeMode.system,
              icon: const Icon(Icons.brightness_auto_outlined),
              label: Text(l10n.settingsThemeSystem),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              icon: const Icon(Icons.dark_mode_outlined),
              label: Text(l10n.settingsThemeDark),
            ),
          ],
          showSelectedIcon: false,
          selected: {mode},
          onSelectionChanged: (s) => ref.read(themeBrightnessProvider.notifier).set(s.single),
        ),
        const SizedBox(height: 16),
        Text(l10n.settingsColorScheme, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final s in AppColorScheme.values)
              _SchemeSwatch(
                key: ValueKey(s),
                scheme: s,
                selected: s == scheme,
                onTap: () => ref.read(themeColorSchemeProvider.notifier).set(s),
              ),
          ],
        ),
      ],
    );
  }
}

String colorSchemeName(AppLocalizations l10n, AppColorScheme scheme) => switch (scheme) {
  AppColorScheme.olive => l10n.colorSchemeOlive,
  AppColorScheme.crimson => l10n.colorSchemeCrimson,
  AppColorScheme.monochrome => l10n.colorSchemeMonochrome,
  AppColorScheme.khaki => l10n.colorSchemeKhaki,
  AppColorScheme.amber => l10n.colorSchemeAmber,
  AppColorScheme.electricViolet => l10n.colorSchemeElectricViolet,
  AppColorScheme.cobalt => l10n.colorSchemeCobalt,
  AppColorScheme.neonCyan => l10n.colorSchemeNeonCyan,
};

class _SchemeSwatch extends StatelessWidget {
  final AppColorScheme scheme;
  final bool selected;
  final VoidCallback onTap;

  const _SchemeSwatch({super.key, required this.scheme, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final seed = scheme.seed;
    final checkColor = ThemeData.estimateBrightnessForColor(seed) == Brightness.dark ? Colors.white : Colors.black;
    final labelStyle = theme.textTheme.labelMedium;
    return Semantics(
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        child: SizedBox(
          width: 88,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: seed),
                  child: selected ? Icon(Icons.check, color: checkColor) : null,
                ),
                const SizedBox(height: 8),
                Text(
                  colorSchemeName(context.l10n, scheme),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: selected ? labelStyle?.copyWith(color: cs.primary, fontWeight: FontWeight.bold) : labelStyle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
