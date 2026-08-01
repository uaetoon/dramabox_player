import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/drama_model.dart';
import '../models/drama_section_model.dart';
import '../models/episode_model.dart';
import '../models/favorite_model.dart';
import '../models/history_model.dart';
import '../../core/constants/app_enums.dart';

abstract class DramaLocalDataSource {
  Future<void> cacheTrendingDramas(List<DramaModel> dramas);
  Future<List<DramaModel>?> getTrendingDramas();
  Future<void> cacheLatestDramas(List<DramaModel> dramas);
  Future<List<DramaModel>?> getLatestDramas();
  Future<void> cacheVipDramas(List<DramaModel> dramas);
  Future<List<DramaModel>?> getVipDramas();
  Future<void> cacheSections(String key, List<DramaSectionModel> sections);
  Future<List<DramaSectionModel>?> getCachedSections(String key);
  Future<void> cacheEpisodes(String bookId, List<EpisodeModel> episodes);
  Future<List<EpisodeModel>?> getEpisodes(String bookId);
  Future<void> saveLastWatchedIndex(
    String bookId,
    int index, {
    int position = 0,
    int duration = 0,
  });
  Future<int> getLastWatchedIndex(String bookId);
  Future<Map<String, dynamic>?> getEpisodeProgress(String bookId, int index);
  Future<void> saveHistory(HistoryModel history);
  Future<List<HistoryModel>> getHistory();
  Future<void> saveFavorite(FavoriteModel favorite);
  Future<void> removeFavorite(String bookId, AppContentProvider provider);
  Future<bool> isFavorite(String bookId, AppContentProvider provider);
  Future<List<FavoriteModel>> getFavorites();
}

class DramaLocalDataSourceImpl implements DramaLocalDataSource {
  static const String trendingBox = 'trending_cache';
  static const String latestBox = 'latest_cache';
  static const String vipBox = 'vip_cache';
  static const String sectionsBox = 'sections_cache';
  static const String episodesBox = 'episodes_cache';
  static const String progressBox = 'playback_progress';
  static const String historyBox = 'watch_history';
  static const String favoritesBox = 'favorites_box';

  static String _hiveKey(String raw) {
    var hash = 0xcbf29ce484222325;
    for (final unit in raw.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return 'k$hash';
  }

  @override
  Future<void> cacheTrendingDramas(List<DramaModel> dramas) async {
    final box = await Hive.openBox(trendingBox);
    final jsonList = dramas.map((e) => e.toJson()).toList();
    await box.put('trending', jsonEncode(jsonList));
  }

  @override
  Future<List<DramaModel>?> getTrendingDramas() async {
    final box = await Hive.openBox(trendingBox);
    final String? cached = box.get('trending');
    if (cached != null) {
      final List decoded = jsonDecode(cached);
      return decoded.map((e) => DramaModel.fromJson(e)).toList();
    }
    return null;
  }

  @override
  Future<void> cacheLatestDramas(List<DramaModel> dramas) async {
    final box = await Hive.openBox(latestBox);
    final jsonList = dramas.map((e) => e.toJson()).toList();
    await box.put('latest', jsonEncode(jsonList));
  }

  @override
  Future<List<DramaModel>?> getLatestDramas() async {
    final box = await Hive.openBox(latestBox);
    final String? cached = box.get('latest');
    if (cached != null) {
      final List decoded = jsonDecode(cached);
      return decoded.map((e) => DramaModel.fromJson(e)).toList();
    }
    return null;
  }

  @override
  Future<void> cacheVipDramas(List<DramaModel> dramas) async {
    final box = await Hive.openBox(vipBox);
    final jsonList = dramas.map((e) => e.toJson()).toList();
    await box.put('vip', jsonEncode(jsonList));
  }

  @override
  Future<List<DramaModel>?> getVipDramas() async {
    final box = await Hive.openBox(vipBox);
    final String? cached = box.get('vip');
    if (cached != null) {
      final List decoded = jsonDecode(cached);
      return decoded.map((e) => DramaModel.fromJson(e)).toList();
    }
    return null;
  }

  @override
  Future<void> cacheEpisodes(String bookId, List<EpisodeModel> episodes) async {
    final box = await Hive.openBox(episodesBox);
    final jsonList = episodes.map((e) => e.toJson()).toList();
    await box.put(
      _hiveKey(bookId),
      jsonEncode({
        'v': _episodesCacheVersion,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'items': jsonList,
      }),
    );
  }

  static const int _episodesCacheVersion = 3;
  static const Duration _episodesCacheTtl = Duration(hours: 24);

  @override
  Future<List<EpisodeModel>?> getEpisodes(String bookId) async {
    final box = await Hive.openBox(episodesBox);
    final String? cached = box.get(_hiveKey(bookId));
    if (cached == null) return null;
    final dynamic decoded;
    try {
      decoded = jsonDecode(cached);
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;
    if (decoded['v'] != _episodesCacheVersion) return null;
    final updatedAt = decoded['updatedAt'] is int
        ? decoded['updatedAt'] as int
        : 0;
    final age = DateTime.now().millisecondsSinceEpoch - updatedAt;
    if (age > _episodesCacheTtl.inMilliseconds) return null;
    final items = decoded['items'];
    if (items is! List || items.isEmpty) return null;
    return items
        .whereType<Map<String, dynamic>>()
        .map((e) => EpisodeModel.fromJson(e))
        .toList();
  }

  @override
  Future<void> saveLastWatchedIndex(
    String bookId,
    int index, {
    int position = 0,
    int duration = 0,
  }) async {
    final box = await Hive.openBox(progressBox);
    final key = _hiveKey(bookId);
    await box.put(key, index);

    // Save detailed progress for this episode
    final detailKey = '${key}_$index';
    await box.put(detailKey, {
      'position': position,
      'duration': duration,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  @override
  Future<int> getLastWatchedIndex(String bookId) async {
    final box = await Hive.openBox(progressBox);
    final value = box.get(_hiveKey(bookId));
    if (value is int) return value;
    return -1;
  }

  @override
  Future<Map<String, dynamic>?> getEpisodeProgress(
    String bookId,
    int index,
  ) async {
    final box = await Hive.openBox(progressBox);
    final detailKey = '${_hiveKey(bookId)}_$index';
    final value = box.get(detailKey);
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  @override
  Future<void> cacheSections(
    String key,
    List<DramaSectionModel> sections,
  ) async {
    final box = await Hive.openBox(sectionsBox);
    final jsonList = sections.map((e) => e.toJson()).toList();
    await box.put(key, jsonEncode(jsonList));
  }

  @override
  Future<List<DramaSectionModel>?> getCachedSections(String key) async {
    final box = await Hive.openBox(sectionsBox);
    final String? cached = box.get(key);
    if (cached != null) {
      final List decoded = jsonDecode(cached);
      return decoded.map((e) => DramaSectionModel.fromJson(e)).toList();
    }
    return null;
  }

  @override
  Future<void> saveHistory(HistoryModel history) async {
    final box = await Hive.openBox(historyBox);
    final String? cached = box.get('history');
    List<HistoryModel> historyList = [];
    if (cached != null) {
      final List decoded = jsonDecode(cached);
      historyList = decoded.map((e) => HistoryModel.fromJson(e)).toList();
    }

    // Remove existing entry for the same drama to avoid duplicates and move to top
    historyList.removeWhere(
      (e) =>
          e.drama.bookId == history.drama.bookId &&
          e.provider == history.provider,
    );
    historyList.insert(0, history);

    // Keep only last 100 items
    if (historyList.length > 100) {
      historyList = historyList.sublist(0, 100);
    }

    final jsonList = historyList.map((e) => e.toJson()).toList();
    await box.put('history', jsonEncode(jsonList));
  }

  @override
  Future<List<HistoryModel>> getHistory() async {
    final box = await Hive.openBox(historyBox);
    final String? cached = box.get('history');
    if (cached != null) {
      final List decoded = jsonDecode(cached);
      return decoded.map((e) => HistoryModel.fromJson(e)).toList();
    }
    return [];
  }

  @override
  Future<void> saveFavorite(FavoriteModel favorite) async {
    final box = await Hive.openBox(favoritesBox);
    final key = _hiveKey('${favorite.provider.name}_${favorite.drama.bookId}');
    await box.put(key, jsonEncode(favorite.toJson()));
  }

  @override
  Future<void> removeFavorite(
    String bookId,
    AppContentProvider provider,
  ) async {
    final box = await Hive.openBox(favoritesBox);
    await box.delete(_hiveKey('${provider.name}_$bookId'));
  }

  @override
  Future<bool> isFavorite(
    String bookId,
    AppContentProvider provider,
  ) async {
    final box = await Hive.openBox(favoritesBox);
    return box.containsKey(_hiveKey('${provider.name}_$bookId'));
  }

  @override
  Future<List<FavoriteModel>> getFavorites() async {
    final box = await Hive.openBox(favoritesBox);
    final result = <FavoriteModel>[];
    for (final value in box.values) {
      if (value is String) {
        try {
          result.add(FavoriteModel.fromJson(jsonDecode(value)));
        } catch (_) {
          // ignore malformed entries
        }
      }
    }
    result.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return result;
  }
}
