// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get commonRetry => 'Повторити';

  @override
  String get errorLoading => 'Не вдалося завантажити';

  @override
  String get rowEmpty => 'Тут поки нічого немає';

  @override
  String get rowLoadMore => 'Завантажити ще';

  @override
  String get homeEmpty => 'Оберіть постачальників і канали рекомендацій у налаштуваннях';

  @override
  String get homeConfigure => 'Налаштувати';

  @override
  String get searchHint => 'Пошук фільмів, серіалів, аніме, манги';

  @override
  String get searchClear => 'Очистити';

  @override
  String get searchFilters => 'Фільтри';

  @override
  String get searchFilterLanguages => 'Мови';

  @override
  String get searchFilterTypes => 'Типи';

  @override
  String get searchFilterSuppliers => 'Постачальники';

  @override
  String get searchEnterQuery => 'Введіть назву для пошуку';

  @override
  String get searchNoSuppliers => 'Жоден постачальник не відповідає вибраним фільтрам';

  @override
  String get searchNothingFound => 'Нічого не знайдено';

  @override
  String get searchRemoveFromHistory => 'Видалити з історії';

  @override
  String get contentTypeMovie => 'Фільми';

  @override
  String get contentTypeAnime => 'Аніме';

  @override
  String get contentTypeCartoon => 'Мультфільми';

  @override
  String get contentTypeSeries => 'Серіали';

  @override
  String get contentTypeManga => 'Манга';

  @override
  String get languageUk => 'Українська';

  @override
  String get languageEn => 'Англійська';

  @override
  String get languageJa => 'Японська';

  @override
  String get detailsWatch => 'Дивитися';

  @override
  String get detailsRead => 'Читати';

  @override
  String get detailsMore => 'Більше';

  @override
  String get detailsLess => 'Менше';

  @override
  String get detailsEpisodes => 'Епізоди';

  @override
  String get detailsChapters => 'Розділи';

  @override
  String get detailsSimilar => 'Схоже';

  @override
  String get detailsNotFound => 'Контент не знайдено';

  @override
  String get appTitle => 'Струмок';

  @override
  String get navHome => 'Головна';

  @override
  String get navSearch => 'Пошук';

  @override
  String get navCollection => 'Колекція';

  @override
  String get navSettings => 'Налаштування';

  @override
  String get navDownloads => 'Завантаження';

  @override
  String get accountMenuTooltip => 'Обліковий запис';

  @override
  String get accountNotSignedIn => 'Ви не увійшли';

  @override
  String get detailsTitle => 'Деталі';

  @override
  String get playerTitle => 'Плеєр';

  @override
  String get readerTitle => 'Читалка';

  @override
  String get settingsSuppliers => 'Постачальники';

  @override
  String get pageNotImplemented => 'Ця сторінка ще в розробці';

  @override
  String get pageNotFound => 'Сторінку не знайдено';

  @override
  String get goHome => 'На головну';

  @override
  String get settingsAppVersionSection => 'Версія застосунку';

  @override
  String get settingsSuppliersBundleSection => 'Бібліотека постачальників';

  @override
  String get settingsSuppliersSubtitle => 'Порядок, увімкнення та канали рекомендацій';

  @override
  String updatesCurrentVersion(String version) {
    return 'Поточна версія: $version';
  }

  @override
  String updatesLatestVersion(String version) {
    return 'Остання версія: $version';
  }

  @override
  String updatesInstalledVersion(String version) {
    return 'Встановлена версія: $version';
  }

  @override
  String get updatesNotInstalled => 'Не встановлено';

  @override
  String get updatesDevLibrary => 'Локальна бібліотека розробника';

  @override
  String get updatesCheck => 'Перевірити оновлення';

  @override
  String get updatesUpToDate => 'Встановлено останню версію';

  @override
  String get updatesUpdate => 'Оновити';

  @override
  String get updatesInstall => 'Встановити';

  @override
  String get updatesCancel => 'Скасувати';

  @override
  String get updatesRetry => 'Повторити';

  @override
  String get updatesDownloading => 'Завантаження…';

  @override
  String updatesProgress(int percent) {
    return 'Завантаження: $percent%';
  }

  @override
  String get updatesCheckFailed => 'Не вдалося перевірити оновлення';

  @override
  String get updatesNotConfigured => 'Адресу перевірки оновлень не налаштовано';

  @override
  String appUpdateAvailable(String version) {
    return 'Доступна нова версія $version';
  }

  @override
  String get appUpdateFailed => 'Не вдалося оновити застосунок';

  @override
  String get appUpdateNoAsset => 'Для цієї платформи немає файлу оновлення';

  @override
  String get appUpdateOpenDownload => 'Відкрити сторінку завантаження';

  @override
  String get appUpdateReleaseNotes => 'Що нового';

  @override
  String suppliersBundleUpdateAvailable(String version) {
    return 'Доступна нова бібліотека постачальників $version';
  }

  @override
  String suppliersBundleAppUpdateRequired(String version) {
    return 'Бібліотека постачальників $version потребує оновлення застосунку';
  }

  @override
  String get suppliersBundleInstallFailed => 'Не вдалося встановити бібліотеку постачальників';

  @override
  String get suppliersBundleInstallTitle => 'Потрібна бібліотека постачальників';

  @override
  String get suppliersBundleInstallMessage =>
      'Щоб переглядати фільми, серіали, аніме та мангу, встановіть бібліотеку постачальників контенту.';

  @override
  String get suppliersEmpty => 'Немає доступних постачальників';

  @override
  String get suppliersEnabled => 'Увімкнено';

  @override
  String get suppliersMoveUp => 'Перемістити вгору';

  @override
  String get suppliersMoveDown => 'Перемістити вниз';

  @override
  String get suppliersChannels => 'Канали рекомендацій';
}
