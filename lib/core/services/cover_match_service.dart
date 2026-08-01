import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:dramabox_free/data/datasources/narto_remote_data_source.dart';
import 'package:dramabox_free/data/models/drama_model.dart';

/// Finds the same drama on other platforms by perceptual cover matching (dHash).
class CoverMatchService {
  final NartoRemoteDataSource remote;
  final Dio dio;

  static const String _boxName = 'cover_hash_cache';
  // Tuned on real data: re-encoded/cropped cross-provider covers of the same
  // drama land in the 12-19 bit range, so 10 missed actual duplicates.
  static const int _hashThreshold = 16; // out of 64 bits
  static const int _concurrency = 6;
  static const int _maxCandidatesPerProvider = 60;

  final Map<String, String> _hashCache = {};
  final Map<String, List<DramaModel>> _resultsCache = {};
  Future<Box>? _boxFuture;

  CoverMatchService({required this.remote})
    : dio = Dio(
        BaseOptions(
          baseUrl: 'https://narto-drama.com',
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 30),
          responseType: ResponseType.bytes,
          headers: {
            'User-Agent': 'Mozilla/5.0 (Linux; Android 12) QuickPlay/1.0.0',
          },
        ),
      );

  Future<Box> _box() {
    return _boxFuture ??= Hive.openBox(_boxName);
  }

  /// Streams matches progressively as each provider is scanned. Caches the
  /// final result per target bookId for the session.
  Stream<List<DramaModel>> match({
    required String bookId,
    required String coverWap,
    String excludeProvider = '',
  }) async* {
    final cached = _resultsCache[bookId];
    if (cached != null) {
      yield cached;
      return;
    }

    final targetHash = await _hashFor(coverWap);
    if (targetHash == null || targetHash.length != 64) {
      yield const [];
      return;
    }

    final catalog = await remote.getProviderCatalog();
    final providers = excludeProvider.isEmpty
        ? catalog.providers
        : catalog.providers
              .where((p) => p.key != excludeProvider)
              .toList();

    final matches = <DramaModel>[];
    final seenIds = <String>{};
    var scanned = 0;
    var totalHashed = 0;
    var minDistance = 64;
    for (final provider in providers) {
      scanned++;
      List<(DramaModel, String)> hashed;
      try {
        final sections = await remote
            .getSectionsWithKeys(providerKey: provider.key)
            .timeout(const Duration(seconds: 45));
        var candidates = sections.expand((s) => s.dramas).toList();
        if (candidates.length > _maxCandidatesPerProvider) {
          candidates = candidates.sublist(0, _maxCandidatesPerProvider);
        }
        hashed = await _hashCandidates(candidates).timeout(
          const Duration(seconds: 120),
        );
      } catch (e) {
        debugPrint('CoverMatch: provider ${provider.key} error: $e');
        continue;
      }

      for (final entry in hashed) {
        final drama = entry.$1;
        final hash = entry.$2;
        if (drama.bookId == bookId) continue;
        totalHashed++;
        final distance = _hamming(targetHash, hash);
        if (distance < minDistance) minDistance = distance;
        if (distance > _hashThreshold) continue;
        if (seenIds.contains(drama.bookId)) continue;
        seenIds.add(drama.bookId);
        matches.add(drama);
      }

      // Emit progress every provider or on first matches.
      if (matches.isNotEmpty || scanned == providers.length) {
        yield List.unmodifiable(matches);
      }
    }

    _resultsCache[bookId] = List.unmodifiable(matches);
    debugPrint(
      'CoverMatch: done bookId=$bookId matches=${matches.length} '
      'providers=$scanned hashed=$totalHashed minDist=$minDistance',
    );
  }

  Future<List<(DramaModel, String)>> _hashCandidates(
    List<DramaModel> candidates,
  ) async {
    final result = <(DramaModel, String)>[];
    for (var i = 0; i < candidates.length; i += _concurrency) {
      final chunk = candidates.sublist(
        i,
        i + _concurrency > candidates.length
            ? candidates.length
            : i + _concurrency,
      );
      final chunkResults = await Future.wait(
        chunk.map((d) async {
          final hash = await _hashFor(d.coverWap);
          if (hash == null) return null;
          return (d, hash);
        }),
      );
      for (final r in chunkResults) {
        if (r != null) result.add(r);
      }
    }
    return result;
  }

  Future<String?> _hashFor(String coverWap) async {
    if (coverWap.isEmpty) return null;
    final cached = _hashCache[coverWap];
    if (cached != null) return cached;

    final box = await _box();
    final persisted = box.get(_cacheKey(coverWap));
    if (persisted is String && persisted.isNotEmpty) {
      _hashCache[coverWap] = persisted;
      return persisted;
    }

    Uint8List? bytes;
    try {
      final response = await dio.get<List<int>>(coverWap);
      bytes = Uint8List.fromList(response.data ?? const []);
    } catch (e) {
      debugPrint('CoverMatch: fetch ${coverWap.length > 60 ? coverWap.substring(0, 60) : coverWap}: $e');
      return null;
    }

    final hash = await compute(_dHashIsolate, bytes);
    if (hash == null) return null;
    _hashCache[coverWap] = hash;
    await box.put(_cacheKey(coverWap), hash);
    return hash;
  }

  /// Hive keys max out at 255 chars; map arbitrary cover URLs to a short
  /// 64-bit FNV-1a hash instead of storing the URL verbatim.
  String _cacheKey(String url) {
    var hash = 0xcbf29ce484222325;
    for (final unit in url.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16);
  }

  int _hamming(String a, String b) {
    var distance = 0;
    for (var i = 0; i < a.length && i < b.length; i++) {
      if (a[i] != b[i]) distance++;
    }
    return distance;
  }
}

String? _dHashIsolate(Uint8List bytes) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final small = img.copyResize(
      decoded,
      width: 9,
      height: 8,
      interpolation: img.Interpolation.average,
    );
    final gray = img.grayscale(small);
    final buffer = StringBuffer();
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        final left = gray.getPixel(x, y).r.toInt();
        final right = gray.getPixel(x + 1, y).r.toInt();
        buffer.write(left > right ? '1' : '0');
      }
    }
    return buffer.toString();
  } catch (e) {
    return null;
  }
}
