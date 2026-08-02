import 'package:dramabox_free/core/constants/app_enums.dart';
import '../../data/models/drama_model.dart';
import '../../data/models/drama_section_model.dart';
import '../../data/models/episode_model.dart';
import '../../data/models/favorite_model.dart';
import '../../data/models/history_model.dart';
import '../../data/models/narto_provider.dart';

abstract class DramaRepository {
  Future<NartoHomeData> getNartoHomeData({String? nartoProviderKey});
  Future<NartoProviderCatalog> getNartoProviders();
  Future<List<DramaSectionModel>> getHomeSections({
    AppContentProvider provider = AppContentProvider.narto,
    String? nartoProviderKey,
  });
  Future<List<DramaSectionModel>?> getCachedHomeSections({
    AppContentProvider provider = AppContentProvider.narto,
    String? nartoProviderKey,
  });
  Future<List<DramaModel>> getTrendingDramas({
    AppContentProvider provider = AppContentProvider.narto,
    int page = 1,
  });
  Future<List<DramaModel>> getForYouDramas({
    AppContentProvider provider = AppContentProvider.narto,
    String? nartoProviderKey,
    int page = 1,
  });
  Future<List<DramaModel>> getLatestDramas({
    AppContentProvider provider = AppContentProvider.narto,
    int page = 1,
  });
  Future<List<DramaModel>> getVipDramas({
    AppContentProvider provider = AppContentProvider.narto,
    int page = 1,
  });
  Future<List<DramaModel>?> getCachedTrendingDramas({
    AppContentProvider provider = AppContentProvider.narto,
  });
  Future<List<DramaModel>?> getCachedLatestDramas({
    AppContentProvider provider = AppContentProvider.narto,
  });
  Future<List<DramaModel>?> getCachedVipDramas({
    AppContentProvider provider = AppContentProvider.narto,
  });
  Future<List<DramaModel>> searchDramas(
    String query, {
    AppContentProvider provider = AppContentProvider.narto,
    String? nartoProviderKey,
  });
  Future<List<EpisodeModel>> getDramaEpisodes(
    String bookId, {
    AppContentProvider provider = AppContentProvider.narto,
    String? nartoProviderKey,
  });
  Future<void> saveLastWatchedIndex(
    String bookId,
    int index, {
    int position = 0,
    int duration = 0,
    AppContentProvider provider = AppContentProvider.narto,
  });
  Future<int> getLastWatchedIndex(
    String bookId, {
    AppContentProvider provider = AppContentProvider.narto,
  });
  Future<Map<String, dynamic>?> getEpisodeProgress(
    String bookId,
    int episodeIndex, {
    AppContentProvider provider = AppContentProvider.narto,
  });
  Future<int> getLocalLastWatchedIndex(String bookId);
  Future<void> saveHistory(HistoryModel history);
  Future<List<HistoryModel>> getHistory();
  Future<List<FavoriteModel>> getFavorites();
  Future<void> saveFavorite(FavoriteModel favorite);
  Future<void> removeFavorite(String bookId, AppContentProvider provider);
  Future<bool> isFavorite(String bookId, AppContentProvider provider);
}
