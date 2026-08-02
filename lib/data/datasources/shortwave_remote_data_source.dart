import 'package:dramabox_free/data/models/drama_model.dart';
import 'package:dramabox_free/data/models/drama_section_model.dart';
import 'package:dramabox_free/data/models/episode_model.dart';

/// ShortWave (shortwave.dramafren.org) is delivered as an embedded WebView of
/// the dramafren site (see [ShortWaveWebViewPage]) because Cloudflare blocks
/// plain HTTP clients (403) but accepts a real browser. The site is a complete
/// SPA (grid, search, detail, player), so the app hosts it directly instead of
/// scraping its JSON API.
///
/// These native catalogue methods intentionally return nothing so the home tab
/// switches to the embedded site instantly without a network round-trip.
class ShortWaveRemoteDataSource {
  /// Provider key used across the app for this platform.
  static const String shortWaveProviderKey = 'shortwave';

  /// Provider key for the dramafren mirror of the DramaBox catalog
  /// (dramabox.dramafren.org), embedded as a WebView like ShortWave.
  static const String dramafrenDramaboxProviderKey = 'dramafren_dramabox';

  Future<List<DramaSectionModel>> getHomeSections() async => const [];

  Future<List<DramaModel>> searchDramas(String query) async => const [];

  Future<List<EpisodeModel>> getDramaEpisodes(String dramaId) async =>
      const [];
}
