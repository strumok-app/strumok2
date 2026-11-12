import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'l10n/app_localizations.dart';

export 'l10n/app_localizations.dart';

part 'localization.g.dart';

extension LocalizationContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// UI language: `uk` by default; becomes user-selectable with the language setting (spec-09).
@Riverpod(keepAlive: true)
Locale appLocale(Ref ref) => const Locale('uk');
