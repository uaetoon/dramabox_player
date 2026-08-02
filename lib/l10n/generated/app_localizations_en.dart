// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'UAETooNDrama';

  @override
  String get searchDramas => 'Search dramas...';

  @override
  String get noResultsFound => 'No results found';

  @override
  String get history => 'History';

  @override
  String get episodes => 'Episodes';

  @override
  String get ep => 'Ep';

  @override
  String lastWatched(int epNum) {
    return 'LAST WATCHED EP $epNum';
  }

  @override
  String get fetchingEpisodes => 'Fetching episodes...';

  @override
  String get thisMayTake =>
      'This may take a moment depending on your connection.';

  @override
  String get back => 'Back';

  @override
  String get retry => 'Retry';

  @override
  String get buffering => 'Buffering...';

  @override
  String get videoDecryptionFailed =>
      'Video decryption failed. Please try again.';

  @override
  String get keepTrack => 'Keep Track of Your Dramas';

  @override
  String get emptyHistory =>
      'Your viewing history will appear here. Start watching dramas to keep track of where you left off!';

  @override
  String get sectionForYou => 'For You';

  @override
  String get sectionLatest => 'Latest';

  @override
  String get sectionTrending => 'Trending';

  @override
  String get sectionVip => 'VIP';

  @override
  String get settings => 'Settings';

  @override
  String get platforms => 'Platforms';

  @override
  String get specialDubbed => 'Dubbed';

  @override
  String get specialAdult => '18+';

  @override
  String get similarOnPlatforms => 'Similar on other platforms';

  @override
  String get similarSectionHint =>
      'Show similar dramas available on other platforms.';

  @override
  String get scanningPlatforms => 'Scanning platforms...';

  @override
  String get profile => 'Profile';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get arabic => 'العربية';

  @override
  String get about => 'About';

  @override
  String version(String version) {
    return 'Version $version';
  }

  @override
  String checkingUpdates(String version) {
    return 'Checking for updates... ($version)';
  }

  @override
  String downloadingPatch(String version) {
    return 'Downloading patch... ($version)';
  }

  @override
  String get updateReady => 'Update ready! Restart app to apply.';

  @override
  String get updateFailed => 'Update failed';

  @override
  String get serverUnavailable => 'Server Unavailable';

  @override
  String get serverBlockedMessage =>
      'The API server is temporarily blocking requests due to high traffic. Please wait a moment and try again.';

  @override
  String episodesCount(int count) {
    return '$count Episodes';
  }

  @override
  String get episodesTab => 'EPISODES';

  @override
  String get descriptionTab => 'DESCRIPTION';

  @override
  String get speedPlaying => '1.5x Speed Playing';

  @override
  String get subtitles => 'Subtitles';

  @override
  String get subtitleOff => 'Off';

  @override
  String get videoUrlEmpty => 'Video URL is empty';

  @override
  String get search => 'Search';

  @override
  String get myList => 'My List';

  @override
  String get home => 'Home';

  @override
  String get watchHistory => 'Watch History';

  @override
  String get theme => 'Theme';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get themeSystem => 'System';

  @override
  String get searchHint => 'Type a drama title to search across all providers';

  @override
  String get emptyMyList => 'Dramas you add to My List will appear here';

  @override
  String get continueWatching => 'Continue Watching';

  @override
  String get play => 'Play';

  @override
  String get downloads => 'Downloads';

  @override
  String get download => 'Download';

  @override
  String get emptyDownloads =>
      'Episodes you download will appear here. Download episodes from a drama page to watch offline.';

  @override
  String get downloadPaused => 'Paused';

  @override
  String get downloadFailed => 'Download failed';

  @override
  String get downloadCompleted => 'Downloaded';

  @override
  String get downloadQueued => 'Queued';

  @override
  String get pause => 'Pause';

  @override
  String get resume => 'Resume';

  @override
  String get cancel => 'Cancel';

  @override
  String get deleteDownload => 'Delete download';

  @override
  String get deleteDownloadConfirm => 'Delete this download?';

  @override
  String get downloadAllTooltip => 'Download all episodes';

  @override
  String get downloadEpisodeConfirm => 'Download this episode?';

  @override
  String downloadAllConfirm(int count) {
    return 'Download all $count episodes?';
  }

  @override
  String estimatedSizeLabel(String size) {
    return 'Estimated size: $size';
  }

  @override
  String downloadAllEstimatedSize(String size) {
    return 'Estimated total: $size';
  }

  @override
  String get estimatingSize => 'Estimating size...';

  @override
  String get sizeUnknown => 'Size not available';

  @override
  String get largeDownload => 'Large download';

  @override
  String get largeDownloadWarning =>
      'This is a large download and may use significant storage and mobile data.';

  @override
  String downloadsQueued(int count) {
    return '$count episodes queued for download';
  }

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get episodeNotAvailable =>
      'This episode is not available yet. Try again later.';

  @override
  String get adultContent => 'Adult Content';

  @override
  String get adultContentHint =>
      'Show the 18+ provider in the home bar. Unlocking requires a code.';

  @override
  String get enterCode => 'Enter code';

  @override
  String get wrongCode => 'Incorrect code. Try again.';

  @override
  String get unlockAdultContent => 'Unlock adult content';

  @override
  String get lockAdultContent => 'Lock adult content';

  @override
  String get unlocked => 'Unlocked';

  @override
  String get locked => 'Locked';

  @override
  String get confirm => 'Confirm';

  @override
  String get uiStyle => 'UI Style';

  @override
  String get uiClassic => 'Classic';

  @override
  String get uiQuickplay => 'QuickPlay';

  @override
  String get playback => 'Playback';

  @override
  String get autoPlayNext => 'Auto-play next episode';

  @override
  String get autoPlayNextHint =>
      'Automatically advance to the next episode when one finishes.';

  @override
  String get defaultSpeed => 'Default speed';

  @override
  String get searchAllProviders => 'Search across all providers';

  @override
  String searchingProviders(int completed, int total) {
    return 'Searching $completed/$total providers...';
  }

  @override
  String searchComplete(int count) {
    return '$count results found';
  }
}
