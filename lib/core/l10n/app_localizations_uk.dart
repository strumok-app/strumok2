// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get commonCancel => 'Скасувати';

  @override
  String get commonClose => 'Закрити';

  @override
  String get commonSave => 'Зберегти';

  @override
  String get homeContinue => 'Продовжити';

  @override
  String get mediaTypeVideo => 'Відео';

  @override
  String get mediaTypeManga => 'Манга';

  @override
  String get collectionEmpty => 'Колекція порожня. Додавайте фільми, серіали та мангу зі сторінки деталей.';

  @override
  String get collectionSearchHint => 'Пошук у колекції';

  @override
  String get collectionStatusTitle => 'Статус';

  @override
  String get collectionPriorityTitle => 'Пріоритет';

  @override
  String get collectionFilterMediaType => 'Тип';

  @override
  String get collectionAdd => 'Додати в колекцію';

  @override
  String get collectionRemove => 'Видалити з колекції';

  @override
  String get collectionStatusNone => 'Не в колекції';

  @override
  String get collectionStatusInProgress => 'В процесі';

  @override
  String get collectionStatusLater => 'На потім';

  @override
  String get collectionStatusOnHold => 'Відкладено';

  @override
  String get collectionStatusComplete => 'Завершено';

  @override
  String get collectionPriorityLow => 'Низький';

  @override
  String get collectionPriorityNormal => 'Звичайний';

  @override
  String get collectionPriorityHigh => 'Високий';

  @override
  String collectionEpisode(int number) {
    return 'Серія $number';
  }

  @override
  String collectionChapter(int number) {
    return 'Розділ $number';
  }

  @override
  String get profilesTitle => 'Профілі';

  @override
  String get profilesPickTitle => 'Хто дивиться?';

  @override
  String get profilesAdd => 'Додати профіль';

  @override
  String get profilesEdit => 'Редагувати профіль';

  @override
  String get profilesName => 'Ім\'я профілю';

  @override
  String get profilesColor => 'Колір';

  @override
  String get profilesDelete => 'Видалити профіль';

  @override
  String profilesDeleteConfirm(String name) {
    return 'Видалити профіль «$name»? Його колекцію буде видалено з цього пристрою; дані в обліковому записі Google залишаться.';
  }

  @override
  String get profilesActive => 'Поточний профіль';

  @override
  String get profilesSwitch => 'Змінити профіль';

  @override
  String get profilesManage => 'Керувати профілями';

  @override
  String get profilesAskOnStartup => 'Питати профіль під час запуску';

  @override
  String get profilesAskOnStartupSubtitle => 'Коли профілів декілька';

  @override
  String get settingsProfilesSubtitle => 'Окремі колекції для кожного члена родини';

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
  String get accountSignInGoogle => 'Увійти через Google';

  @override
  String get accountSignInWithCode => 'Увійти за кодом';

  @override
  String get accountConnectTv => 'Підключити телевізор';

  @override
  String get accountSignOut => 'Вийти';

  @override
  String get accountSignIn => 'Увійти';

  @override
  String get accountSignInBrowser => 'Продовжіть вхід у браузері';

  @override
  String get accountSigningIn => 'Вхід…';

  @override
  String get accountSignInFailed => 'Не вдалося увійти. Перевірте з’єднання та спробуйте ще раз.';

  @override
  String get accountSignInUnavailable => 'Вхід недоступний у цій збірці застосунку';

  @override
  String accountAlreadyLinked(String name) {
    return 'Цей обліковий запис уже прив’язаний до профілю «$name».';
  }

  @override
  String get accountSwitchToProfile => 'Перейти до профілю';

  @override
  String get accountSyncHint => 'Колекція синхронізується з обліковим записом Google';

  @override
  String get pairingCodeTitle => 'Вхід за кодом';

  @override
  String get pairingCodeInstruction =>
      'На телефоні чи комп’ютері, де ви вже увійшли, відкрийте меню облікового запису → «Підключити телевізор» і введіть показаний код.';

  @override
  String get pairingCodeLabel => 'Код';

  @override
  String get pairingCodeInvalid => 'Невірний або прострочений код';

  @override
  String get connectTvTitle => 'Підключення телевізора';

  @override
  String get connectTvInstruction =>
      'На телевізорі відкрийте меню облікового запису → «Увійти за кодом» і введіть цей код.';

  @override
  String get connectTvFailed => 'Не вдалося отримати код';

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
  String appUpdateReleaseNotesTitle(String version) {
    return 'Що нового у версії $version';
  }

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
