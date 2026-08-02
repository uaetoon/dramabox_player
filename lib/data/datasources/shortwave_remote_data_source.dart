import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:dramabox_free/data/models/drama_model.dart';
import 'package:dramabox_free/data/models/drama_section_model.dart';
import 'package:dramabox_free/data/models/episode_model.dart';

/// Scrapes the ShortWave mirror (shortwave.dramafren.org), a client-side app
/// that exposes a small JSON API behind `?api_route=...`:
///   - list   -> {dramas:[{id,title,cover,episodes|total_episodes}]}
///   - search -> {dramas:[...]}
///   - detail -> {drama:{...}, episodes:[{index,chapter_id}]}
///   - unlock -> {data:{play_url_encoded:[base64], sublist:[{url,language}]}}
///
/// The unlock payload's `play_url_encoded` is a base64-encoded direct stream
/// URL (MP4 or HLS), which is what the in-app player consumes.
class ShortWaveRemoteDataSource {
  final Dio dio;

  ShortWaveRemoteDataSource()
    : dio = Dio(
        BaseOptions(
          baseUrl: 'https://shortwave.dramafren.org',
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 12) QuickPlay/1.0.0',
            'Accept-Language': 'ar,en;q=0.9',
            'Accept': 'application/json, text/plain, */*',
            'Referer': 'https://shortwave.dramafren.org/',
          },
        ),
      );

  /// Provider key used across the app for this platform.
  static const String shortWaveProviderKey = 'shortwave';

  static const int _resolveConcurrency = 6;

  Future<Map<String, dynamic>?> _getApi(
    String route, {
    Map<String, dynamic>? params,
  }) async {
    try {
      final response = await dio.get<dynamic>(
        '/',
        queryParameters: {'api_route': route, 'lang': 'ar', ...?params},
      );
      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data);
      }
    } catch (e) {
      debugPrint('ShortWave: $route failed: $e');
    }
    return null;
  }

  /// Home grid: aggregates the paginated list into a single section so the
  /// home page has a usable feed without extra load-more plumbing.
  Future<List<DramaSectionModel>> getHomeSections() async {
    final dramas = <DramaModel>[];
    const maxPages = 3;
    for (var page = 1; page <= maxPages; page++) {
      final data = await _getApi('list', params: {'page': page});
      final items = data?['dramas'];
      if (items is! List || items.isEmpty) break;
      for (final item in items) {
        if (item is! Map) continue;
        final drama = _dramaFromJson(Map<String, dynamic>.from(item));
        if (drama.bookId.isNotEmpty) dramas.add(drama);
      }
    }
    return [
      DramaSectionModel(name: 'ShortWave', dramas: dramas, hasMore: false),
    ];
  }

  Future<List<DramaModel>> searchDramas(String query) async {
    final data = await _getApi('search', params: {'q': query, 'page': 1});
    final items = data?['dramas'];
    if (items is! List) return [];
    final dramas = <DramaModel>[];
    for (final item in items) {
      if (item is! Map) continue;
      final drama = _dramaFromJson(Map<String, dynamic>.from(item));
      if (drama.bookId.isNotEmpty) dramas.add(drama);
    }
    return dramas;
  }

  DramaModel _dramaFromJson(Map<String, dynamic> json) {
    final drama = DramaModel.fromJson(json);
    final episodeCount =
        int.tryParse(
          (json['episodes'] ?? json['total_episodes'] ?? '').toString(),
        ) ??
        0;
    return drama.copyWith(
      chapterCount: drama.chapterCount > 0 ? drama.chapterCount : episodeCount,
      nartoProviderKey: shortWaveProviderKey,
    );
  }

  /// Detail + unlock: returns episodes with their direct stream URLs resolved
  /// via the unlock endpoint (bounded concurrency). The site's client-side
  /// "wait 60s between episodes" gate is purely localStorage UI, so it is
  /// bypassed.
  Future<List<EpisodeModel>> getDramaEpisodes(String dramaId) async {
    final data = await _getApi('detail', params: {'id': dramaId});
    final raw = data?['episodes'];
    if (raw is! List || raw.isEmpty) return [];

    final chapters = raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final episodes = List<EpisodeModel?>.filled(chapters.length, null);
    var next = 0;

    Future<void> worker() async {
      while (true) {
        final i = next++;
        if (i >= chapters.length) return;
        final chapter = chapters[i];
        final chapterId =
            chapter['chapter_id']?.toString() ?? chapter['id']?.toString() ?? '';
        if (chapterId.isEmpty) continue;
        final index = chapter['index']?.toString() ?? '${i + 1}';
        final playUrl = await _resolvePlayUrl(dramaId, chapterId);
        episodes[i] = EpisodeModel(
          chapterId: chapterId,
          chapterName: 'Episode $index',
          videoUrl: playUrl,
          chapterImg: '',
          subtitles: const [],
          isPlayable: playUrl.isNotEmpty,
        );
      }
    }

    await Future.wait(List.generate(_resolveConcurrency, (_) => worker()));
    return episodes.whereType<EpisodeModel>().toList();
  }

  Future<String> _resolvePlayUrl(String dramaId, String chapterId) async {
    try {
      final data = await _getApi('unlock', params: {
        'drama_id': dramaId,
        'chapter_id': chapterId,
      });
      final encoded =
          (data?['data'] as Map?)?['play_url_encoded']?.toString() ?? '';
      if (encoded.isEmpty) return '';
      return utf8.decode(base64Decode(encoded));
    } catch (e) {
      debugPrint('ShortWave: unlock $dramaId/$chapterId failed: $e');
      return '';
    }
  }
}
