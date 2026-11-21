import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'l10n/app_localizations.dart';
import 'storage/app_preferences.dart';

export 'l10n/app_localizations.dart';

part 'localization.g.dart';

extension LocalizationContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  String sourceLabel(ContentMediaItemSource source) {
    final language = switch (source.language) {
      ContentLanguage.en => l10n.languageEn,
      ContentLanguage.uk => l10n.languageUk,
      null => null,
    };
    return language == null ? source.description : l10n.sourceWithLanguage(source.description, language);
  }
}

/// UI language (spec-09 key `user_language`, language code); `uk` by default.
@Riverpod(keepAlive: true)
class AppLocale extends _$AppLocale {
  static const defaultLocale = Locale('uk');

  @override
  Locale build() {
    final saved = ref.read(appPreferencesProvider).getString(AppPreferences.userLanguage);
    return AppLocalizations.supportedLocales.where((l) => l.languageCode == saved).firstOrNull ?? defaultLocale;
  }

  Future<void> set(Locale value) async {
    state = value;
    await ref.read(appPreferencesProvider).setString(AppPreferences.userLanguage, value.languageCode);
  }
}
