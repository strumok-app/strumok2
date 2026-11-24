import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_uk.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en'), Locale('uk')];

  /// Dialog cancel button
  ///
  /// In uk, this message translates to:
  /// **'Скасувати'**
  String get commonCancel;

  /// Dialog close button
  ///
  /// In uk, this message translates to:
  /// **'Закрити'**
  String get commonClose;

  /// Dialog save button
  ///
  /// In uk, this message translates to:
  /// **'Зберегти'**
  String get commonSave;

  /// Home row with in-progress (or watch later) collection items
  ///
  /// In uk, this message translates to:
  /// **'Продовжити'**
  String get homeContinue;

  /// Media type filter: video
  ///
  /// In uk, this message translates to:
  /// **'Відео'**
  String get mediaTypeVideo;

  /// Media type filter: manga
  ///
  /// In uk, this message translates to:
  /// **'Манга'**
  String get mediaTypeManga;

  /// Collection page: no items at all
  ///
  /// In uk, this message translates to:
  /// **'Колекція порожня. Додавайте фільми, серіали та мангу зі сторінки деталей.'**
  String get collectionEmpty;

  /// Collection title search hint
  ///
  /// In uk, this message translates to:
  /// **'Пошук у колекції'**
  String get collectionSearchHint;

  /// Collection status selector / filter title
  ///
  /// In uk, this message translates to:
  /// **'Статус'**
  String get collectionStatusTitle;

  /// Collection priority selector title
  ///
  /// In uk, this message translates to:
  /// **'Пріоритет'**
  String get collectionPriorityTitle;

  /// Collection filter group: video or manga
  ///
  /// In uk, this message translates to:
  /// **'Тип'**
  String get collectionFilterMediaType;

  /// Details: item is not in the collection yet
  ///
  /// In uk, this message translates to:
  /// **'Додати в колекцію'**
  String get collectionAdd;

  /// Removes the item from the collection
  ///
  /// In uk, this message translates to:
  /// **'Видалити з колекції'**
  String get collectionRemove;

  /// Collection status: none
  ///
  /// In uk, this message translates to:
  /// **'Не в колекції'**
  String get collectionStatusNone;

  /// Collection status: watching/reading now
  ///
  /// In uk, this message translates to:
  /// **'В процесі'**
  String get collectionStatusInProgress;

  /// Collection status: watch/read later (legacy value 'latter')
  ///
  /// In uk, this message translates to:
  /// **'На потім'**
  String get collectionStatusLater;

  /// Collection status: on hold
  ///
  /// In uk, this message translates to:
  /// **'Відкладено'**
  String get collectionStatusOnHold;

  /// Collection status: completed
  ///
  /// In uk, this message translates to:
  /// **'Завершено'**
  String get collectionStatusComplete;

  /// Collection priority
  ///
  /// In uk, this message translates to:
  /// **'Низький'**
  String get collectionPriorityLow;

  /// Collection priority
  ///
  /// In uk, this message translates to:
  /// **'Звичайний'**
  String get collectionPriorityNormal;

  /// Collection priority
  ///
  /// In uk, this message translates to:
  /// **'Високий'**
  String get collectionPriorityHigh;

  /// Current episode on a collection card
  ///
  /// In uk, this message translates to:
  /// **'Серія {number}'**
  String collectionEpisode(int number);

  /// Current chapter on a collection card
  ///
  /// In uk, this message translates to:
  /// **'Розділ {number}'**
  String collectionChapter(int number);

  /// Manage profiles page title / settings entry
  ///
  /// In uk, this message translates to:
  /// **'Профілі'**
  String get profilesTitle;

  /// Profile picker title
  ///
  /// In uk, this message translates to:
  /// **'Хто дивиться?'**
  String get profilesPickTitle;

  /// Creates a new profile
  ///
  /// In uk, this message translates to:
  /// **'Додати профіль'**
  String get profilesAdd;

  /// Profile edit dialog title
  ///
  /// In uk, this message translates to:
  /// **'Редагувати профіль'**
  String get profilesEdit;

  /// Profile name field hint
  ///
  /// In uk, this message translates to:
  /// **'Ім\'я профілю'**
  String get profilesName;

  /// Profile avatar color
  ///
  /// In uk, this message translates to:
  /// **'Колір'**
  String get profilesColor;

  /// Deletes a profile
  ///
  /// In uk, this message translates to:
  /// **'Видалити профіль'**
  String get profilesDelete;

  /// Delete profile confirmation
  ///
  /// In uk, this message translates to:
  /// **'Видалити профіль «{name}»? Його колекцію буде видалено з цього пристрою; дані в обліковому записі Google залишаться.'**
  String profilesDeleteConfirm(String name);

  /// Marks the active profile
  ///
  /// In uk, this message translates to:
  /// **'Поточний профіль'**
  String get profilesActive;

  /// Opens the profile picker
  ///
  /// In uk, this message translates to:
  /// **'Змінити профіль'**
  String get profilesSwitch;

  /// Opens profile management
  ///
  /// In uk, this message translates to:
  /// **'Керувати профілями'**
  String get profilesManage;

  /// Setting: show the profile picker on startup
  ///
  /// In uk, this message translates to:
  /// **'Питати профіль під час запуску'**
  String get profilesAskOnStartup;

  /// Setting subtitle
  ///
  /// In uk, this message translates to:
  /// **'Коли профілів декілька'**
  String get profilesAskOnStartupSubtitle;

  /// Settings entry subtitle for profiles
  ///
  /// In uk, this message translates to:
  /// **'Окремі колекції для кожного члена родини'**
  String get settingsProfilesSubtitle;

  /// Generic retry button after a loading error
  ///
  /// In uk, this message translates to:
  /// **'Повторити'**
  String get commonRetry;

  /// Generic loading error
  ///
  /// In uk, this message translates to:
  /// **'Не вдалося завантажити'**
  String get errorLoading;

  /// A content row returned no items
  ///
  /// In uk, this message translates to:
  /// **'Тут поки нічого немає'**
  String get rowEmpty;

  /// TV: tile at the end of a row that loads the next page
  ///
  /// In uk, this message translates to:
  /// **'Завантажити ще'**
  String get rowLoadMore;

  /// Content row header button: reload the row from its first page
  ///
  /// In uk, this message translates to:
  /// **'Оновити'**
  String get rowReload;

  /// Content row header button and dialog title: pick a random item of the row
  ///
  /// In uk, this message translates to:
  /// **'Випадковий вибір'**
  String get rowPickRandom;

  /// Random pick dialog: pick another random item
  ///
  /// In uk, this message translates to:
  /// **'Інший'**
  String get randomPickAnother;

  /// Random pick dialog: open details of the picked item
  ///
  /// In uk, this message translates to:
  /// **'Відкрити'**
  String get randomPickOpen;

  /// Random pick dialog: the row has no items
  ///
  /// In uk, this message translates to:
  /// **'Немає з чого обирати'**
  String get randomPickEmpty;

  /// Home: no recommendation channels are enabled
  ///
  /// In uk, this message translates to:
  /// **'Оберіть постачальників і канали рекомендацій у налаштуваннях'**
  String get homeEmpty;

  /// Home: opens supplier/recommendation settings
  ///
  /// In uk, this message translates to:
  /// **'Налаштувати'**
  String get homeConfigure;

  /// Search field hint
  ///
  /// In uk, this message translates to:
  /// **'Пошук фільмів, серіалів, аніме, манги'**
  String get searchHint;

  /// Clears the search field
  ///
  /// In uk, this message translates to:
  /// **'Очистити'**
  String get searchClear;

  /// Search filters button and dialog title
  ///
  /// In uk, this message translates to:
  /// **'Фільтри'**
  String get searchFilters;

  /// Search filter group: content languages
  ///
  /// In uk, this message translates to:
  /// **'Мови'**
  String get searchFilterLanguages;

  /// Search filter group: content types
  ///
  /// In uk, this message translates to:
  /// **'Типи'**
  String get searchFilterTypes;

  /// Search filter group: suppliers
  ///
  /// In uk, this message translates to:
  /// **'Постачальники'**
  String get searchFilterSuppliers;

  /// Search: nothing submitted yet
  ///
  /// In uk, this message translates to:
  /// **'Введіть назву для пошуку'**
  String get searchEnterQuery;

  /// Search: filters exclude every supplier
  ///
  /// In uk, this message translates to:
  /// **'Жоден постачальник не відповідає вибраним фільтрам'**
  String get searchNoSuppliers;

  /// Search: all suppliers returned no results
  ///
  /// In uk, this message translates to:
  /// **'Нічого не знайдено'**
  String get searchNothingFound;

  /// Removes a query from search history
  ///
  /// In uk, this message translates to:
  /// **'Видалити з історії'**
  String get searchRemoveFromHistory;

  /// Content type
  ///
  /// In uk, this message translates to:
  /// **'Фільми'**
  String get contentTypeMovie;

  /// Content type
  ///
  /// In uk, this message translates to:
  /// **'Аніме'**
  String get contentTypeAnime;

  /// Content type
  ///
  /// In uk, this message translates to:
  /// **'Мультфільми'**
  String get contentTypeCartoon;

  /// Content type
  ///
  /// In uk, this message translates to:
  /// **'Серіали'**
  String get contentTypeSeries;

  /// Content type
  ///
  /// In uk, this message translates to:
  /// **'Манга'**
  String get contentTypeManga;

  /// Ukrainian language name, always in Ukrainian
  ///
  /// In uk, this message translates to:
  /// **'Українська'**
  String get languageUk;

  /// English language name, always in English
  ///
  /// In uk, this message translates to:
  /// **'English'**
  String get languageEn;

  /// Details: primary action for video
  ///
  /// In uk, this message translates to:
  /// **'Дивитися'**
  String get detailsWatch;

  /// Details: primary action for manga
  ///
  /// In uk, this message translates to:
  /// **'Читати'**
  String get detailsRead;

  /// Expands a collapsed description
  ///
  /// In uk, this message translates to:
  /// **'Більше'**
  String get detailsMore;

  /// Collapses an expanded description
  ///
  /// In uk, this message translates to:
  /// **'Менше'**
  String get detailsLess;

  /// Details: video media items section
  ///
  /// In uk, this message translates to:
  /// **'Епізоди'**
  String get detailsEpisodes;

  /// Details: manga media items section
  ///
  /// In uk, this message translates to:
  /// **'Розділи'**
  String get detailsChapters;

  /// Details: video media items failed to load; shown instead of Watch with a Retry button
  ///
  /// In uk, this message translates to:
  /// **'Не вдалося завантажити епізоди'**
  String get detailsEpisodesLoadError;

  /// Details: manga media items failed to load; shown instead of Read with a Retry button
  ///
  /// In uk, this message translates to:
  /// **'Не вдалося завантажити розділи'**
  String get detailsChaptersLoadError;

  /// Details: similar content row
  ///
  /// In uk, this message translates to:
  /// **'Схоже'**
  String get detailsSimilar;

  /// Details: supplier returned no content for this id
  ///
  /// In uk, this message translates to:
  /// **'Контент не знайдено'**
  String get detailsNotFound;

  /// Details: the content's supplier is not in the installed suppliers library
  ///
  /// In uk, this message translates to:
  /// **'Постачальник «{supplier}» недоступний'**
  String detailsSupplierUnavailable(String supplier);

  /// Application name
  ///
  /// In uk, this message translates to:
  /// **'Струмок'**
  String get appTitle;

  /// Main navigation: Home page
  ///
  /// In uk, this message translates to:
  /// **'Головна'**
  String get navHome;

  /// Main navigation: Search page
  ///
  /// In uk, this message translates to:
  /// **'Пошук'**
  String get navSearch;

  /// Main navigation: user's collection (library) page
  ///
  /// In uk, this message translates to:
  /// **'Колекція'**
  String get navCollection;

  /// Settings page title and account menu entry
  ///
  /// In uk, this message translates to:
  /// **'Налаштування'**
  String get navSettings;

  /// Downloads (offline items) page title and account menu entry
  ///
  /// In uk, this message translates to:
  /// **'Завантаження'**
  String get navDownloads;

  /// Tooltip of the account (avatar) menu button
  ///
  /// In uk, this message translates to:
  /// **'Обліковий запис'**
  String get accountMenuTooltip;

  /// Account menu header when no user is signed in
  ///
  /// In uk, this message translates to:
  /// **'Ви не увійшли'**
  String get accountNotSignedIn;

  /// Account menu: start Google sign-in
  ///
  /// In uk, this message translates to:
  /// **'Увійти через Google'**
  String get accountSignInGoogle;

  /// Account menu: sign in with a pairing code generated on another device
  ///
  /// In uk, this message translates to:
  /// **'Увійти за кодом'**
  String get accountSignInWithCode;

  /// Account menu: generate a pairing code for a TV
  ///
  /// In uk, this message translates to:
  /// **'Підключити телевізор'**
  String get accountConnectTv;

  /// Account menu: sign out of the Google account
  ///
  /// In uk, this message translates to:
  /// **'Вийти'**
  String get accountSignOut;

  /// Manage profiles: sign the profile in
  ///
  /// In uk, this message translates to:
  /// **'Увійти'**
  String get accountSignIn;

  /// Shown while desktop Google consent is open in the browser
  ///
  /// In uk, this message translates to:
  /// **'Продовжіть вхід у браузері'**
  String get accountSignInBrowser;

  /// Progress while signing in
  ///
  /// In uk, this message translates to:
  /// **'Вхід…'**
  String get accountSigningIn;

  /// Sign-in failed (network/server)
  ///
  /// In uk, this message translates to:
  /// **'Не вдалося увійти. Перевірте з’єднання та спробуйте ще раз.'**
  String get accountSignInFailed;

  /// Accounts are not configured in this build
  ///
  /// In uk, this message translates to:
  /// **'Вхід недоступний у цій збірці застосунку'**
  String get accountSignInUnavailable;

  /// Two profiles cannot use the same Google account
  ///
  /// In uk, this message translates to:
  /// **'Цей обліковий запис уже прив’язаний до профілю «{name}».'**
  String accountAlreadyLinked(String name);

  /// Action: switch to the profile that already uses the account
  ///
  /// In uk, this message translates to:
  /// **'Перейти до профілю'**
  String get accountSwitchToProfile;

  /// Subtitle under a signed-in profile
  ///
  /// In uk, this message translates to:
  /// **'Колекція синхронізується з обліковим записом Google'**
  String get accountSyncHint;

  /// Pairing code entry dialog title
  ///
  /// In uk, this message translates to:
  /// **'Вхід за кодом'**
  String get pairingCodeTitle;

  /// Pairing code entry instructions
  ///
  /// In uk, this message translates to:
  /// **'На телефоні чи комп’ютері, де ви вже увійшли, відкрийте меню облікового запису → «Підключити телевізор» і введіть показаний код.'**
  String get pairingCodeInstruction;

  /// Pairing code text field label
  ///
  /// In uk, this message translates to:
  /// **'Код'**
  String get pairingCodeLabel;

  /// Pairing code was rejected
  ///
  /// In uk, this message translates to:
  /// **'Невірний або прострочений код'**
  String get pairingCodeInvalid;

  /// Connect TV dialog title
  ///
  /// In uk, this message translates to:
  /// **'Підключення телевізора'**
  String get connectTvTitle;

  /// Connect TV dialog instructions
  ///
  /// In uk, this message translates to:
  /// **'На телевізорі відкрийте меню облікового запису → «Увійти за кодом» і введіть цей код.'**
  String get connectTvInstruction;

  /// Generating the pairing code failed
  ///
  /// In uk, this message translates to:
  /// **'Не вдалося отримати код'**
  String get connectTvFailed;

  /// Content details page title
  ///
  /// In uk, this message translates to:
  /// **'Деталі'**
  String get detailsTitle;

  /// Video player page title
  ///
  /// In uk, this message translates to:
  /// **'Плеєр'**
  String get playerTitle;

  /// Manga reader page title
  ///
  /// In uk, this message translates to:
  /// **'Читалка'**
  String get readerTitle;

  /// Player error: the item has no video sources
  ///
  /// In uk, this message translates to:
  /// **'Немає доступних джерел відео'**
  String get playerNoSources;

  /// Player error: loading items, sources or the link failed
  ///
  /// In uk, this message translates to:
  /// **'Не вдалося завантажити відео'**
  String get playerLoadFailed;

  /// Player error: playback stopped with an error
  ///
  /// In uk, this message translates to:
  /// **'Помилка відтворення'**
  String get playerPlaybackFailed;

  /// Player error action: pick another source
  ///
  /// In uk, this message translates to:
  /// **'Змінити джерело'**
  String get playerChangeSource;

  /// Player source (server) selector
  ///
  /// In uk, this message translates to:
  /// **'Джерело'**
  String get playerSource;

  /// Player play button
  ///
  /// In uk, this message translates to:
  /// **'Відтворити'**
  String get playerPlay;

  /// Player pause button
  ///
  /// In uk, this message translates to:
  /// **'Пауза'**
  String get playerPause;

  /// Player next item button
  ///
  /// In uk, this message translates to:
  /// **'Наступний'**
  String get playerNext;

  /// Player previous item button
  ///
  /// In uk, this message translates to:
  /// **'Попередній'**
  String get playerPrevious;

  /// Player enter full screen button
  ///
  /// In uk, this message translates to:
  /// **'На весь екран'**
  String get playerFullscreen;

  /// Player exit full screen button
  ///
  /// In uk, this message translates to:
  /// **'Вийти з повноекранного режиму'**
  String get playerExitFullscreen;

  /// Player mute button
  ///
  /// In uk, this message translates to:
  /// **'Вимкнути звук'**
  String get playerMute;

  /// Player unmute button
  ///
  /// In uk, this message translates to:
  /// **'Увімкнути звук'**
  String get playerUnmute;

  /// Desktop player button tooltip with its keyboard shortcut, e.g. Next (])
  ///
  /// In uk, this message translates to:
  /// **'{label} ({key})'**
  String playerShortcutHint(String label, String key);

  /// Desktop player: keyboard shortcuts overlay title
  ///
  /// In uk, this message translates to:
  /// **'Гарячі клавіші'**
  String get playerShortcutsTitle;

  /// Desktop player: keyboard shortcuts overlay dismiss hint
  ///
  /// In uk, this message translates to:
  /// **'Натисніть будь-яку клавішу або клацніть, щоб закрити'**
  String get playerShortcutsClose;

  /// Desktop player shortcut: play or pause
  ///
  /// In uk, this message translates to:
  /// **'Відтворення / пауза'**
  String get playerShortcutPlayPause;

  /// Desktop player shortcut: seek backward / forward
  ///
  /// In uk, this message translates to:
  /// **'Перемотати назад / вперед на {seconds} с'**
  String playerShortcutSeek(int seconds);

  /// Desktop player shortcut: frame step
  ///
  /// In uk, this message translates to:
  /// **'Попередній / наступний кадр'**
  String get playerShortcutFrameStep;

  /// Desktop player shortcut: volume
  ///
  /// In uk, this message translates to:
  /// **'Гучніше / тихіше (або колесо миші)'**
  String get playerShortcutVolume;

  /// Desktop player shortcut: toggle mute
  ///
  /// In uk, this message translates to:
  /// **'Вимкнути / увімкнути звук'**
  String get playerShortcutMute;

  /// Desktop player shortcut: previous or next item
  ///
  /// In uk, this message translates to:
  /// **'Попередній / наступний епізод'**
  String get playerShortcutPreviousNext;

  /// Desktop player shortcut: toggle subtitles
  ///
  /// In uk, this message translates to:
  /// **'Показати / сховати субтитри'**
  String get playerShortcutSubtitles;

  /// Desktop player shortcut: open the shortcuts overlay
  ///
  /// In uk, this message translates to:
  /// **'Показати цей список'**
  String get playerShortcutHelp;

  /// Desktop player: tooltip for the top-bar button that opens the keyboard shortcuts overlay
  ///
  /// In uk, this message translates to:
  /// **'Гарячі клавіші'**
  String get playerKeybindings;

  /// Mobile player: lock controls and gestures
  ///
  /// In uk, this message translates to:
  /// **'Заблокувати керування'**
  String get playerLock;

  /// Mobile player: unlock controls
  ///
  /// In uk, this message translates to:
  /// **'Розблокувати керування'**
  String get playerUnlock;

  /// Double-tap seek indicator, forward
  ///
  /// In uk, this message translates to:
  /// **'+{seconds} с'**
  String playerSeekForward(int seconds);

  /// Double-tap seek indicator, backward
  ///
  /// In uk, this message translates to:
  /// **'−{seconds} с'**
  String playerSeekBackward(int seconds);

  /// Brightness gesture indicator
  ///
  /// In uk, this message translates to:
  /// **'Яскравість'**
  String get playerBrightness;

  /// Volume gesture indicator
  ///
  /// In uk, this message translates to:
  /// **'Гучність'**
  String get playerVolume;

  /// Settings sub-page: content suppliers
  ///
  /// In uk, this message translates to:
  /// **'Постачальники'**
  String get settingsSuppliers;

  /// Shown on pages whose content is not implemented yet
  ///
  /// In uk, this message translates to:
  /// **'Ця сторінка ще в розробці'**
  String get pageNotImplemented;

  /// Shown for unknown routes
  ///
  /// In uk, this message translates to:
  /// **'Сторінку не знайдено'**
  String get pageNotFound;

  /// Button that navigates to the Home page
  ///
  /// In uk, this message translates to:
  /// **'На головну'**
  String get goHome;

  /// Settings section: app version and self-update
  ///
  /// In uk, this message translates to:
  /// **'Версія застосунку'**
  String get settingsAppVersionSection;

  /// Settings section: installed content suppliers library (bundle)
  ///
  /// In uk, this message translates to:
  /// **'Бібліотека постачальників'**
  String get settingsSuppliersBundleSection;

  /// Subtitle of the suppliers settings entry
  ///
  /// In uk, this message translates to:
  /// **'Порядок, увімкнення та канали рекомендацій'**
  String get settingsSuppliersSubtitle;

  /// Settings section: app language
  ///
  /// In uk, this message translates to:
  /// **'Мова'**
  String get settingsLanguageSection;

  /// Settings section: connect a TV to the signed-in account (pairing code)
  ///
  /// In uk, this message translates to:
  /// **'Телевізор'**
  String get settingsTvSection;

  /// Subtitle of the Connect TV item in Settings
  ///
  /// In uk, this message translates to:
  /// **'Показати код для входу в цей обліковий запис на телевізорі'**
  String get settingsConnectTvSubtitle;

  /// Explains what the language setting affects
  ///
  /// In uk, this message translates to:
  /// **'Мова інтерфейсу та рекомендованих постачальників'**
  String get settingsLanguageHint;

  /// Settings section: theme
  ///
  /// In uk, this message translates to:
  /// **'Тема'**
  String get settingsThemeSection;

  /// Light theme brightness
  ///
  /// In uk, this message translates to:
  /// **'Світла'**
  String get settingsThemeLight;

  /// Theme brightness follows the system
  ///
  /// In uk, this message translates to:
  /// **'Системна'**
  String get settingsThemeSystem;

  /// Dark theme brightness
  ///
  /// In uk, this message translates to:
  /// **'Темна'**
  String get settingsThemeDark;

  /// Theme color scheme picker label
  ///
  /// In uk, this message translates to:
  /// **'Кольорова схема'**
  String get settingsColorScheme;

  /// Color scheme name
  ///
  /// In uk, this message translates to:
  /// **'Олива'**
  String get colorSchemeOlive;

  /// Color scheme name
  ///
  /// In uk, this message translates to:
  /// **'Багрянець'**
  String get colorSchemeCrimson;

  /// Color scheme name
  ///
  /// In uk, this message translates to:
  /// **'Монохром'**
  String get colorSchemeMonochrome;

  /// Color scheme name
  ///
  /// In uk, this message translates to:
  /// **'Хакі'**
  String get colorSchemeKhaki;

  /// Color scheme name
  ///
  /// In uk, this message translates to:
  /// **'Бурштин'**
  String get colorSchemeAmber;

  /// Color scheme name
  ///
  /// In uk, this message translates to:
  /// **'Електричний фіолет'**
  String get colorSchemeElectricViolet;

  /// Color scheme name
  ///
  /// In uk, this message translates to:
  /// **'Кобальт'**
  String get colorSchemeCobalt;

  /// Color scheme name
  ///
  /// In uk, this message translates to:
  /// **'Неоновий ціан'**
  String get colorSchemeNeonCyan;

  /// Currently running app version
  ///
  /// In uk, this message translates to:
  /// **'Поточна версія: {version}'**
  String updatesCurrentVersion(String version);

  /// Latest published version
  ///
  /// In uk, this message translates to:
  /// **'Остання версія: {version}'**
  String updatesLatestVersion(String version);

  /// Installed suppliers library version
  ///
  /// In uk, this message translates to:
  /// **'Встановлена версія: {version}'**
  String updatesInstalledVersion(String version);

  /// Suppliers library is not installed
  ///
  /// In uk, this message translates to:
  /// **'Не встановлено'**
  String get updatesNotInstalled;

  /// A local developer suppliers library is loaded instead of an installed one
  ///
  /// In uk, this message translates to:
  /// **'Локальна бібліотека розробника'**
  String get updatesDevLibrary;

  /// Button: check for updates
  ///
  /// In uk, this message translates to:
  /// **'Перевірити оновлення'**
  String get updatesCheck;

  /// No newer version available
  ///
  /// In uk, this message translates to:
  /// **'Встановлено останню версію'**
  String get updatesUpToDate;

  /// Button: install an update
  ///
  /// In uk, this message translates to:
  /// **'Оновити'**
  String get updatesUpdate;

  /// Button: install the suppliers library
  ///
  /// In uk, this message translates to:
  /// **'Встановити'**
  String get updatesInstall;

  /// Button: cancel a download
  ///
  /// In uk, this message translates to:
  /// **'Скасувати'**
  String get updatesCancel;

  /// Button: retry after an error
  ///
  /// In uk, this message translates to:
  /// **'Повторити'**
  String get updatesRetry;

  /// Download in progress with unknown size
  ///
  /// In uk, this message translates to:
  /// **'Завантаження…'**
  String get updatesDownloading;

  /// Download progress
  ///
  /// In uk, this message translates to:
  /// **'Завантаження: {percent}%'**
  String updatesProgress(int percent);

  /// Error: update check failed
  ///
  /// In uk, this message translates to:
  /// **'Не вдалося перевірити оновлення'**
  String get updatesCheckFailed;

  /// Error: build has no update check URL
  ///
  /// In uk, this message translates to:
  /// **'Адресу перевірки оновлень не налаштовано'**
  String get updatesNotConfigured;

  /// Notice: a newer app version is available
  ///
  /// In uk, this message translates to:
  /// **'Доступна нова версія {version}'**
  String appUpdateAvailable(String version);

  /// Error: app self-update failed
  ///
  /// In uk, this message translates to:
  /// **'Не вдалося оновити застосунок'**
  String get appUpdateFailed;

  /// Error: release has no file for this platform
  ///
  /// In uk, this message translates to:
  /// **'Для цієї платформи немає файлу оновлення'**
  String get appUpdateNoAsset;

  /// Linux: open the update download link in the browser
  ///
  /// In uk, this message translates to:
  /// **'Відкрити сторінку завантаження'**
  String get appUpdateOpenDownload;

  /// Button that opens the release notes dialog
  ///
  /// In uk, this message translates to:
  /// **'Що нового'**
  String get appUpdateReleaseNotes;

  /// Release notes dialog title
  ///
  /// In uk, this message translates to:
  /// **'Що нового у версії {version}'**
  String appUpdateReleaseNotesTitle(String version);

  /// Notice: a newer suppliers library is available
  ///
  /// In uk, this message translates to:
  /// **'Доступна нова бібліотека постачальників {version}'**
  String suppliersBundleUpdateAvailable(String version);

  /// The latest suppliers library is incompatible; the app must be updated first
  ///
  /// In uk, this message translates to:
  /// **'Бібліотека постачальників {version} потребує оновлення застосунку'**
  String suppliersBundleAppUpdateRequired(String version);

  /// Error: suppliers library download or load failed
  ///
  /// In uk, this message translates to:
  /// **'Не вдалося встановити бібліотеку постачальників'**
  String get suppliersBundleInstallFailed;

  /// Startup install prompt title
  ///
  /// In uk, this message translates to:
  /// **'Потрібна бібліотека постачальників'**
  String get suppliersBundleInstallTitle;

  /// Startup install prompt message
  ///
  /// In uk, this message translates to:
  /// **'Щоб переглядати фільми, серіали, аніме та мангу, встановіть бібліотеку постачальників контенту.'**
  String get suppliersBundleInstallMessage;

  /// Suppliers settings: list is empty
  ///
  /// In uk, this message translates to:
  /// **'Немає доступних постачальників'**
  String get suppliersEmpty;

  /// Suppliers settings: supplier enabled switch
  ///
  /// In uk, this message translates to:
  /// **'Увімкнено'**
  String get suppliersEnabled;

  /// Suppliers settings: move supplier up
  ///
  /// In uk, this message translates to:
  /// **'Перемістити вгору'**
  String get suppliersMoveUp;

  /// Suppliers settings: move supplier down
  ///
  /// In uk, this message translates to:
  /// **'Перемістити вниз'**
  String get suppliersMoveDown;

  /// Suppliers settings: recommendation channels
  ///
  /// In uk, this message translates to:
  /// **'Канали рекомендацій'**
  String get suppliersChannels;

  /// Player: subtitles button and panel title
  ///
  /// In uk, this message translates to:
  /// **'Субтитри'**
  String get playerSubtitles;

  /// Subtitles panel: no subtitles
  ///
  /// In uk, this message translates to:
  /// **'Вимкнено'**
  String get playerSubtitlesOff;

  /// Subtitles panel: selected subtitles failed to load
  ///
  /// In uk, this message translates to:
  /// **'Не вдалося завантажити субтитри'**
  String get playerSubtitlesFailed;

  /// Subtitles panel: audio tracks section
  ///
  /// In uk, this message translates to:
  /// **'Аудіо'**
  String get playerAudio;

  /// Automatic audio track or video quality
  ///
  /// In uk, this message translates to:
  /// **'Авто'**
  String get playerAuto;

  /// Unnamed audio track
  ///
  /// In uk, this message translates to:
  /// **'Доріжка {number}'**
  String playerTrack(int number);

  /// Subtitles panel: font size
  ///
  /// In uk, this message translates to:
  /// **'Розмір субтитрів'**
  String get playerSubtitleSize;

  /// Subtitles panel: timing offset; positive shows subtitles later
  ///
  /// In uk, this message translates to:
  /// **'Зсув субтитрів'**
  String get playerSubtitleOffset;

  /// Subtitle offset value, signed seconds like +0.5
  ///
  /// In uk, this message translates to:
  /// **'{seconds} с'**
  String playerSubtitleOffsetValue(String seconds);

  /// Stepper button
  ///
  /// In uk, this message translates to:
  /// **'Зменшити'**
  String get playerDecrease;

  /// Stepper button
  ///
  /// In uk, this message translates to:
  /// **'Збільшити'**
  String get playerIncrease;

  /// Player: settings (gear) button and panel title
  ///
  /// In uk, this message translates to:
  /// **'Налаштування'**
  String get playerSettings;

  /// Player settings: video quality
  ///
  /// In uk, this message translates to:
  /// **'Якість'**
  String get playerQuality;

  /// Subtitle overlay placeholder while the selected subtitles load
  ///
  /// In uk, this message translates to:
  /// **'Завантаження субтитрів…'**
  String get playerSubtitlesLoading;

  /// Player settings: playback speed
  ///
  /// In uk, this message translates to:
  /// **'Швидкість'**
  String get playerSpeed;

  /// Playback speed 1.0
  ///
  /// In uk, this message translates to:
  /// **'Звичайна'**
  String get playerSpeedNormal;

  /// Playback speed value, e.g. 1.25×
  ///
  /// In uk, this message translates to:
  /// **'{value}×'**
  String playerSpeedValue(String value);

  /// Player settings: 5-band equalizer
  ///
  /// In uk, this message translates to:
  /// **'Еквалайзер'**
  String get playerEqualizer;

  /// Equalizer preset: flat
  ///
  /// In uk, this message translates to:
  /// **'Вимкнено'**
  String get playerEqualizerOff;

  /// Equalizer preset
  ///
  /// In uk, this message translates to:
  /// **'Чіткі діалоги'**
  String get playerEqualizerClearDialogue;

  /// Equalizer preset
  ///
  /// In uk, this message translates to:
  /// **'Кіно'**
  String get playerEqualizerCinema;

  /// Equalizer preset
  ///
  /// In uk, this message translates to:
  /// **'Нічний'**
  String get playerEqualizerNight;

  /// Equalizer preset
  ///
  /// In uk, this message translates to:
  /// **'Бойовик'**
  String get playerEqualizerAction;

  /// Equalizer: gains that match no preset
  ///
  /// In uk, this message translates to:
  /// **'Власний'**
  String get playerEqualizerCustom;

  /// Equalizer band frequency
  ///
  /// In uk, this message translates to:
  /// **'{value} Гц'**
  String playerHertz(String value);

  /// Equalizer band frequency
  ///
  /// In uk, this message translates to:
  /// **'{value} кГц'**
  String playerKilohertz(String value);

  /// Equalizer band gain, signed
  ///
  /// In uk, this message translates to:
  /// **'{value} дБ'**
  String playerDecibels(String value);

  /// Player setting: where playback starts
  ///
  /// In uk, this message translates to:
  /// **'Починати з'**
  String get playerStartFrom;

  /// Start from: remembered position
  ///
  /// In uk, this message translates to:
  /// **'Місця зупинки'**
  String get playerStartFromRemembered;

  /// Start from: 0
  ///
  /// In uk, this message translates to:
  /// **'Початку'**
  String get playerStartFromBeginning;

  /// Start from: configured seconds
  ///
  /// In uk, this message translates to:
  /// **'Фіксованої позиції'**
  String get playerStartFromFixed;

  /// Start position for "a fixed position"
  ///
  /// In uk, this message translates to:
  /// **'Фіксована позиція'**
  String get playerFixedPosition;

  /// Player setting: on-end action
  ///
  /// In uk, this message translates to:
  /// **'Після завершення'**
  String get playerOnEnd;

  /// On-end action
  ///
  /// In uk, this message translates to:
  /// **'Наступний епізод'**
  String get playerOnEndNext;

  /// On-end action
  ///
  /// In uk, this message translates to:
  /// **'Повторити'**
  String get playerOnEndAgain;

  /// On-end action
  ///
  /// In uk, this message translates to:
  /// **'Нічого не робити'**
  String get playerOnEndNothing;

  /// Player setting: the next item after the end is random
  ///
  /// In uk, this message translates to:
  /// **'Випадковий порядок'**
  String get playerShuffle;

  /// Player: subtitles toggle while they are off
  ///
  /// In uk, this message translates to:
  /// **'Показати субтитри'**
  String get playerShowSubtitles;

  /// Player: subtitles toggle while they are on
  ///
  /// In uk, this message translates to:
  /// **'Сховати субтитри'**
  String get playerHideSubtitles;

  /// Equalizer preset: full +12 dB boost on every band
  ///
  /// In uk, this message translates to:
  /// **'Максимум'**
  String get playerEqualizerMax;

  /// Player: enter picture-in-picture (Android PiP / compact desktop window)
  ///
  /// In uk, this message translates to:
  /// **'Картинка в картинці'**
  String get playerPip;

  /// Desktop picture-in-picture window: back to the full player
  ///
  /// In uk, this message translates to:
  /// **'Повернутися до повного плеєра'**
  String get playerExitPip;

  /// Desktop picture-in-picture window: stop playback and close the app
  ///
  /// In uk, this message translates to:
  /// **'Закрити застосунок'**
  String get playerCloseApp;

  /// Player setting: keep playing in a mini player after leaving the player
  ///
  /// In uk, this message translates to:
  /// **'Плаваючий плеєр'**
  String get playerFloating;

  /// Player setting: floating player switch subtitle
  ///
  /// In uk, this message translates to:
  /// **'Продовжувати перегляд у міні-плеєрі після виходу з плеєра'**
  String get playerFloatingDescription;

  /// Equalizer page switch: even out loudness over time
  ///
  /// In uk, this message translates to:
  /// **'Нормалізація гучності'**
  String get playerVolumeNormalization;

  /// Equalizer page: volume normalization switch subtitle
  ///
  /// In uk, this message translates to:
  /// **'Вирівнює гучність між тихими та гучними сценами'**
  String get playerVolumeNormalizationDescription;

  /// Equalizer page switch: dynamic range compression
  ///
  /// In uk, this message translates to:
  /// **'Зменшити гучні звуки'**
  String get playerDynamicCompression;

  /// Equalizer page: reduce loud sounds switch subtitle
  ///
  /// In uk, this message translates to:
  /// **'Пом\'якшує різкі гучні звуки, щоб діалоги лишалися чутними на малій гучності'**
  String get playerDynamicCompressionDescription;

  /// Floating mini player: reopen the full-screen player
  ///
  /// In uk, this message translates to:
  /// **'Відкрити плеєр'**
  String get playerOpen;

  /// Floating mini player: stop playback and close it
  ///
  /// In uk, this message translates to:
  /// **'Закрити плеєр'**
  String get playerClose;

  /// Reader: settings side sheet title and button
  ///
  /// In uk, this message translates to:
  /// **'Налаштування читалки'**
  String get readerSettings;

  /// Reader settings: reading mode group
  ///
  /// In uk, this message translates to:
  /// **'Режим читання'**
  String get readerModeTitle;

  /// Reader mode: continuous vertical scroll
  ///
  /// In uk, this message translates to:
  /// **'Стрічка'**
  String get readerModeLongStrip;

  /// Reader mode: one page at a time, turned vertically
  ///
  /// In uk, this message translates to:
  /// **'Посторінково вертикально'**
  String get readerModeVertical;

  /// Reader mode: paged, horizontal
  ///
  /// In uk, this message translates to:
  /// **'Зліва направо'**
  String get readerModeLeftToRight;

  /// Reader mode: paged, horizontal reversed (manga)
  ///
  /// In uk, this message translates to:
  /// **'Справа наліво'**
  String get readerModeRightToLeft;

  /// Reader settings: background group
  ///
  /// In uk, this message translates to:
  /// **'Фон'**
  String get readerBackground;

  /// Reader background: dark
  ///
  /// In uk, this message translates to:
  /// **'Темний'**
  String get readerBackgroundDark;

  /// Reader background: light
  ///
  /// In uk, this message translates to:
  /// **'Світлий'**
  String get readerBackgroundLight;

  /// Reader settings: auto-crop switch
  ///
  /// In uk, this message translates to:
  /// **'Обрізати поля'**
  String get readerAutoCrop;

  /// Reader settings: auto-crop switch subtitle
  ///
  /// In uk, this message translates to:
  /// **'Прибирати білі та чорні поля сторінок'**
  String get readerAutoCropDescription;

  /// Reader: translation (manga source) selector
  ///
  /// In uk, this message translates to:
  /// **'Переклад'**
  String get readerTranslation;

  /// Reader error: pick another translation
  ///
  /// In uk, this message translates to:
  /// **'Змінити переклад'**
  String get readerChangeTranslation;

  /// Reader error: chapter or pages failed to load
  ///
  /// In uk, this message translates to:
  /// **'Не вдалося завантажити розділ'**
  String get readerLoadFailed;

  /// Reader error: no pages available
  ///
  /// In uk, this message translates to:
  /// **'У цьому розділі немає сторінок'**
  String get readerNoPages;

  /// Reader: a page image failed to load
  ///
  /// In uk, this message translates to:
  /// **'Не вдалося завантажити сторінку {number}'**
  String readerPageFailed(int number);

  /// Reader: current page and page count
  ///
  /// In uk, this message translates to:
  /// **'{page} / {total}'**
  String readerPageCounter(int page, int total);

  /// Reader: page after the last page; title of the finished chapter
  ///
  /// In uk, this message translates to:
  /// **'Кінець: {title}'**
  String readerChapterEnd(String title);

  /// Reader: page before the first page; title of the current chapter
  ///
  /// In uk, this message translates to:
  /// **'Початок: {title}'**
  String readerChapterStart(String title);

  /// Reader: open the next chapter
  ///
  /// In uk, this message translates to:
  /// **'Наступний розділ'**
  String get readerNextChapter;

  /// Reader: open the previous chapter
  ///
  /// In uk, this message translates to:
  /// **'Попередній розділ'**
  String get readerPreviousChapter;

  /// Generic delete action
  ///
  /// In uk, this message translates to:
  /// **'Видалити'**
  String get commonDelete;

  /// Dismiss a permission explanation
  ///
  /// In uk, this message translates to:
  /// **'Не зараз'**
  String get commonNotNow;

  /// Confirm a permission explanation
  ///
  /// In uk, this message translates to:
  /// **'Дозволити'**
  String get commonAllow;

  /// Details: download button and sheet title
  ///
  /// In uk, this message translates to:
  /// **'Завантажити'**
  String get detailsDownload;

  /// Download sheet: all items of the content
  ///
  /// In uk, this message translates to:
  /// **'Завантажити все'**
  String get downloadsAll;

  /// Download sheet: pick a single episode
  ///
  /// In uk, this message translates to:
  /// **'Вибрати серію'**
  String get downloadsPickEpisode;

  /// Download sheet: pick a single chapter
  ///
  /// In uk, this message translates to:
  /// **'Вибрати розділ'**
  String get downloadsPickChapter;

  /// Download sheet: source list header
  ///
  /// In uk, this message translates to:
  /// **'Джерело для завантаження'**
  String get downloadsChooseSource;

  /// Download sheet: subtitle selection section title
  ///
  /// In uk, this message translates to:
  /// **'Субтитри для завантаження'**
  String get downloadsSubtitles;

  /// Download sheet: subtitle selection behavior for multiple items
  ///
  /// In uk, this message translates to:
  /// **'Виберіть доріжки субтитрів у порядку пріоритету або вимкніть їх. Для кожного елемента буде взято першу доступну доріжку або доріжку тією ж відомою мовою. Якщо відповідників немає, субтитри не завантажуються.'**
  String get downloadsSubtitleHint;

  /// Download sheet: no downloadable sources
  ///
  /// In uk, this message translates to:
  /// **'Немає джерел для завантаження'**
  String get downloadsNoSources;

  /// Snackbar after enqueueing downloads
  ///
  /// In uk, this message translates to:
  /// **'{count, plural, one{Додано до завантажень: {count}} few{Додано до завантажень: {count}} many{Додано до завантажень: {count}} other{Додано до завантажень: {count}}}'**
  String downloadsAdded(int count);

  /// Downloads page: queue section
  ///
  /// In uk, this message translates to:
  /// **'Черга'**
  String get downloadsQueue;

  /// Downloads page: downloaded content section; home row in offline mode
  ///
  /// In uk, this message translates to:
  /// **'Завантажене'**
  String get downloadsDownloaded;

  /// Downloads page: nothing downloaded
  ///
  /// In uk, this message translates to:
  /// **'Тут з’являтимуться завантажені фільми, серіали та манга'**
  String get downloadsEmpty;

  /// Downloads page: the queue tab has no tasks
  ///
  /// In uk, this message translates to:
  /// **'Черга завантажень порожня'**
  String get downloadsQueueEmpty;

  /// Cancel one task
  ///
  /// In uk, this message translates to:
  /// **'Скасувати завантаження'**
  String get downloadsCancel;

  /// Cancel every active download (page and notification)
  ///
  /// In uk, this message translates to:
  /// **'Скасувати все'**
  String get downloadsCancelAll;

  /// Remove a finished task from the queue list
  ///
  /// In uk, this message translates to:
  /// **'Прибрати зі списку'**
  String get downloadsDismiss;

  /// Remove all finished tasks from the queue list
  ///
  /// In uk, this message translates to:
  /// **'Очистити завершені'**
  String get downloadsClearFinished;

  /// Task state
  ///
  /// In uk, this message translates to:
  /// **'У черзі'**
  String get downloadsStateQueued;

  /// Task state; mark of a downloaded item or source
  ///
  /// In uk, this message translates to:
  /// **'Завантажено'**
  String get downloadsStateCompleted;

  /// Task state
  ///
  /// In uk, this message translates to:
  /// **'Скасовано'**
  String get downloadsStateCanceled;

  /// Number of failed items in a content download group
  ///
  /// In uk, this message translates to:
  /// **'{count} з помилкою'**
  String downloadsFailedCount(int count);

  /// Downloaded vs total items in a content download group
  ///
  /// In uk, this message translates to:
  /// **'{done}/{total}'**
  String downloadsGroupItems(int done, int total);

  /// Expand a content download group to show its items
  ///
  /// In uk, this message translates to:
  /// **'Розгорнути'**
  String get downloadsExpand;

  /// Collapse a content download group
  ///
  /// In uk, this message translates to:
  /// **'Згорнути'**
  String get downloadsCollapse;

  /// Running task: progress and speed
  ///
  /// In uk, this message translates to:
  /// **'{percent}% · {speed}'**
  String downloadsProgress(int percent, String speed);

  /// Download speed
  ///
  /// In uk, this message translates to:
  /// **'{size}/с'**
  String downloadsSpeed(String size);

  /// Task failure
  ///
  /// In uk, this message translates to:
  /// **'Помилка мережі'**
  String get downloadsFailureNetwork;

  /// Task failure: HTTP 4xx
  ///
  /// In uk, this message translates to:
  /// **'Джерело недоступне'**
  String get downloadsFailureUnavailable;

  /// Task failure: source/item gone
  ///
  /// In uk, this message translates to:
  /// **'Джерело не знайдено'**
  String get downloadsFailureSourceNotFound;

  /// Task failure
  ///
  /// In uk, this message translates to:
  /// **'Бібліотека постачальників недоступна'**
  String get downloadsFailureSuppliers;

  /// Task failure
  ///
  /// In uk, this message translates to:
  /// **'Непідтримуваний формат відео'**
  String get downloadsFailureInvalidMedia;

  /// Task failure
  ///
  /// In uk, this message translates to:
  /// **'Не вдалося записати файл'**
  String get downloadsFailureStorage;

  /// Downloaded content: number of episodes
  ///
  /// In uk, this message translates to:
  /// **'{count, plural, one{{count} серія} few{{count} серії} many{{count} серій} other{{count} серії}}'**
  String downloadsEpisodes(int count);

  /// Downloaded content: number of chapters
  ///
  /// In uk, this message translates to:
  /// **'{count, plural, one{{count} розділ} few{{count} розділи} many{{count} розділів} other{{count} розділу}}'**
  String downloadsChapters(int count);

  /// Delete downloaded files of a content or an item
  ///
  /// In uk, this message translates to:
  /// **'Видалити завантажене'**
  String get downloadsDeleteContent;

  /// Delete confirmation
  ///
  /// In uk, this message translates to:
  /// **'Видалити завантажене «{title}»?'**
  String downloadsDeleteConfirm(String title);

  /// Android notification title
  ///
  /// In uk, this message translates to:
  /// **'{count, plural, one{Завантаження: {count}} few{Завантаження: {count}} many{Завантаження: {count}} other{Завантаження: {count}}}'**
  String downloadsNotificationActive(int count);

  /// Android notification text
  ///
  /// In uk, this message translates to:
  /// **'{name} — {percent}%'**
  String downloadsNotificationProgress(String name, int percent);

  /// Android notification title when the queue is done
  ///
  /// In uk, this message translates to:
  /// **'Завантаження завершено'**
  String get downloadsNotificationDone;

  /// Battery optimization explanation title
  ///
  /// In uk, this message translates to:
  /// **'Завантаження у фоні'**
  String get downloadsBatteryTitle;

  /// Battery optimization explanation
  ///
  /// In uk, this message translates to:
  /// **'Щоб завантаження не переривались, коли застосунок згорнуто, дозвольте йому працювати без обмежень батареї.'**
  String get downloadsBatteryMessage;

  /// File size
  ///
  /// In uk, this message translates to:
  /// **'{value} КБ'**
  String sizeKilobytes(String value);

  /// File size
  ///
  /// In uk, this message translates to:
  /// **'{value} МБ'**
  String sizeMegabytes(String value);

  /// File size
  ///
  /// In uk, this message translates to:
  /// **'{value} ГБ'**
  String sizeGigabytes(String value);

  /// Settings: downloads folder
  ///
  /// In uk, this message translates to:
  /// **'Тека завантажень'**
  String get settingsDownloadsFolder;

  /// Settings: pick another downloads folder
  ///
  /// In uk, this message translates to:
  /// **'Змінити'**
  String get settingsDownloadsFolderChange;

  /// Settings: reset the downloads folder
  ///
  /// In uk, this message translates to:
  /// **'Типова тека'**
  String get settingsDownloadsFolderReset;

  /// Settings: max parallel downloads
  ///
  /// In uk, this message translates to:
  /// **'Одночасних завантажень'**
  String get settingsMaxDownloads;

  /// Offline mode switch
  ///
  /// In uk, this message translates to:
  /// **'Офлайн-режим'**
  String get offlineMode;

  /// Offline mode switch subtitle
  ///
  /// In uk, this message translates to:
  /// **'Лише завантажене; колекція синхронізується пізніше'**
  String get offlineModeDescription;

  /// Home suggestion action
  ///
  /// In uk, this message translates to:
  /// **'Увімкнути офлайн-режим'**
  String get offlineModeTurnOn;

  /// Offline Home/Search action
  ///
  /// In uk, this message translates to:
  /// **'Вимкнути офлайн-режим'**
  String get offlineModeTurnOff;

  /// Home: suggestion when every row failed to load
  ///
  /// In uk, this message translates to:
  /// **'Немає з’єднання? Перегляньте завантажене в офлайн-режимі.'**
  String get homeOfflineSuggestion;

  /// Home in offline mode without downloads
  ///
  /// In uk, this message translates to:
  /// **'Немає завантаженого. Вимкніть офлайн-режим, щоб переглядати каталог.'**
  String get homeOfflineEmpty;

  /// Search page in offline mode
  ///
  /// In uk, this message translates to:
  /// **'Пошук недоступний в офлайн-режимі'**
  String get searchOffline;

  /// Download sheet: open the list of seasons
  ///
  /// In uk, this message translates to:
  /// **'Завантажити сезон'**
  String get downloadsPickSeason;

  /// Download sheet: open the list of manga volumes
  ///
  /// In uk, this message translates to:
  /// **'Завантажити том'**
  String get downloadsPickVolume;

  /// Назва джерела відео, субтитрів або манґи з мовою
  ///
  /// In uk, this message translates to:
  /// **'{source} ({language})'**
  String sourceWithLanguage(String source, String language);

  /// Download sheet: several items share the chosen sources; similar ones replace missing ones
  ///
  /// In uk, this message translates to:
  /// **'Виберіть одне чи кілька джерел у порядку пріоритету. Де їх немає, буде взято джерело тією ж мовою, а якщо мову не вказано — перше доступне.'**
  String get downloadsSourcesHint;

  /// Download sheet: priority of a selected source (1 = highest)
  ///
  /// In uk, this message translates to:
  /// **'Пріоритет {priority}'**
  String downloadsSourcePriority(int priority);

  /// Player settings: upscaling (GPU shaders, desktop only, spec-13)
  ///
  /// In uk, this message translates to:
  /// **'Покращення зображення'**
  String get playerUpscaling;

  /// Upscaling choice: off
  ///
  /// In uk, this message translates to:
  /// **'Вимкнено'**
  String get playerUpscalingOff;

  /// Help text under the upscaling choices
  ///
  /// In uk, this message translates to:
  /// **'Збільшує чіткість відео за допомогою відеокарти. Важкі режими на слабкій відеокарті пропускатимуть кадри.'**
  String get playerUpscalingDescription;

  /// Snackbar: the upscaler failed on this GPU and was turned off
  ///
  /// In uk, this message translates to:
  /// **'Не вдалося увімкнути «{name}». Покращення зображення вимкнено.'**
  String playerUpscalingFailed(String name);

  /// Current upscaler on the settings root: family and variant
  ///
  /// In uk, this message translates to:
  /// **'{family} · {variant}'**
  String playerUpscalerValue(String family, String variant);

  /// Upscaler family name (proper noun)
  ///
  /// In uk, this message translates to:
  /// **'FSRCNNX'**
  String get playerUpscalerFamilyFsrcnnx;

  /// Upscaler family name (proper noun)
  ///
  /// In uk, this message translates to:
  /// **'RAVU'**
  String get playerUpscalerFamilyRavu;

  /// Upscaler family name (proper noun)
  ///
  /// In uk, this message translates to:
  /// **'NNEDI3'**
  String get playerUpscalerFamilyNnedi3;

  /// Upscaler family name (proper noun)
  ///
  /// In uk, this message translates to:
  /// **'Anime4K'**
  String get playerUpscalerFamilyAnime4k;

  /// FSRCNNX variant with 8 filters
  ///
  /// In uk, this message translates to:
  /// **'Швидкий'**
  String get playerUpscalerFsrcnnx8;

  /// FSRCNNX variant with 16 filters
  ///
  /// In uk, this message translates to:
  /// **'Якісний'**
  String get playerUpscalerFsrcnnx16;

  /// RAVU lite variant (upstream name)
  ///
  /// In uk, this message translates to:
  /// **'Lite'**
  String get playerUpscalerRavuLite;

  /// RAVU zoom variant (upstream name)
  ///
  /// In uk, this message translates to:
  /// **'Zoom'**
  String get playerUpscalerRavuZoom;

  /// NNEDI3 variant with 64 neurons
  ///
  /// In uk, this message translates to:
  /// **'64 нейрони'**
  String get playerUpscalerNnedi3_64;

  /// NNEDI3 variant with 128 neurons
  ///
  /// In uk, this message translates to:
  /// **'128 нейронів'**
  String get playerUpscalerNnedi3_128;

  /// Anime4K mode A, fast chain
  ///
  /// In uk, this message translates to:
  /// **'Режим A (швидкий)'**
  String get playerUpscalerAnime4kAFast;

  /// Anime4K mode A, HQ chain
  ///
  /// In uk, this message translates to:
  /// **'Режим A (якісний)'**
  String get playerUpscalerAnime4kAHq;

  /// Anime4K mode B, HQ chain
  ///
  /// In uk, this message translates to:
  /// **'Режим B (якісний)'**
  String get playerUpscalerAnime4kBHq;

  /// Anime4K mode C, HQ chain
  ///
  /// In uk, this message translates to:
  /// **'Режим C (якісний)'**
  String get playerUpscalerAnime4kCHq;

  /// Upscaler GPU cost badge
  ///
  /// In uk, this message translates to:
  /// **'Легкий'**
  String get playerUpscalerCostLight;

  /// Upscaler GPU cost badge
  ///
  /// In uk, this message translates to:
  /// **'Середній'**
  String get playerUpscalerCostMedium;

  /// Upscaler GPU cost badge
  ///
  /// In uk, this message translates to:
  /// **'Важкий'**
  String get playerUpscalerCostHeavy;

  /// Upscaler hint: tuned for anime
  ///
  /// In uk, this message translates to:
  /// **'Для аніме'**
  String get playerUpscalerForAnime;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'uk'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'uk':
      return AppLocalizationsUk();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
