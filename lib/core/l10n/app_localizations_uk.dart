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
  String get languageEn => 'English';

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
  String detailsSupplierUnavailable(String supplier) {
    return 'Постачальник «$supplier» недоступний';
  }

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
  String get playerNoSources => 'Немає доступних джерел відео';

  @override
  String get playerLoadFailed => 'Не вдалося завантажити відео';

  @override
  String get playerPlaybackFailed => 'Помилка відтворення';

  @override
  String get playerChangeSource => 'Змінити джерело';

  @override
  String get playerSource => 'Джерело';

  @override
  String get playerPlay => 'Відтворити';

  @override
  String get playerPause => 'Пауза';

  @override
  String get playerNext => 'Наступний';

  @override
  String get playerPrevious => 'Попередній';

  @override
  String get playerFullscreen => 'На весь екран';

  @override
  String get playerExitFullscreen => 'Вийти з повноекранного режиму';

  @override
  String get playerMute => 'Вимкнути звук';

  @override
  String get playerUnmute => 'Увімкнути звук';

  @override
  String get playerLock => 'Заблокувати керування';

  @override
  String get playerUnlock => 'Розблокувати керування';

  @override
  String playerSeekForward(int seconds) {
    return '+$seconds с';
  }

  @override
  String playerSeekBackward(int seconds) {
    return '−$seconds с';
  }

  @override
  String get playerBrightness => 'Яскравість';

  @override
  String get playerVolume => 'Гучність';

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
  String get settingsLanguageSection => 'Мова';

  @override
  String get settingsTvSection => 'Телевізор';

  @override
  String get settingsConnectTvSubtitle => 'Показати код для входу в цей обліковий запис на телевізорі';

  @override
  String get settingsLanguageHint => 'Мова інтерфейсу та рекомендованих постачальників';

  @override
  String get settingsThemeSection => 'Тема';

  @override
  String get settingsThemeLight => 'Світла';

  @override
  String get settingsThemeSystem => 'Системна';

  @override
  String get settingsThemeDark => 'Темна';

  @override
  String get settingsColorScheme => 'Кольорова схема';

  @override
  String get colorSchemeOlive => 'Олива';

  @override
  String get colorSchemeCrimson => 'Багрянець';

  @override
  String get colorSchemeMonochrome => 'Монохром';

  @override
  String get colorSchemeKhaki => 'Хакі';

  @override
  String get colorSchemeAmber => 'Бурштин';

  @override
  String get colorSchemeElectricViolet => 'Електричний фіолет';

  @override
  String get colorSchemeCobalt => 'Кобальт';

  @override
  String get colorSchemeNeonCyan => 'Неоновий ціан';

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

  @override
  String get playerSubtitles => 'Субтитри';

  @override
  String get playerSubtitlesOff => 'Вимкнено';

  @override
  String get playerSubtitlesFailed => 'Не вдалося завантажити субтитри';

  @override
  String get playerAudio => 'Аудіо';

  @override
  String get playerAuto => 'Авто';

  @override
  String playerTrack(int number) {
    return 'Доріжка $number';
  }

  @override
  String get playerSubtitleSize => 'Розмір субтитрів';

  @override
  String get playerSubtitleOffset => 'Зсув субтитрів';

  @override
  String playerSubtitleOffsetValue(String seconds) {
    return '$seconds с';
  }

  @override
  String get playerDecrease => 'Зменшити';

  @override
  String get playerIncrease => 'Збільшити';

  @override
  String get playerSettings => 'Налаштування';

  @override
  String get playerQuality => 'Якість';

  @override
  String get playerSubtitlesLoading => 'Завантаження субтитрів…';

  @override
  String get playerSpeed => 'Швидкість';

  @override
  String get playerSpeedNormal => 'Звичайна';

  @override
  String playerSpeedValue(String value) {
    return '$value×';
  }

  @override
  String get playerEqualizer => 'Еквалайзер';

  @override
  String get playerEqualizerOff => 'Вимкнено';

  @override
  String get playerEqualizerClearDialogue => 'Чіткі діалоги';

  @override
  String get playerEqualizerCinema => 'Кіно';

  @override
  String get playerEqualizerNight => 'Нічний';

  @override
  String get playerEqualizerAction => 'Бойовик';

  @override
  String get playerEqualizerCustom => 'Власний';

  @override
  String playerHertz(String value) {
    return '$value Гц';
  }

  @override
  String playerKilohertz(String value) {
    return '$value кГц';
  }

  @override
  String playerDecibels(String value) {
    return '$value дБ';
  }

  @override
  String get playerStartFrom => 'Починати з';

  @override
  String get playerStartFromRemembered => 'Місця зупинки';

  @override
  String get playerStartFromBeginning => 'Початку';

  @override
  String get playerStartFromFixed => 'Фіксованої позиції';

  @override
  String get playerFixedPosition => 'Фіксована позиція';

  @override
  String get playerOnEnd => 'Після завершення';

  @override
  String get playerOnEndNext => 'Наступний епізод';

  @override
  String get playerOnEndAgain => 'Повторити';

  @override
  String get playerOnEndNothing => 'Нічого не робити';

  @override
  String get playerShuffle => 'Випадковий порядок';

  @override
  String get playerShowSubtitles => 'Показати субтитри';

  @override
  String get playerHideSubtitles => 'Сховати субтитри';

  @override
  String get playerEqualizerMax => 'Максимум';

  @override
  String get playerPip => 'Картинка в картинці';

  @override
  String get playerExitPip => 'Повернутися до повного плеєра';

  @override
  String get playerCloseApp => 'Закрити застосунок';

  @override
  String get playerFloating => 'Плаваючий плеєр';

  @override
  String get playerFloatingDescription => 'Продовжувати перегляд у міні-плеєрі після виходу з плеєра';

  @override
  String get playerOpen => 'Відкрити плеєр';

  @override
  String get playerClose => 'Закрити плеєр';

  @override
  String get readerSettings => 'Налаштування читалки';

  @override
  String get readerModeTitle => 'Режим читання';

  @override
  String get readerModeLongStrip => 'Стрічка';

  @override
  String get readerModeVertical => 'Посторінково вертикально';

  @override
  String get readerModeLeftToRight => 'Зліва направо';

  @override
  String get readerModeRightToLeft => 'Справа наліво';

  @override
  String get readerBackground => 'Фон';

  @override
  String get readerBackgroundDark => 'Темний';

  @override
  String get readerBackgroundLight => 'Світлий';

  @override
  String get readerAutoCrop => 'Обрізати поля';

  @override
  String get readerAutoCropDescription => 'Прибирати білі та чорні поля сторінок';

  @override
  String get readerTranslation => 'Переклад';

  @override
  String get readerChangeTranslation => 'Змінити переклад';

  @override
  String get readerLoadFailed => 'Не вдалося завантажити розділ';

  @override
  String get readerNoPages => 'У цьому розділі немає сторінок';

  @override
  String readerPageFailed(int number) {
    return 'Не вдалося завантажити сторінку $number';
  }

  @override
  String readerPageCounter(int page, int total) {
    return '$page / $total';
  }

  @override
  String readerChapterEnd(String title) {
    return 'Кінець: $title';
  }

  @override
  String readerChapterStart(String title) {
    return 'Початок: $title';
  }

  @override
  String get readerNextChapter => 'Наступний розділ';

  @override
  String get readerPreviousChapter => 'Попередній розділ';

  @override
  String get commonDelete => 'Видалити';

  @override
  String get commonNotNow => 'Не зараз';

  @override
  String get commonAllow => 'Дозволити';

  @override
  String get detailsDownload => 'Завантажити';

  @override
  String get downloadsAll => 'Завантажити все';

  @override
  String get downloadsPickEpisode => 'Вибрати серію';

  @override
  String get downloadsPickChapter => 'Вибрати розділ';

  @override
  String get downloadsChooseSource => 'Джерело для завантаження';

  @override
  String get downloadsNoSources => 'Немає джерел для завантаження';

  @override
  String downloadsAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Додано до завантажень: $count',
      many: 'Додано до завантажень: $count',
      few: 'Додано до завантажень: $count',
      one: 'Додано до завантажень: $count',
    );
    return '$_temp0';
  }

  @override
  String get downloadsQueue => 'Черга';

  @override
  String get downloadsDownloaded => 'Завантажене';

  @override
  String get downloadsEmpty => 'Тут з’являтимуться завантажені фільми, серіали та манга';

  @override
  String get downloadsCancel => 'Скасувати завантаження';

  @override
  String get downloadsCancelAll => 'Скасувати все';

  @override
  String get downloadsDismiss => 'Прибрати зі списку';

  @override
  String get downloadsClearFinished => 'Очистити завершені';

  @override
  String get downloadsStateQueued => 'У черзі';

  @override
  String get downloadsStateCompleted => 'Завантажено';

  @override
  String get downloadsStateCanceled => 'Скасовано';

  @override
  String downloadsProgress(int percent, String speed) {
    return '$percent% · $speed';
  }

  @override
  String downloadsSpeed(String size) {
    return '$size/с';
  }

  @override
  String get downloadsFailureNetwork => 'Помилка мережі';

  @override
  String get downloadsFailureUnavailable => 'Джерело недоступне';

  @override
  String get downloadsFailureSourceNotFound => 'Джерело не знайдено';

  @override
  String get downloadsFailureSuppliers => 'Бібліотека постачальників недоступна';

  @override
  String get downloadsFailureInvalidMedia => 'Непідтримуваний формат відео';

  @override
  String get downloadsFailureStorage => 'Не вдалося записати файл';

  @override
  String downloadsEpisodes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count серії',
      many: '$count серій',
      few: '$count серії',
      one: '$count серія',
    );
    return '$_temp0';
  }

  @override
  String downloadsChapters(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count розділу',
      many: '$count розділів',
      few: '$count розділи',
      one: '$count розділ',
    );
    return '$_temp0';
  }

  @override
  String get downloadsDeleteContent => 'Видалити завантажене';

  @override
  String downloadsDeleteConfirm(String title) {
    return 'Видалити завантажене «$title»?';
  }

  @override
  String downloadsNotificationActive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Завантаження: $count',
      many: 'Завантаження: $count',
      few: 'Завантаження: $count',
      one: 'Завантаження: $count',
    );
    return '$_temp0';
  }

  @override
  String downloadsNotificationProgress(String name, int percent) {
    return '$name — $percent%';
  }

  @override
  String get downloadsNotificationDone => 'Завантаження завершено';

  @override
  String get downloadsBatteryTitle => 'Завантаження у фоні';

  @override
  String get downloadsBatteryMessage =>
      'Щоб завантаження не переривались, коли застосунок згорнуто, дозвольте йому працювати без обмежень батареї.';

  @override
  String sizeKilobytes(String value) {
    return '$value КБ';
  }

  @override
  String sizeMegabytes(String value) {
    return '$value МБ';
  }

  @override
  String sizeGigabytes(String value) {
    return '$value ГБ';
  }

  @override
  String get settingsDownloadsFolder => 'Тека завантажень';

  @override
  String get settingsDownloadsFolderChange => 'Змінити';

  @override
  String get settingsDownloadsFolderReset => 'Типова тека';

  @override
  String get settingsMaxDownloads => 'Одночасних завантажень';

  @override
  String get offlineMode => 'Офлайн-режим';

  @override
  String get offlineModeDescription => 'Лише завантажене; колекція синхронізується пізніше';

  @override
  String get offlineModeTurnOn => 'Увімкнути офлайн-режим';

  @override
  String get offlineModeTurnOff => 'Вимкнути офлайн-режим';

  @override
  String get homeOfflineSuggestion => 'Немає з’єднання? Перегляньте завантажене в офлайн-режимі.';

  @override
  String get homeOfflineEmpty => 'Немає завантаженого. Вимкніть офлайн-режим, щоб переглядати каталог.';

  @override
  String get searchOffline => 'Пошук недоступний в офлайн-режимі';

  @override
  String get downloadsPickSeason => 'Завантажити сезон';

  @override
  String get downloadsPickVolume => 'Завантажити том';
}
