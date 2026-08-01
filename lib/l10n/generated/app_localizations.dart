import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
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
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'UAETooNDrama'**
  String get appName;

  /// No description provided for @searchDramas.
  ///
  /// In en, this message translates to:
  /// **'Search dramas...'**
  String get searchDramas;

  /// No description provided for @noResultsFound.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResultsFound;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @episodes.
  ///
  /// In en, this message translates to:
  /// **'Episodes'**
  String get episodes;

  /// No description provided for @ep.
  ///
  /// In en, this message translates to:
  /// **'Ep'**
  String get ep;

  /// No description provided for @lastWatched.
  ///
  /// In en, this message translates to:
  /// **'LAST WATCHED EP {epNum}'**
  String lastWatched(int epNum);

  /// No description provided for @fetchingEpisodes.
  ///
  /// In en, this message translates to:
  /// **'Fetching episodes...'**
  String get fetchingEpisodes;

  /// No description provided for @thisMayTake.
  ///
  /// In en, this message translates to:
  /// **'This may take a moment depending on your connection.'**
  String get thisMayTake;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @videoDecryptionFailed.
  ///
  /// In en, this message translates to:
  /// **'Video decryption failed. Please try again.'**
  String get videoDecryptionFailed;

  /// No description provided for @keepTrack.
  ///
  /// In en, this message translates to:
  /// **'Keep Track of Your Dramas'**
  String get keepTrack;

  /// No description provided for @emptyHistory.
  ///
  /// In en, this message translates to:
  /// **'Your viewing history will appear here. Start watching dramas to keep track of where you left off!'**
  String get emptyHistory;

  /// No description provided for @sectionForYou.
  ///
  /// In en, this message translates to:
  /// **'For You'**
  String get sectionForYou;

  /// No description provided for @sectionLatest.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get sectionLatest;

  /// No description provided for @sectionTrending.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get sectionTrending;

  /// No description provided for @sectionVip.
  ///
  /// In en, this message translates to:
  /// **'VIP'**
  String get sectionVip;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @platforms.
  ///
  /// In en, this message translates to:
  /// **'Platforms'**
  String get platforms;

  /// No description provided for @specialDubbed.
  ///
  /// In en, this message translates to:
  /// **'Dubbed'**
  String get specialDubbed;

  /// No description provided for @specialAdult.
  ///
  /// In en, this message translates to:
  /// **'18+'**
  String get specialAdult;

  /// No description provided for @similarOnPlatforms.
  ///
  /// In en, this message translates to:
  /// **'Similar on other platforms'**
  String get similarOnPlatforms;

  /// No description provided for @similarSectionHint.
  ///
  /// In en, this message translates to:
  /// **'Show similar dramas available on other platforms.'**
  String get similarSectionHint;

  /// No description provided for @scanningPlatforms.
  ///
  /// In en, this message translates to:
  /// **'Scanning platforms...'**
  String get scanningPlatforms;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @arabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get arabic;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String version(String version);

  /// No description provided for @checkingUpdates.
  ///
  /// In en, this message translates to:
  /// **'Checking for updates... ({version})'**
  String checkingUpdates(String version);

  /// No description provided for @downloadingPatch.
  ///
  /// In en, this message translates to:
  /// **'Downloading patch... ({version})'**
  String downloadingPatch(String version);

  /// No description provided for @updateReady.
  ///
  /// In en, this message translates to:
  /// **'Update ready! Restart app to apply.'**
  String get updateReady;

  /// No description provided for @updateFailed.
  ///
  /// In en, this message translates to:
  /// **'Update failed'**
  String get updateFailed;

  /// No description provided for @serverUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Server Unavailable'**
  String get serverUnavailable;

  /// No description provided for @serverBlockedMessage.
  ///
  /// In en, this message translates to:
  /// **'The API server is temporarily blocking requests due to high traffic. Please wait a moment and try again.'**
  String get serverBlockedMessage;

  /// No description provided for @episodesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Episodes'**
  String episodesCount(int count);

  /// No description provided for @episodesTab.
  ///
  /// In en, this message translates to:
  /// **'EPISODES'**
  String get episodesTab;

  /// No description provided for @descriptionTab.
  ///
  /// In en, this message translates to:
  /// **'DESCRIPTION'**
  String get descriptionTab;

  /// No description provided for @speedPlaying.
  ///
  /// In en, this message translates to:
  /// **'1.5x Speed Playing'**
  String get speedPlaying;

  /// No description provided for @subtitles.
  ///
  /// In en, this message translates to:
  /// **'Subtitles'**
  String get subtitles;

  /// No description provided for @subtitleOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get subtitleOff;

  /// No description provided for @videoUrlEmpty.
  ///
  /// In en, this message translates to:
  /// **'Video URL is empty'**
  String get videoUrlEmpty;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @myList.
  ///
  /// In en, this message translates to:
  /// **'My List'**
  String get myList;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @watchHistory.
  ///
  /// In en, this message translates to:
  /// **'Watch History'**
  String get watchHistory;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Type a drama title to search across all providers'**
  String get searchHint;

  /// No description provided for @emptyMyList.
  ///
  /// In en, this message translates to:
  /// **'Dramas you add to My List will appear here'**
  String get emptyMyList;

  /// No description provided for @continueWatching.
  ///
  /// In en, this message translates to:
  /// **'Continue Watching'**
  String get continueWatching;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @downloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloads;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @emptyDownloads.
  ///
  /// In en, this message translates to:
  /// **'Episodes you download will appear here. Download episodes from a drama page to watch offline.'**
  String get emptyDownloads;

  /// No description provided for @downloadPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get downloadPaused;

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get downloadFailed;

  /// No description provided for @downloadCompleted.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get downloadCompleted;

  /// No description provided for @downloadQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get downloadQueued;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @deleteDownload.
  ///
  /// In en, this message translates to:
  /// **'Delete download'**
  String get deleteDownload;

  /// No description provided for @deleteDownloadConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this download?'**
  String get deleteDownloadConfirm;

  /// No description provided for @downloadAllTooltip.
  ///
  /// In en, this message translates to:
  /// **'Download all episodes'**
  String get downloadAllTooltip;

  /// No description provided for @downloadsQueued.
  ///
  /// In en, this message translates to:
  /// **'{count} episodes queued for download'**
  String downloadsQueued(int count);

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @episodeNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'This episode is not available yet. Try again later.'**
  String get episodeNotAvailable;

  /// No description provided for @adultContent.
  ///
  /// In en, this message translates to:
  /// **'Adult Content'**
  String get adultContent;

  /// No description provided for @adultContentHint.
  ///
  /// In en, this message translates to:
  /// **'Show the 18+ provider in the home bar. Unlocking requires a code.'**
  String get adultContentHint;

  /// No description provided for @enterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter code'**
  String get enterCode;

  /// No description provided for @wrongCode.
  ///
  /// In en, this message translates to:
  /// **'Incorrect code. Try again.'**
  String get wrongCode;

  /// No description provided for @unlockAdultContent.
  ///
  /// In en, this message translates to:
  /// **'Unlock adult content'**
  String get unlockAdultContent;

  /// No description provided for @lockAdultContent.
  ///
  /// In en, this message translates to:
  /// **'Lock adult content'**
  String get lockAdultContent;

  /// No description provided for @unlocked.
  ///
  /// In en, this message translates to:
  /// **'Unlocked'**
  String get unlocked;

  /// No description provided for @locked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get locked;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
