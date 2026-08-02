import 'package:dramabox_free/core/constants/app_enums.dart';
import 'package:dramabox_free/domain/repositories/drama_repository.dart';
import 'package:dramabox_free/data/datasources/drama_local_data_source.dart';
import 'package:dramabox_free/data/datasources/narto_remote_data_source.dart';
import 'package:dramabox_free/data/datasources/shortwave_remote_data_source.dart';
import 'package:dramabox_free/data/models/drama_model.dart';
import 'package:dramabox_free/data/models/drama_section_model.dart';
import 'package:dramabox_free/data/models/episode_model.dart';
import 'package:dramabox_free/data/models/favorite_model.dart';
import 'package:dramabox_free/data/models/history_model.dart';
import 'package:dramabox_free/data/models/narto_provider.dart';

class DramaRepositoryImpl implements DramaRepository {
  final NartoRemoteDataSource nartoDataSource;
  final ShortWaveRemoteDataSource shortwaveDataSource;
  final DramaLocalDataSource localDataSource;

  DramaRepositoryImpl({
    required this.nartoDataSource,
    required this.shortwaveDataSource,
    required this.localDataSource,
  });

  /// Extra pseudo-provider surfaced in the home provider bar, backed by its own
  /// data source instead of narto.
  static const NartoProvider _shortwaveProvider = NartoProvider(
    key: ShortWaveRemoteDataSource.shortWaveProviderKey,
    label: 'ShortWave',
  );

  static const NartoProvider _dramafrenDramaboxProvider = NartoProvider(
    key: ShortWaveRemoteDataSource.dramafrenDramaboxProviderKey,
    label: 'DramaFren Box',
  );

  static const NartoProvider _shortflixProvider = NartoProvider(
    key: ShortWaveRemoteDataSource.shortflixProviderKey,
    label: 'ShortFlix',
  );

  static const NartoProvider _shortdizilabProvider = NartoProvider(
    key: ShortWaveRemoteDataSource.shortdizilabProviderKey,
    label: 'ShortDiziLab',
  );

  static const NartoProvider _dramaexpressProvider = NartoProvider(
    key: ShortWaveRemoteDataSource.dramaexpressProviderKey,
    label: 'DramaExpress',
  );

  bool _isEmbeddedSite(String? nartoProviderKey) =>
      nartoProviderKey == ShortWaveRemoteDataSource.shortWaveProviderKey ||
      nartoProviderKey ==
          ShortWaveRemoteDataSource.dramafrenDramaboxProviderKey ||
      nartoProviderKey == ShortWaveRemoteDataSource.shortflixProviderKey ||
      nartoProviderKey == ShortWaveRemoteDataSource.shortdizilabProviderKey ||
      nartoProviderKey == ShortWaveRemoteDataSource.dramaexpressProviderKey;

  List<NartoProvider> _withEmbeddedSites(List<NartoProvider> providers) {
    final result = [...providers];
    for (final p in [
      _shortwaveProvider,
      _dramafrenDramaboxProvider,
      _shortflixProvider,
      _shortdizilabProvider,
      _dramaexpressProvider,
    ]) {
      if (!result.any((e) => e.key == p.key)) result.add(p);
    }
    return result;
  }

  String _getCacheKey(
    String baseKey,
    AppContentProvider provider, {
    String? nartoProviderKey,
  }) {
    final subKey = (nartoProviderKey != null && nartoProviderKey.isNotEmpty)
        ? '${nartoProviderKey}_'
        : '';
    return '$subKey${provider.name}_$baseKey';
  }

  Future<List<DramaSectionModel>> _fetchSections(
    AppContentProvider provider, {
    String? nartoProviderKey,
  }) {
    if (_isEmbeddedSite(nartoProviderKey)) {
      return shortwaveDataSource.getHomeSections();
    }
    return nartoDataSource.getHomeSections(providerKey: nartoProviderKey);
  }

  @override
  Future<NartoHomeData> getNartoHomeData({String? nartoProviderKey}) async {
    final data = await nartoDataSource.getHomeData(providerKey: nartoProviderKey);
    final key = data.activeProvider;
    if (key.isNotEmpty) {
      final cacheKey = _getCacheKey(
        'home_sections',
        AppContentProvider.narto,
        nartoProviderKey: key,
      );
      await localDataSource.cacheSections(cacheKey, data.sections);
    }
    return NartoHomeData(
      providers: _withEmbeddedSites(data.providers),
      activeProvider: data.activeProvider,
      sections: data.sections,
      sectionsWithKeys: data.sectionsWithKeys,
    );
  }

  @override
  Future<NartoProviderCatalog> getNartoProviders() async {
    final catalog = await nartoDataSource.getProviderCatalog();
    return NartoProviderCatalog(
      providers: _withEmbeddedSites(catalog.providers),
      activeProvider: catalog.activeProvider,
    );
  }

  @override
  Future<List<DramaSectionModel>> getHomeSections({
    AppContentProvider provider = AppContentProvider.narto,
    String? nartoProviderKey,
  }) async {
    final cacheKey = _getCacheKey(
      'home_sections',
      provider,
      nartoProviderKey: nartoProviderKey,
    );
    final sections = await _fetchSections(
      provider,
      nartoProviderKey: nartoProviderKey,
    );
    await localDataSource.cacheSections(cacheKey, sections);
    return sections;
  }

  @override
  Future<List<DramaSectionModel>?> getCachedHomeSections({
    AppContentProvider provider = AppContentProvider.narto,
    String? nartoProviderKey,
  }) async {
    final cacheKey = _getCacheKey(
      'home_sections',
      provider,
      nartoProviderKey: nartoProviderKey,
    );
    return await localDataSource.getCachedSections(cacheKey);
  }

  @override
  Future<List<DramaModel>> getTrendingDramas({
    AppContentProvider provider = AppContentProvider.narto,
    int page = 1,
  }) async {
    try {
      final remoteDramas = await _fetchSections(provider);
      final trending = remoteDramas.length > 2 ? remoteDramas[2].dramas : <DramaModel>[];
      if (page == 1) {
        await localDataSource.cacheTrendingDramas(trending);
      }
      return trending;
    } catch (e) {
      if (page == 1) {
        final cached = await localDataSource.getTrendingDramas();
        if (cached != null) return cached;
      }
      rethrow;
    }
  }

  @override
  Future<List<DramaModel>> getForYouDramas({
    AppContentProvider provider = AppContentProvider.narto,
    String? nartoProviderKey,
    int page = 1,
    String tabKey = 'for-you',
  }) async {
    try {
      if (_isEmbeddedSite(nartoProviderKey)) {
        final sections = await _fetchSections(
          provider,
          nartoProviderKey: nartoProviderKey,
        );
        if (sections.isNotEmpty) return sections[0].dramas;
        return [];
      }
      return await nartoDataSource.getTabDramas(
        providerKey: nartoProviderKey,
        tabKey: tabKey,
        page: page,
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<DramaModel>> getLatestDramas({
    AppContentProvider provider = AppContentProvider.narto,
    int page = 1,
  }) async {
    try {
      final remoteDramas = await _fetchSections(provider);
      final latest = remoteDramas.length > 1 ? remoteDramas[1].dramas : <DramaModel>[];
      if (page == 1) {
        await localDataSource.cacheLatestDramas(latest);
      }
      return latest;
    } catch (e) {
      if (page == 1) {
        final cached = await localDataSource.getLatestDramas();
        if (cached != null) return cached;
      }
      rethrow;
    }
  }

  @override
  Future<List<DramaModel>> getVipDramas({
    AppContentProvider provider = AppContentProvider.narto,
    int page = 1,
  }) async {
    try {
      final remoteDramas = await _fetchSections(provider);
      final vip = remoteDramas.length > 3 ? remoteDramas[3].dramas : <DramaModel>[];
      if (page == 1) {
        await localDataSource.cacheVipDramas(vip);
      }
      return vip;
    } catch (e) {
      if (page == 1) {
        final cached = await localDataSource.getVipDramas();
        if (cached != null) return cached;
      }
      rethrow;
    }
  }

  @override
  Future<List<DramaModel>?> getCachedTrendingDramas({
    AppContentProvider provider = AppContentProvider.narto,
  }) async {
    return await localDataSource.getTrendingDramas();
  }

  @override
  Future<List<DramaModel>?> getCachedLatestDramas({
    AppContentProvider provider = AppContentProvider.narto,
  }) async {
    return await localDataSource.getLatestDramas();
  }

  @override
  Future<List<DramaModel>?> getCachedVipDramas({
    AppContentProvider provider = AppContentProvider.narto,
  }) async {
    return await localDataSource.getVipDramas();
  }

  @override
  Future<List<DramaModel>> searchDramas(
    String query, {
    AppContentProvider provider = AppContentProvider.narto,
    String? nartoProviderKey,
  }) {
    if (_isEmbeddedSite(nartoProviderKey)) {
      return shortwaveDataSource.searchDramas(query);
    }
    return nartoDataSource.searchDramas(
      query,
      providerKey: nartoProviderKey,
    );
  }

  @override
  Future<List<EpisodeModel>> getDramaEpisodes(
    String bookId, {
    AppContentProvider provider = AppContentProvider.narto,
    String? nartoProviderKey,
  }) async {
    final cacheKey = _getCacheKey(bookId, provider, nartoProviderKey: nartoProviderKey);
    final cached = await localDataSource.getEpisodes(cacheKey);
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    final List<EpisodeModel> remoteEpisodes;
    if (_isEmbeddedSite(nartoProviderKey)) {
      remoteEpisodes = await shortwaveDataSource.getDramaEpisodes(bookId);
    } else {
      remoteEpisodes = await nartoDataSource.getDramaEpisodes(
        bookId,
        providerKey: nartoProviderKey,
      );
    }
    if (remoteEpisodes.isNotEmpty) {
      await localDataSource.cacheEpisodes(cacheKey, remoteEpisodes);
    }
    return remoteEpisodes;
  }

  @override
  Future<void> saveLastWatchedIndex(
    String bookId,
    int index, {
    int position = 0,
    int duration = 0,
    AppContentProvider provider = AppContentProvider.narto,
  }) async {
    final cacheKey = _getCacheKey(bookId, provider);
    await localDataSource.saveLastWatchedIndex(
      cacheKey,
      index,
      position: position,
      duration: duration,
    );
  }

  @override
  Future<int> getLastWatchedIndex(
    String bookId, {
    AppContentProvider provider = AppContentProvider.narto,
  }) async {
    final cacheKey = _getCacheKey(bookId, provider);
    return localDataSource.getLastWatchedIndex(cacheKey);
  }

  @override
  Future<Map<String, dynamic>?> getEpisodeProgress(
    String bookId,
    int episodeIndex, {
    AppContentProvider provider = AppContentProvider.narto,
  }) async {
    final cacheKey = _getCacheKey(bookId, provider);
    return await localDataSource.getEpisodeProgress(cacheKey, episodeIndex);
  }

  @override
  Future<int> getLocalLastWatchedIndex(String bookId) async {
    for (final provider in AppContentProvider.values) {
      final key = _getCacheKey(bookId, provider);
      final index = await localDataSource.getLastWatchedIndex(key);
      if (index >= 0) return index;
    }
    return await localDataSource.getLastWatchedIndex(bookId);
  }

  @override
  Future<void> saveHistory(HistoryModel history) async {
    return localDataSource.saveHistory(history);
  }

  @override
  Future<List<HistoryModel>> getHistory() async {
    return localDataSource.getHistory();
  }

  @override
  Future<List<FavoriteModel>> getFavorites() async {
    return localDataSource.getFavorites();
  }

  @override
  Future<void> saveFavorite(FavoriteModel favorite) async {
    return localDataSource.saveFavorite(favorite);
  }

  @override
  Future<void> removeFavorite(
    String bookId,
    AppContentProvider provider,
  ) async {
    return localDataSource.removeFavorite(bookId, provider);
  }

  @override
  Future<bool> isFavorite(String bookId, AppContentProvider provider) async {
    return localDataSource.isFavorite(bookId, provider);
  }
}
