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

  /// Language name
  ///
  /// In uk, this message translates to:
  /// **'Українська'**
  String get languageUk;

  /// Language name
  ///
  /// In uk, this message translates to:
  /// **'Англійська'**
  String get languageEn;

  /// Language name
  ///
  /// In uk, this message translates to:
  /// **'Японська'**
  String get languageJa;

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

  /// Link to release notes
  ///
  /// In uk, this message translates to:
  /// **'Що нового'**
  String get appUpdateReleaseNotes;

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
