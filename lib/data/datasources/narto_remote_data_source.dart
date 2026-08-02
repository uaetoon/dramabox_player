import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:dramabox_free/core/utils/isolate_parser.dart';
import 'package:dramabox_free/data/models/drama_model.dart';
import 'package:dramabox_free/data/models/drama_section_model.dart';
import 'package:dramabox_free/data/models/episode_model.dart';
import 'package:dramabox_free/data/models/narto_provider.dart';

class NartoRemoteDataSource {
  final Dio dio;
  NartoProviderCatalog? _cachedCatalog;

  NartoRemoteDataSource()
    : dio = Dio(
        BaseOptions(
          baseUrl: 'https://narto-drama.com',
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 12) QuickPlay/1.0.0',
            'Accept-Language': 'ar-SA,ar;q=0.9,en;q=0.8',
            'Accept': 'application/json',
            'X-Requested-With': 'XMLHttpRequest',
          },
        ),
      );

  static const String _lang = 'ar-SA';

  /// Language code for providers whose feed has no Arabic content at all. On
  /// the site, switching such a provider to English shows every drama
  /// (including Arabic ones); the `ar-SA` feed only surfaces a subset of
  /// untranslated (Indonesian/English) titles.
  static const String _fullCatalogLang = 'en-US';

  /// Provider keys (lowercased) whose `ar-SA` feed contains no Arabic titles
  /// and therefore serve the full `en-US` catalog. Populated dynamically the
  /// first time each provider's home data is loaded.
  final Set<String> _fullCatalogProviders = {};

  /// The narto API language code for a provider. Once a provider is detected
  /// to have no Arabic content it uses English so the whole catalog is listed;
  /// every other provider stays Arabic.
  String _langFor(String? providerKey) {
    final key = providerKey?.toLowerCase() ?? '';
    if (_fullCatalogProviders.contains(key)) return _fullCatalogLang;
    return _lang;
  }

  Future<NartoProviderCatalog> getProviderCatalog() async {
    final cached = _cachedCatalog;
    if (cached != null) return cached;
    final data = await getHomeData();
    return NartoProviderCatalog(
      providers: data.providers,
      activeProvider: data.activeProvider,
    );
  }

  Future<List<DramaSectionModel>> getHomeSections({String? providerKey}) async {
    final data = await getHomeData(providerKey: providerKey);
    _cachedCatalog ??= NartoProviderCatalog(
      providers: data.providers,
      activeProvider: data.activeProvider,
    );
    return data.sections;
  }

  Future<NartoHomeData> getHomeData({String? providerKey}) async {
    final response = await dio.get<String>(
      '/home/providers/sections',
      queryParameters: {
        if (providerKey != null && providerKey.isNotEmpty)
          'provider': providerKey,
        'lang': _lang,
        'target_lang': _lang,
      },
      options: Options(responseType: ResponseType.plain),
    );
    final body = response.data ?? '';
    if (body.isEmpty) {
      return const NartoHomeData(providers: [], activeProvider: '', sections: []);
    }
    var data = await compute(_parseHomeJson, body);
    debugPrint(
      'Narto: loaded ${data.providers.length} providers, active=${data.activeProvider}, ${data.sections.length} sections',
    );
    // Providers without any Arabic content serve the full English catalog so
    // every drama is listed; the ar-SA feed only surfaces a subset of
    // untranslated (Indonesian/English) titles.
    if (!_hasArabicSections(data.sections)) {
      final key = providerKey?.toLowerCase() ?? '';
      _fullCatalogProviders.add(key);
      final englishResponse = await dio.get<String>(
        '/home/providers/sections',
        queryParameters: {
          if (providerKey != null && providerKey.isNotEmpty)
            'provider': providerKey,
          'lang': _fullCatalogLang,
          'target_lang': _fullCatalogLang,
        },
        options: Options(responseType: ResponseType.plain),
      );
      final englishBody = englishResponse.data ?? '';
      if (englishBody.isNotEmpty) {
        final englishData = await compute(_parseHomeJson, englishBody);
        if (englishData.sections.isNotEmpty) {
          data = englishData;
          debugPrint(
            'Narto: provider $providerKey has no Arabic feed, '
            'using full English catalog (${englishData.sections.length} sections)',
          );
        }
      }
    }
    return data;
  }

  /// Fetches a specific tab page for a provider. The narto sections endpoint
  /// paginates per-tab via `only_tab=<tab>&tab_pages[<tab>]=<page>`; a plain
  /// `page` param is ignored by the server. Returns the dramas on that page
  /// (empty when the tab is exhausted).
  Future<List<DramaModel>> getTabDramas({
    String? providerKey,
    String tabKey = 'for-you',
    int page = 1,
  }) async {
    final response = await dio.get<String>(
      '/home/providers/sections',
      queryParameters: {
        if (providerKey != null && providerKey.isNotEmpty)
          'provider': providerKey,
        'lang': _langFor(providerKey),
        'target_lang': _langFor(providerKey),
        'only_tab': tabKey,
        'tab_pages[$tabKey]': page,
      },
      options: Options(responseType: ResponseType.plain),
    );
    final body = response.data ?? '';
    if (body.isEmpty) return const <DramaModel>[];
    final data = await compute(_parseHomeJson, body);
    if (data.sections.isEmpty) return const <DramaModel>[];
    return data.sections.first.dramas;
  }

  /// Returns raw sections retaining tab key/label for a provider.
  Future<List<NartoSection>> getSectionsWithKeys({String? providerKey}) async {
    final data = await getHomeData(providerKey: providerKey);
    _cachedCatalog ??= NartoProviderCatalog(
      providers: data.providers,
      activeProvider: data.activeProvider,
    );
    return data.sectionsWithKeys;
  }

  Future<List<DramaModel>> searchDramas(
    String query, {
    String? providerKey,
  }) async {
    final response = await dio.get<String>(
      '/search',
      queryParameters: {
        'q': query,
        'limit': 50,
        'lang': _langFor(providerKey),
        if (providerKey != null && providerKey.isNotEmpty)
          'providers': providerKey,
      },
      options: Options(responseType: ResponseType.plain),
    );
    final body = response.data ?? '';
    if (body.isEmpty) return const <DramaModel>[];
    return compute(_parseSearchJson, body);
  }

  /// Scrapes server-rendered genre listing pages (e.g. `/genre/adult`).
  Future<List<DramaModel>> getGenreDramas(
    String genre, {
    int maxPages = 3,
  }) async {
    final result = <DramaModel>[];
    for (var page = 1; page <= maxPages; page++) {
      try {
        final response = await dio.get<String>(
          '/genre/$genre',
          queryParameters: {
            'lang': _lang,
            if (page > 1) 'page': page,
          },
          options: Options(responseType: ResponseType.plain),
        );
        final html = response.data ?? '';
        if (html.isEmpty) break;

        final dramaPattern = RegExp(
          r'<article\s+class="card"[\s\S]*?data-watch-url="([^"]+)"[\s\S]*?data-movie-title="([^"]+)"[\s\S]*?<img class="poster" src="([^"]+)"',
        );
        var count = 0;
        for (final match in dramaPattern.allMatches(html)) {
          final watchUrl = match.group(1)?.replaceAll('&amp;', '&') ?? '';
          final title = match.group(2)?.replaceAll('&amp;', '&') ?? '';
          final posterSrc = match.group(3) ?? '';
          if (watchUrl.isEmpty || title.isEmpty) continue;
          final cover = posterSrc.startsWith('http')
              ? posterSrc
              : 'https://narto-drama.com$posterSrc';
          result.add(
            DramaModel(
              bookId: watchUrl,
              bookName: title,
              coverWap: cover,
              introduction: '',
              tags: const ['#Adult'],
              protagonist: '',
              chapterCount: 0,
            ),
          );
          count++;
        }
        if (count == 0) break;
      } catch (e) {
        debugPrint('Narto: genre $genre page $page error: $e');
        break;
      }
    }
    debugPrint('Narto: genre $genre scraped ${result.length} dramas');
    return result;
  }

  Future<List<EpisodeModel>> getDramaEpisodes(
    String watchUrl, {
    String? providerKey,
  }) async {
    final slug = await _resolveSlug(watchUrl);
    if (slug == null) {
      debugPrint('Narto: failed to resolve slug for $watchUrl');
      return [];
    }

    final response = await dio.get<String>(
      '/detail/watch/$slug/1',
      queryParameters: {'lang': _langFor(providerKey)},
      options: Options(responseType: ResponseType.plain),
    );
    final html = response.data ?? '';
    final match = RegExp(
      r'episodeItemsRaw\s*=\s*(\[.*?\]);',
      dotAll: true,
    ).firstMatch(html);
    if (match == null) return [];

    final dynamic decoded = await IsolateParser.parseJson(match.group(1)!);
    if (decoded is! List) return [];

    final episodes = <EpisodeModel>[];
    for (var i = 0; i < decoded.length; i++) {
      final e = decoded[i];
      if (e is! Map<String, dynamic>) continue;

      final playUrl =
          e['play_url']?.toString() ?? e['direct_play_url']?.toString() ?? '';
      final directUrl = e['direct_play_url']?.toString() ?? '';

      final subtitles = _extractSubtitles(e);
      episodes.add(
        EpisodeModel(
          chapterId: e['id']?.toString() ??
              e['number']?.toString() ??
              '${i + 1}',
          chapterName: e['title']?.toString() ??
              e['number']?.toString() ??
              'EP ${i + 1}',
          videoUrl: playUrl,
          alternateVideoUrl: directUrl == playUrl ? '' : directUrl,
          chapterImg: e['thumb_url']?.toString() ?? '',
          subtitles: subtitles,
          isPlayable: playUrl.isNotEmpty,
        ),
      );
    }
    debugPrint('Narto: loaded ${episodes.length} episodes for $slug');
    return episodes;
  }

  Future<String?> _resolveSlug(String watchUrl) async {
    final direct = _extractSlug(watchUrl);
    if (direct != null) return direct;

    try {
      final response = await dio.get(
        watchUrl,
        options: Options(
          followRedirects: false,
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null && status < 400,
        ),
      );
      final location = response.headers.value('location') ?? '';
      debugPrint('Narto: import ${response.statusCode} location=$location');
      return _extractSlug(location);
    } catch (e) {
      debugPrint('Narto: import request error: $e');
      return null;
    }
  }

  String? _extractSlug(String url) {
    final match = RegExp(r'detail/watch/([a-z0-9-]+)').firstMatch(url);
    return match?.group(1);
  }

  List<SubtitleModel> _extractSubtitles(Map<String, dynamic> json) {
    final subtitles = <SubtitleModel>[];

    String abs(String url) =>
        url.startsWith('http') ? url : 'https://narto-drama.com${url.startsWith('/') ? url : '/$url'}';

    final subtitleUrl = json['subtitle_url']?.toString() ?? '';
    if (subtitleUrl.isNotEmpty) {
      subtitles.add(
        SubtitleModel(
          url: abs(subtitleUrl),
          format: subtitleUrl.endsWith('.srt') ? 'srt' : 'vtt',
          language: json['selected_subtitle_language']?.toString() ?? 'ar',
        ),
      );
    }

    final multi = json['multi_subtitles'];
    if (multi is List) {
      for (final s in multi.whereType<Map<String, dynamic>>()) {
        final url = s['url']?.toString() ?? s['subtitle_url']?.toString() ?? '';
        if (url.isEmpty) continue;
        final absUrl = abs(url);
        if (subtitles.any((sub) => sub.url == absUrl)) continue;
        subtitles.add(
          SubtitleModel(
            url: absUrl,
            format: url.endsWith('.srt') ? 'srt' : 'vtt',
            language: s['language_code']?.toString() ??
                s['language']?.toString() ??
                'ar',
          ),
        );
      }
    }
    return subtitles;
  }
}

DramaModel _dramaFromJson(Map<String, dynamic> json) {
  final tags = json['tag_names'] ?? json['tags'];
  final category = json['category_name']?.toString() ?? '';
  var cover = json['poster_url']?.toString() ?? json['poster']?.toString() ?? '';
  if (cover.startsWith('/')) {
    cover = 'https://narto-drama.com$cover';
  }
  return DramaModel(
    bookId: json['watch_url']?.toString() ??
        json['url']?.toString() ??
        json['id']?.toString() ??
        '',
    bookName: json['title']?.toString() ?? json['name']?.toString() ?? '',
    coverWap: cover,
    introduction: json['description']?.toString() ?? '',
    tags: tags is List
        ? List<String>.from(tags)
        : (category.isNotEmpty ? [category] : const []),
    protagonist: '',
    chapterCount: 0,
    hotCode: null,
  );
}

/// Returns true when any section drama title contains Arabic script.
bool _hasArabicSections(List<DramaSectionModel> sections) {
  final arabic = RegExp(r'[\u0600-\u06FF]');
  for (final section in sections) {
    for (final drama in section.dramas) {
      if (arabic.hasMatch(drama.bookName)) return true;
    }
  }
  return false;
}

/// Decodes + maps a `/home/providers/sections` payload off the main isolate.
NartoHomeData _parseHomeJson(String jsonString) {
  final dynamic data;
  try {
    data = jsonDecode(jsonString);
  } catch (_) {
    return const NartoHomeData(providers: [], activeProvider: '', sections: []);
  }
  if (data is! Map) {
    return const NartoHomeData(providers: [], activeProvider: '', sections: []);
  }

  final providers = <NartoProvider>[];
  final providersRaw = data['providers'];
  if (providersRaw is List) {
    for (final p in providersRaw.whereType<Map<String, dynamic>>()) {
      final provider = NartoProvider.fromJson(p);
      if (provider.key.isNotEmpty) providers.add(provider);
    }
  }

  final activeProvider = data['active_provider']?.toString() ?? '';

  final sections = <DramaSectionModel>[];
  final sectionsWithKeys = <NartoSection>[];
  final sectionsRaw = data['sections'];
  if (sectionsRaw is List) {
    for (final section in sectionsRaw.whereType<Map<String, dynamic>>()) {
      final items = section['items'];
      if (items is! List || items.isEmpty) continue;

      final dramas = items
          .whereType<Map<String, dynamic>>()
          .map(_dramaFromJson)
          .where((d) => d.bookId.isNotEmpty)
          .toList();
      if (dramas.isEmpty) continue;

      final tabKey = section['tab_key']?.toString() ?? '';
      final tabLabel = section['tab_label']?.toString() ?? 'For You';
      sectionsWithKeys.add(
        NartoSection(tabKey: tabKey, tabLabel: tabLabel, dramas: dramas),
      );
      sections.add(
        DramaSectionModel(
          name: tabKey == 'for-you' ? 'For You' : tabLabel,
          dramas: dramas,
          hasMore: tabKey == 'for-you',
        ),
      );
    }
  }
  return NartoHomeData(
    providers: providers,
    activeProvider: activeProvider,
    sections: sections,
    sectionsWithKeys: sectionsWithKeys,
  );
}

/// Decodes + maps a `/search` payload off the main isolate.
List<DramaModel> _parseSearchJson(String jsonString) {
  final dynamic data;
  try {
    data = jsonDecode(jsonString);
  } catch (_) {
    return const <DramaModel>[];
  }
  if (data is! Map) return const <DramaModel>[];
  final items = data['items'];
  if (items is! List) return const <DramaModel>[];
  return items
      .whereType<Map<String, dynamic>>()
      .map(_dramaFromJson)
      .where((d) => d.bookId.isNotEmpty)
      .toList();
}
