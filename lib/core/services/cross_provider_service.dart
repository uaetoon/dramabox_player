import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dramabox_free/data/datasources/narto_remote_data_source.dart';
import 'package:dramabox_free/data/models/drama_model.dart';
import 'package:dramabox_free/data/models/drama_section_model.dart';

/// Aggregates content across all narto platforms for the "Dubbed" and "18+"
/// special provider pills.
class CrossProviderService {
  final NartoRemoteDataSource remote;

  /// Known special pseudo-provider keys injected into the home provider row.
  static const String dubbedKey = '__dubbed__';
  static const String adultKey = '__adult__';

  static const List<String> adultSectionLabels = [
    '🍆💦',
    'adult',
    'adults',
    '18+',
    'رجال',
    'نساء',
    'إناث',
    'ذكور',
    'الكبار',
    'erotic',
    'sex',
    'قسم الرجال',
    'قسم النساء',
  ];

  static const List<String> dubbedSectionLabels = [
    'مدبلج',
    'دبلجة',
    'dubbed',
    'sulih suara',
    'dubbing',
  ];

  List<DramaSectionModel>? _dubbedCache;
  List<DramaSectionModel>? _adultCache;
  Future<List<DramaSectionModel>>? _dubbedFuture;
  Future<List<DramaSectionModel>>? _adultFuture;

  CrossProviderService({required this.remote});

  bool _isAdultSection(String tabKey, String tabLabel) {
    final lower = tabLabel.toLowerCase();
    return adultSectionLabels.any(
      (label) => lower.contains(label.toLowerCase()),
    );
  }

  bool _isDubbedSection(String tabKey, String tabLabel) {
    final lower = tabLabel.toLowerCase();
    return dubbedSectionLabels.any(
      (label) => lower.contains(label.toLowerCase()),
    );
  }

  /// Scans every provider's default tabs once and classifies them.
  Future<({List<DramaModel> dubbed, List<DramaModel> adult})>
  _scanAllProviders() async {
    final catalog = await remote.getProviderCatalog();
    final providers = catalog.providers;
    final results = await Future.wait(
      providers.map((p) async {
        try {
          final sections = await remote
              .getSectionsWithKeys(providerKey: p.key)
              .timeout(const Duration(seconds: 30));
          final dubbed = <DramaModel>[];
          final adult = <DramaModel>[];
          for (final section in sections) {
            if (_isDubbedSection(section.tabKey, section.tabLabel)) {
              dubbed.addAll(_tag(section.dramas, p.key));
            }
            if (_isAdultSection(section.tabKey, section.tabLabel)) {
              adult.addAll(_tag(section.dramas, p.key));
            }
          }
          return (dubbed: dubbed, adult: adult);
        } catch (e) {
          // Skip providers that fail; aggregation is best-effort.
          return (dubbed: const <DramaModel>[], adult: const <DramaModel>[]);
        }
      }),
    );

    final allDubbed = <DramaModel>[];
    final allAdult = <DramaModel>[];
    for (final r in results) {
      allDubbed.addAll(r.dubbed);
      allAdult.addAll(r.adult);
    }
    debugPrint(
      'CoverAgg: scanned ${providers.length} providers, '
      'dubbed=${allDubbed.length} adult=${allAdult.length}',
    );
    return (dubbed: allDubbed, adult: allAdult);
  }

  List<DramaModel> _tag(List<DramaModel> dramas, String key) {
    return dramas
        .map((d) => d.nartoProviderKey == key
            ? d
            : d.copyWith(nartoProviderKey: key))
        .toList();
  }

  Future<List<DramaSectionModel>> getDubbedSections() {
    final cached = _dubbedCache;
    if (cached != null) return Future.value(cached);
    final existing = _dubbedFuture;
    if (existing != null) return existing;

    final future = () async {
      final scanned = await _scanAllProviders();
      final deduped = _dedupe(scanned.dubbed);
      final sections = deduped.isEmpty
          ? const <DramaSectionModel>[]
          : [
              DramaSectionModel(
                name: 'Dubbed',
                dramas: deduped,
                hasMore: false,
              ),
            ];
      _dubbedCache = sections;
      return sections;
    }();
    _dubbedFuture = future;
    future.whenComplete(() => _dubbedFuture = null);
    return future;
  }

  Future<List<DramaSectionModel>> getAdultSections() {
    final cached = _adultCache;
    if (cached != null) return Future.value(cached);
    final existing = _adultFuture;
    if (existing != null) return existing;

    final future = () async {
      final scanned = await _scanAllProviders();
      final genreDramas = await remote
          .getGenreDramas('adult')
          .timeout(const Duration(seconds: 45));
      final tagged = genreDramas
          .map((d) => d.nartoProviderKey.isEmpty
              ? d.copyWith(nartoProviderKey: 'narto')
              : d)
          .toList();
      final merged = [...scanned.adult, ...tagged];
      final deduped = _dedupe(merged);
      final sections = deduped.isEmpty
          ? const <DramaSectionModel>[]
          : [
              DramaSectionModel(
                name: '18+',
                dramas: deduped,
                hasMore: false,
              ),
            ];
      _adultCache = sections;
      return sections;
    }();
    _adultFuture = future;
    future.whenComplete(() => _adultFuture = null);
    return future;
  }

  /// Dedupes by exact cover URL first, falling back to bookId + cover.
  List<DramaModel> _dedupe(List<DramaModel> input) {
    final seenCovers = <String>{};
    final seenIds = <String>{};
    final result = <DramaModel>[];
    for (final d in input) {
      final coverKey = d.coverWap;
      final idKey = '${d.bookId}|${d.coverWap}';
      if (coverKey.isNotEmpty && seenCovers.contains(coverKey)) continue;
      if (seenIds.contains(idKey)) continue;
      if (coverKey.isNotEmpty) seenCovers.add(coverKey);
      seenIds.add(idKey);
      result.add(d);
    }
    return result;
  }

  void invalidate() {
    _dubbedCache = null;
    _adultCache = null;
  }
}
