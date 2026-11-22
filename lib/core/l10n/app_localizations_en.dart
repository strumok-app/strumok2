// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonClose => 'Close';

  @override
  String get commonSave => 'Save';

  @override
  String get homeContinue => 'Continue';

  @override
  String get mediaTypeVideo => 'Video';

  @override
  String get mediaTypeManga => 'Manga';

  @override
  String get collectionEmpty => 'Your collection is empty. Add movies, series and manga from their details page.';

  @override
  String get collectionSearchHint => 'Search in collection';

  @override
  String get collectionStatusTitle => 'Status';

  @override
  String get collectionPriorityTitle => 'Priority';

  @override
  String get collectionFilterMediaType => 'Type';

  @override
  String get collectionAdd => 'Add to collection';

  @override
  String get collectionRemove => 'Remove from collection';

  @override
  String get collectionStatusNone => 'Not in collection';

  @override
  String get collectionStatusInProgress => 'In progress';

  @override
  String get collectionStatusLater => 'Later';

  @override
  String get collectionStatusOnHold => 'On hold';

  @override
  String get collectionStatusComplete => 'Completed';

  @override
  String get collectionPriorityLow => 'Low';

  @override
  String get collectionPriorityNormal => 'Normal';

  @override
  String get collectionPriorityHigh => 'High';

  @override
  String collectionEpisode(int number) {
    return 'Episode $number';
  }

  @override
  String collectionChapter(int number) {
    return 'Chapter $number';
  }

  @override
  String get profilesTitle => 'Profiles';

  @override
  String get profilesPickTitle => 'Who\'s watching?';

  @override
  String get profilesAdd => 'Add profile';

  @override
  String get profilesEdit => 'Edit profile';

  @override
  String get profilesName => 'Profile name';

  @override
  String get profilesColor => 'Color';

  @override
  String get profilesDelete => 'Delete profile';

  @override
  String profilesDeleteConfirm(String name) {
    return 'Delete profile “$name”? Its collection is removed from this device; data in the Google account is kept.';
  }

  @override
  String get profilesActive => 'Current profile';

  @override
  String get profilesSwitch => 'Switch profile';

  @override
  String get profilesManage => 'Manage profiles';

  @override
  String get profilesAskOnStartup => 'Ask for profile on startup';

  @override
  String get profilesAskOnStartupSubtitle => 'When there are several profiles';

  @override
  String get settingsProfilesSubtitle => 'Separate collections for each family member';

  @override
  String get commonRetry => 'Retry';

  @override
  String get errorLoading => 'Failed to load';

  @override
  String get rowEmpty => 'Nothing here yet';

  @override
  String get rowLoadMore => 'Load more';

  @override
  String get rowReload => 'Reload';

  @override
  String get rowPickRandom => 'Pick random';

  @override
  String get randomPickAnother => 'Another one';

  @override
  String get randomPickOpen => 'Open';

  @override
  String get randomPickEmpty => 'Nothing to pick from';

  @override
  String get homeEmpty => 'Choose suppliers and recommendation channels in settings';

  @override
  String get homeConfigure => 'Configure';

  @override
  String get searchHint => 'Search movies, series, anime, manga';

  @override
  String get searchClear => 'Clear';

  @override
  String get searchFilters => 'Filters';

  @override
  String get searchFilterLanguages => 'Languages';

  @override
  String get searchFilterTypes => 'Types';

  @override
  String get searchFilterSuppliers => 'Suppliers';

  @override
  String get searchEnterQuery => 'Enter a title to search';

  @override
  String get searchNoSuppliers => 'No suppliers match the selected filters';

  @override
  String get searchNothingFound => 'Nothing found';

  @override
  String get searchRemoveFromHistory => 'Remove from history';

  @override
  String get contentTypeMovie => 'Movies';

  @override
  String get contentTypeAnime => 'Anime';

  @override
  String get contentTypeCartoon => 'Cartoons';

  @override
  String get contentTypeSeries => 'Series';

  @override
  String get contentTypeManga => 'Manga';

  @override
  String get languageUk => 'Українська';

  @override
  String get languageEn => 'English';

  @override
  String get detailsWatch => 'Watch';

  @override
  String get detailsRead => 'Read';

  @override
  String get detailsMore => 'More';

  @override
  String get detailsLess => 'Less';

  @override
  String get detailsEpisodes => 'Episodes';

  @override
  String get detailsChapters => 'Chapters';

  @override
  String get detailsEpisodesLoadError => 'Failed to load episodes';

  @override
  String get detailsChaptersLoadError => 'Failed to load chapters';

  @override
  String get detailsSimilar => 'Similar';

  @override
  String get detailsNotFound => 'Content not found';

  @override
  String detailsSupplierUnavailable(String supplier) {
    return 'Supplier \"$supplier\" is not available';
  }

  @override
  String get appTitle => 'Strumok';

  @override
  String get navHome => 'Home';

  @override
  String get navSearch => 'Search';

  @override
  String get navCollection => 'Collection';

  @override
  String get navSettings => 'Settings';

  @override
  String get navDownloads => 'Downloads';

  @override
  String get accountMenuTooltip => 'Account';

  @override
  String get accountNotSignedIn => 'Not signed in';

  @override
  String get accountSignInGoogle => 'Sign in with Google';

  @override
  String get accountSignInWithCode => 'Sign in with a code';

  @override
  String get accountConnectTv => 'Connect a TV';

  @override
  String get accountSignOut => 'Sign out';

  @override
  String get accountSignIn => 'Sign in';

  @override
  String get accountSignInBrowser => 'Continue signing in in your browser';

  @override
  String get accountSigningIn => 'Signing in…';

  @override
  String get accountSignInFailed => 'Could not sign in. Check your connection and try again.';

  @override
  String get accountSignInUnavailable => 'Sign-in is not available in this build';

  @override
  String accountAlreadyLinked(String name) {
    return 'This account is already linked to profile “$name”.';
  }

  @override
  String get accountSwitchToProfile => 'Switch to profile';

  @override
  String get accountSyncHint => 'The collection syncs with the Google account';

  @override
  String get pairingCodeTitle => 'Sign in with a code';

  @override
  String get pairingCodeInstruction =>
      'On a phone or computer where you are signed in, open the account menu → “Connect a TV” and enter the code shown there.';

  @override
  String get pairingCodeLabel => 'Code';

  @override
  String get pairingCodeInvalid => 'Invalid or expired code';

  @override
  String get connectTvTitle => 'Connect a TV';

  @override
  String get connectTvInstruction => 'On the TV, open the account menu → “Sign in with a code” and enter this code.';

  @override
  String get connectTvFailed => 'Could not get a code';

  @override
  String get detailsTitle => 'Details';

  @override
  String get playerTitle => 'Player';

  @override
  String get readerTitle => 'Reader';

  @override
  String get playerNoSources => 'No video sources available';

  @override
  String get playerLoadFailed => 'Could not load the video';

  @override
  String get playerPlaybackFailed => 'Playback error';

  @override
  String get playerChangeSource => 'Change source';

  @override
  String get playerSource => 'Source';

  @override
  String get playerPlay => 'Play';

  @override
  String get playerPause => 'Pause';

  @override
  String get playerNext => 'Next';

  @override
  String get playerPrevious => 'Previous';

  @override
  String get playerFullscreen => 'Full screen';

  @override
  String get playerExitFullscreen => 'Exit full screen';

  @override
  String get playerMute => 'Mute';

  @override
  String get playerUnmute => 'Unmute';

  @override
  String playerShortcutHint(String label, String key) {
    return '$label ($key)';
  }

  @override
  String get playerShortcutsTitle => 'Keyboard shortcuts';

  @override
  String get playerShortcutsClose => 'Press any key or click to close';

  @override
  String get playerShortcutPlayPause => 'Play / pause';

  @override
  String playerShortcutSeek(int seconds) {
    return 'Seek back / forward $seconds s';
  }

  @override
  String get playerShortcutFrameStep => 'Previous / next frame';

  @override
  String get playerShortcutVolume => 'Volume up / down (or mouse wheel)';

  @override
  String get playerShortcutMute => 'Mute / unmute';

  @override
  String get playerShortcutPreviousNext => 'Previous / next episode';

  @override
  String get playerShortcutSubtitles => 'Show / hide subtitles';

  @override
  String get playerShortcutHelp => 'Show this list';

  @override
  String get playerKeybindings => 'Keybindings';

  @override
  String get playerLock => 'Lock controls';

  @override
  String get playerUnlock => 'Unlock controls';

  @override
  String playerSeekForward(int seconds) {
    return '+$seconds s';
  }

  @override
  String playerSeekBackward(int seconds) {
    return '−$seconds s';
  }

  @override
  String get playerBrightness => 'Brightness';

  @override
  String get playerVolume => 'Volume';

  @override
  String get settingsSuppliers => 'Suppliers';

  @override
  String get pageNotImplemented => 'This page is not implemented yet';

  @override
  String get pageNotFound => 'Page not found';

  @override
  String get goHome => 'Go home';

  @override
  String get settingsAppVersionSection => 'App version';

  @override
  String get settingsSuppliersBundleSection => 'Suppliers library';

  @override
  String get settingsSuppliersSubtitle => 'Order, availability and recommendation channels';

  @override
  String get settingsLanguageSection => 'Language';

  @override
  String get settingsTvSection => 'TV';

  @override
  String get settingsConnectTvSubtitle => 'Show a code to sign in to this account on a TV';

  @override
  String get settingsLanguageHint => 'Interface language and default suppliers';

  @override
  String get settingsThemeSection => 'Theme';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsColorScheme => 'Color scheme';

  @override
  String get colorSchemeOlive => 'Olive';

  @override
  String get colorSchemeCrimson => 'Crimson';

  @override
  String get colorSchemeMonochrome => 'Monochrome';

  @override
  String get colorSchemeKhaki => 'Khaki';

  @override
  String get colorSchemeAmber => 'Amber';

  @override
  String get colorSchemeElectricViolet => 'Electric violet';

  @override
  String get colorSchemeCobalt => 'Cobalt';

  @override
  String get colorSchemeNeonCyan => 'Neon cyan';

  @override
  String updatesCurrentVersion(String version) {
    return 'Current version: $version';
  }

  @override
  String updatesLatestVersion(String version) {
    return 'Latest version: $version';
  }

  @override
  String updatesInstalledVersion(String version) {
    return 'Installed version: $version';
  }

  @override
  String get updatesNotInstalled => 'Not installed';

  @override
  String get updatesDevLibrary => 'Local developer library';

  @override
  String get updatesCheck => 'Check for updates';

  @override
  String get updatesUpToDate => 'Up to date';

  @override
  String get updatesUpdate => 'Update';

  @override
  String get updatesInstall => 'Install';

  @override
  String get updatesCancel => 'Cancel';

  @override
  String get updatesRetry => 'Retry';

  @override
  String get updatesDownloading => 'Downloading…';

  @override
  String updatesProgress(int percent) {
    return 'Downloading: $percent%';
  }

  @override
  String get updatesCheckFailed => 'Failed to check for updates';

  @override
  String get updatesNotConfigured => 'Update check URL is not configured';

  @override
  String appUpdateAvailable(String version) {
    return 'New version $version is available';
  }

  @override
  String get appUpdateFailed => 'App update failed';

  @override
  String get appUpdateNoAsset => 'No update file for this platform';

  @override
  String get appUpdateOpenDownload => 'Open download page';

  @override
  String get appUpdateReleaseNotes => 'Release notes';

  @override
  String appUpdateReleaseNotesTitle(String version) {
    return 'What\'s new in $version';
  }

  @override
  String suppliersBundleUpdateAvailable(String version) {
    return 'New suppliers library $version is available';
  }

  @override
  String suppliersBundleAppUpdateRequired(String version) {
    return 'Suppliers library $version requires an app update';
  }

  @override
  String get suppliersBundleInstallFailed => 'Failed to install the suppliers library';

  @override
  String get suppliersBundleInstallTitle => 'Suppliers library required';

  @override
  String get suppliersBundleInstallMessage =>
      'Install the content suppliers library to browse movies, series, anime and manga.';

  @override
  String get suppliersEmpty => 'No suppliers available';

  @override
  String get suppliersEnabled => 'Enabled';

  @override
  String get suppliersMoveUp => 'Move up';

  @override
  String get suppliersMoveDown => 'Move down';

  @override
  String get suppliersChannels => 'Recommendation channels';

  @override
  String get playerSubtitles => 'Subtitles';

  @override
  String get playerSubtitlesOff => 'Off';

  @override
  String get playerSubtitlesFailed => 'Couldn\'t load the subtitles';

  @override
  String get playerAudio => 'Audio';

  @override
  String get playerAuto => 'Auto';

  @override
  String playerTrack(int number) {
    return 'Track $number';
  }

  @override
  String get playerSubtitleSize => 'Subtitle size';

  @override
  String get playerSubtitleOffset => 'Subtitle offset';

  @override
  String playerSubtitleOffsetValue(String seconds) {
    return '$seconds s';
  }

  @override
  String get playerDecrease => 'Decrease';

  @override
  String get playerIncrease => 'Increase';

  @override
  String get playerSettings => 'Settings';

  @override
  String get playerQuality => 'Quality';

  @override
  String get playerSubtitlesLoading => 'Loading subtitles…';

  @override
  String get playerSpeed => 'Speed';

  @override
  String get playerSpeedNormal => 'Normal';

  @override
  String playerSpeedValue(String value) {
    return '$value×';
  }

  @override
  String get playerEqualizer => 'Equalizer';

  @override
  String get playerEqualizerOff => 'Off';

  @override
  String get playerEqualizerClearDialogue => 'Clear dialogue';

  @override
  String get playerEqualizerCinema => 'Cinema';

  @override
  String get playerEqualizerNight => 'Night';

  @override
  String get playerEqualizerAction => 'Action';

  @override
  String get playerEqualizerCustom => 'Custom';

  @override
  String playerHertz(String value) {
    return '$value Hz';
  }

  @override
  String playerKilohertz(String value) {
    return '$value kHz';
  }

  @override
  String playerDecibels(String value) {
    return '$value dB';
  }

  @override
  String get playerStartFrom => 'Start from';

  @override
  String get playerStartFromRemembered => 'Where I left off';

  @override
  String get playerStartFromBeginning => 'The beginning';

  @override
  String get playerStartFromFixed => 'A fixed position';

  @override
  String get playerFixedPosition => 'Fixed position';

  @override
  String get playerOnEnd => 'When it ends';

  @override
  String get playerOnEndNext => 'Play the next one';

  @override
  String get playerOnEndAgain => 'Play again';

  @override
  String get playerOnEndNothing => 'Do nothing';

  @override
  String get playerShuffle => 'Shuffle';

  @override
  String get playerShowSubtitles => 'Show subtitles';

  @override
  String get playerHideSubtitles => 'Hide subtitles';

  @override
  String get playerEqualizerMax => 'Max';

  @override
  String get playerPip => 'Picture in picture';

  @override
  String get playerExitPip => 'Back to the full player';

  @override
  String get playerCloseApp => 'Close the app';

  @override
  String get playerFloating => 'Floating player';

  @override
  String get playerFloatingDescription => 'Keep watching in a mini player after leaving the player';

  @override
  String get playerVolumeNormalization => 'Volume normalization';

  @override
  String get playerVolumeNormalizationDescription => 'Evens out loudness between quiet and loud scenes';

  @override
  String get playerDynamicCompression => 'Reduce loud sounds';

  @override
  String get playerDynamicCompressionDescription => 'Softens sudden loud sounds so dialogue stays clear at low volume';

  @override
  String get playerOpen => 'Open player';

  @override
  String get playerClose => 'Close player';

  @override
  String get readerSettings => 'Reader settings';

  @override
  String get readerModeTitle => 'Reading mode';

  @override
  String get readerModeLongStrip => 'Long strip';

  @override
  String get readerModeVertical => 'Paged, vertical';

  @override
  String get readerModeLeftToRight => 'Left to right';

  @override
  String get readerModeRightToLeft => 'Right to left';

  @override
  String get readerBackground => 'Background';

  @override
  String get readerBackgroundDark => 'Dark';

  @override
  String get readerBackgroundLight => 'Light';

  @override
  String get readerAutoCrop => 'Crop borders';

  @override
  String get readerAutoCropDescription => 'Remove white and black page margins';

  @override
  String get readerTranslation => 'Translation';

  @override
  String get readerChangeTranslation => 'Change translation';

  @override
  String get readerLoadFailed => 'Could not load the chapter';

  @override
  String get readerNoPages => 'This chapter has no pages';

  @override
  String readerPageFailed(int number) {
    return 'Couldn\'t load page $number';
  }

  @override
  String readerPageCounter(int page, int total) {
    return '$page / $total';
  }

  @override
  String readerChapterEnd(String title) {
    return 'End of $title';
  }

  @override
  String readerChapterStart(String title) {
    return 'Start of $title';
  }

  @override
  String get readerNextChapter => 'Next chapter';

  @override
  String get readerPreviousChapter => 'Previous chapter';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonNotNow => 'Not now';

  @override
  String get commonAllow => 'Allow';

  @override
  String get detailsDownload => 'Download';

  @override
  String get downloadsAll => 'Download all';

  @override
  String get downloadsPickEpisode => 'Choose an episode';

  @override
  String get downloadsPickChapter => 'Choose a chapter';

  @override
  String get downloadsChooseSource => 'Source to download';

  @override
  String get downloadsSubtitles => 'Subtitles to download';

  @override
  String get downloadsSubtitleHint =>
      'Pick subtitle tracks in priority order, or choose Off. Each item gets the first available track, or one in the same known language. If none matches, subtitles are skipped.';

  @override
  String get downloadsNoSources => 'Nothing to download from this source';

  @override
  String downloadsAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added $count downloads',
      one: 'Added $count download',
    );
    return '$_temp0';
  }

  @override
  String get downloadsQueue => 'Queue';

  @override
  String get downloadsDownloaded => 'Downloaded';

  @override
  String get downloadsEmpty => 'Downloaded movies, series and manga will appear here';

  @override
  String get downloadsQueueEmpty => 'The download queue is empty';

  @override
  String get downloadsCancel => 'Cancel download';

  @override
  String get downloadsCancelAll => 'Cancel all';

  @override
  String get downloadsDismiss => 'Remove from the list';

  @override
  String get downloadsClearFinished => 'Clear finished';

  @override
  String get downloadsStateQueued => 'Queued';

  @override
  String get downloadsStateCompleted => 'Downloaded';

  @override
  String get downloadsStateCanceled => 'Canceled';

  @override
  String downloadsFailedCount(int count) {
    return '$count failed';
  }

  @override
  String downloadsGroupItems(int done, int total) {
    return '$done/$total';
  }

  @override
  String get downloadsExpand => 'Expand';

  @override
  String get downloadsCollapse => 'Collapse';

  @override
  String downloadsProgress(int percent, String speed) {
    return '$percent% · $speed';
  }

  @override
  String downloadsSpeed(String size) {
    return '$size/s';
  }

  @override
  String get downloadsFailureNetwork => 'Network error';

  @override
  String get downloadsFailureUnavailable => 'The source is not available';

  @override
  String get downloadsFailureSourceNotFound => 'The source was not found';

  @override
  String get downloadsFailureSuppliers => 'The suppliers library is not available';

  @override
  String get downloadsFailureInvalidMedia => 'Unsupported video format';

  @override
  String get downloadsFailureStorage => 'Could not write the file';

  @override
  String downloadsEpisodes(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count episodes', one: '$count episode');
    return '$_temp0';
  }

  @override
  String downloadsChapters(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count chapters', one: '$count chapter');
    return '$_temp0';
  }

  @override
  String get downloadsDeleteContent => 'Delete download';

  @override
  String downloadsDeleteConfirm(String title) {
    return 'Delete the download of “$title”?';
  }

  @override
  String downloadsNotificationActive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Downloading $count items',
      one: 'Downloading $count item',
    );
    return '$_temp0';
  }

  @override
  String downloadsNotificationProgress(String name, int percent) {
    return '$name — $percent%';
  }

  @override
  String get downloadsNotificationDone => 'Downloads finished';

  @override
  String get downloadsBatteryTitle => 'Background downloads';

  @override
  String get downloadsBatteryMessage =>
      'To keep downloads going while the app is in the background, allow it to run without battery restrictions.';

  @override
  String sizeKilobytes(String value) {
    return '$value KB';
  }

  @override
  String sizeMegabytes(String value) {
    return '$value MB';
  }

  @override
  String sizeGigabytes(String value) {
    return '$value GB';
  }

  @override
  String get settingsDownloadsFolder => 'Downloads folder';

  @override
  String get settingsDownloadsFolderChange => 'Change';

  @override
  String get settingsDownloadsFolderReset => 'Default folder';

  @override
  String get settingsMaxDownloads => 'Parallel downloads';

  @override
  String get offlineMode => 'Offline mode';

  @override
  String get offlineModeDescription => 'Downloaded content only; the collection syncs later';

  @override
  String get offlineModeTurnOn => 'Turn on offline mode';

  @override
  String get offlineModeTurnOff => 'Turn off offline mode';

  @override
  String get homeOfflineSuggestion => 'No connection? Watch your downloads in offline mode.';

  @override
  String get homeOfflineEmpty => 'Nothing is downloaded yet. Turn off offline mode to browse.';

  @override
  String get searchOffline => 'Search is not available in offline mode';

  @override
  String get downloadsPickSeason => 'Download a season';

  @override
  String get downloadsPickVolume => 'Download a volume';

  @override
  String sourceWithLanguage(String source, String language) {
    return '$source ($language)';
  }

  @override
  String get downloadsSourcesHint =>
      'Pick one or more sources in order of priority. Where they are missing, a source in the same language is used, or the first available source if the language is unknown.';

  @override
  String downloadsSourcePriority(int priority) {
    return 'Priority $priority';
  }
}
