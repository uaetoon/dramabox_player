import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/datasources/download_local_data_source.dart';
import '../../data/models/download_item.dart';

/// Minimal callback contract so the UI can rebuild on progress. The callback
/// receives the updated [DownloadItem] whenever progress advances.
typedef ProgressCallback = void Function(DownloadItem item);

/// Downloads Narto episode MP4s to local app storage with resume support.
///
/// The CDN serves byte ranges (206), so downloads stream in chunks and can be
/// paused/resumed: a partial file is kept and the next request uses a
/// `Range: bytes=<fileLength>-` header to continue from where it stopped.
class DownloadService {
  final DownloadLocalDataSource dataSource;
  final Dio _dio;

  /// Max simultaneous downloads. "Download all episodes" queues the rest and
  /// they auto-start as slots free up.
  static const int maxConcurrentDownloads = 3;

  final Map<String, CancelToken> _activeTokens = {};

  final List<_QueuedDownload> _pending = [];
  int _activeCount = 0;

  DownloadService({required this.dataSource})
      : _dio = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 30),
            followRedirects: true,
          ),
        );

  static String sanitizeFileName(String input) {
    return input.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }

  /// Stable short hash so filenames never exceed the filesystem limit even
  /// when `bookId` is a full import URL (e.g. CubeTV's /search/import?...).
  static String _shortHash(String input) {
    var hash = 0;
    for (final code in input.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return hash.toRadixString(36);
  }

  String fileNameFor(DownloadItem item) {
    var chapter = sanitizeFileName(item.episode.chapterId);
    if (chapter.isEmpty) chapter = 'ep';
    if (chapter.length > 40) chapter = chapter.substring(0, 40);
    return '${_shortHash(item.drama.bookId)}_$chapter.mp4';
  }

  Future<Directory> _downloadsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}downloads');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  bool isActive(String id) => _activeTokens.containsKey(id);

  /// Returns the item for a downloaded episode if a complete file exists,
  /// otherwise null. Used by the player to switch to offline playback.
  Future<DownloadItem?> getDownloadedItem(
    String bookId,
    String chapterId,
  ) async {
    final item = await dataSource.getDownload('${bookId}_$chapterId');
    if (item == null || item.status != DownloadStatus.completed) return null;
    if (item.filePath == null) return null;
    final file = File(item.filePath!);
    if (!await _safeExists(file)) return null;
    return item;
  }

  /// Starts (or resumes) the download for [item].
  ///
  /// Progress is reported through [onProgress] (throttled). When the
  /// download is cancelled mid-way the item is persisted as [DownloadStatus.paused]
  /// so it can be resumed later from the partial file.
  Future<void> start(
    DownloadItem item, {
    required ProgressCallback onProgress,
  }) async {
    if (_activeTokens.containsKey(item.id)) return;

    // Persist as queued immediately so the UI reflects it before the
    // concurrency slot is available.
    final queued = item.copyWith(
      status: DownloadStatus.queued,
      clearError: true,
    );
    try {
      await dataSource.saveDownload(queued);
    } catch (_) {}
    onProgress(queued);

    _pending.add(_QueuedDownload(item, onProgress));
    _pump();
  }

  void _pump() {
    while (_activeCount < maxConcurrentDownloads && _pending.isNotEmpty) {
      final queued = _pending.removeAt(0);
      _activeCount++;
      unawaited(_run(queued));
    }
  }

  Future<void> _run(_QueuedDownload queued) async {
    try {
      await _startInternal(queued.item, queued.onProgress);
    } finally {
      _activeCount--;
      _pump();
    }
  }

  Future<void> _startInternal(
    DownloadItem item,
    ProgressCallback onProgress,
  ) async {
    final cancelToken = CancelToken();
    _activeTokens[item.id] = cancelToken;

    final dir = await _downloadsDir();
    if (_isHls(item.episode.videoUrl)) {
      await _startHls(item, dir, cancelToken, onProgress);
    } else {
      await _startFile(item, dir, cancelToken, onProgress);
    }
  }

  Future<void> _startFile(
    DownloadItem item,
    Directory dir,
    CancelToken cancelToken,
    ProgressCallback onProgress,
  ) async {
    final file = File('${dir.path}${Platform.pathSeparator}${fileNameFor(item)}');

    var current = item.copyWith(
      status: DownloadStatus.downloading,
      filePath: file.path,
      clearError: true,
    );
    await dataSource.saveDownload(current);
    onProgress(current);

    try {
      final result = await _performDownload(
        current,
        file,
        cancelToken,
        onProgress,
      );
      if (!_activeTokens.containsKey(item.id)) return; // cancelled
      _activeTokens.remove(item.id);

      if (result == _DownloadResult.completed) {
        final completed = current.copyWith(
          status: DownloadStatus.completed,
          completedAt: DateTime.now(),
          downloadedBytes: await file.length(),
        );
        await dataSource.saveDownload(completed);
        onProgress(completed);
      } else {
        // Reached EOF before expected size but no cancel/error: treat as paused.
        final paused = current.copyWith(status: DownloadStatus.paused);
        await dataSource.saveDownload(paused);
        onProgress(paused);
      }
    } catch (e) {
      _activeTokens.remove(item.id);
      debugPrint('DownloadService: download error for ${item.id}: $e');

      DownloadItem failed;
      if (e is DioException && e.type == DioExceptionType.cancel) {
        failed = current.copyWith(status: DownloadStatus.paused);
      } else {
        failed = current.copyWith(status: DownloadStatus.failed, error: e.toString());
      }
      await dataSource.saveDownload(failed);
      onProgress(failed);
    }
  }

  /// Downloads an HLS episode into a folder: fetches the playlist (resolving
  /// to the highest-quality variant when the URL is a master playlist),
  /// downloads every segment plus any AES-128 key / EXT-X-MAP init section,
  /// and writes a local `index.m3u8` that references the local files so
  /// ExoPlayer can play the episode fully offline.
  Future<void> _startHls(
    DownloadItem item,
    Directory dir,
    CancelToken cancelToken,
    ProgressCallback onProgress,
  ) async {
    final folderName = _artifactFolderName(item);
    final folder = Directory('${dir.path}${Platform.pathSeparator}$folderName');
    final playlistFile = File('${folder.path}${Platform.pathSeparator}index.m3u8');

    // HLS resumes are coarse: restart the whole episode cleanly.
    if (await _safeDirExists(folder)) {
      try {
        await folder.delete(recursive: true);
      } catch (e) {
        debugPrint('DownloadService: failed to clear partial HLS folder: $e');
      }
    }
    await folder.create(recursive: true);

    var current = item.copyWith(
      status: DownloadStatus.downloading,
      filePath: playlistFile.path,
      clearError: true,
    );
    await dataSource.saveDownload(current);
    onProgress(current);

    try {
      await _performHlsDownload(current, folder, playlistFile, cancelToken, onProgress);
      if (!_activeTokens.containsKey(item.id)) return; // cancelled
      _activeTokens.remove(item.id);

      final total = await _dirSize(folder);
      final completed = current.copyWith(
        status: DownloadStatus.completed,
        completedAt: DateTime.now(),
        downloadedBytes: total,
        totalBytes: total,
      );
      await dataSource.saveDownload(completed);
      onProgress(completed);
    } catch (e) {
      _activeTokens.remove(item.id);
      debugPrint('DownloadService: HLS download error for ${item.id}: $e');

      DownloadItem failed;
      if (e is DioException && e.type == DioExceptionType.cancel) {
        failed = current.copyWith(status: DownloadStatus.paused);
      } else {
        failed = current.copyWith(status: DownloadStatus.failed, error: e.toString());
      }
      await dataSource.saveDownload(failed);
      onProgress(failed);
    }
  }

  static bool _isHls(String url) {
    final path = url.split('?').first;
    return path.toLowerCase().endsWith('.m3u8');
  }

  String _artifactFolderName(DownloadItem item) {
    var chapter = sanitizeFileName(item.episode.chapterId);
    if (chapter.isEmpty) chapter = 'ep';
    if (chapter.length > 40) chapter = chapter.substring(0, 40);
    return '${_shortHash(item.drama.bookId)}_$chapter';
  }

  Map<String, String> _mediaHeaders() {
    return {
      'User-Agent': 'Mozilla/5.0 (Linux; Android 12) QuickPlay/1.0.0',
      'Referer': 'https://narto-drama.com/',
      'Accept': '*/*',
    };
  }

  Future<String> _fetchText(
    String url,
    CancelToken cancelToken,
    Map<String, String> headers,
  ) async {
    final response = await _dio.get<String>(
      url,
      options: Options(headers: headers),
      cancelToken: cancelToken,
    );
    return response.data ?? '';
  }

  /// Returns the media playlist URL when [text] is a master playlist,
  /// picking the variant with the highest BANDWIDTH. Null otherwise.
  String? _resolveMediaPlaylist(Uri baseUri, String text) {
    if (!text.contains('#EXT-X-STREAM-INF')) return null;
    final lines = text.split('\n');
    var bestUri = '';
    var bestBw = -1;
    for (var i = 0; i < lines.length; i++) {
      if (!lines[i].contains('#EXT-X-STREAM-INF')) continue;
      final bwMatch = RegExp(r'BANDWIDTH=(\d+)').firstMatch(lines[i]);
      final bw = bwMatch != null ? int.tryParse(bwMatch.group(1)!) ?? 0 : 0;
      if (i + 1 < lines.length) {
        final t = lines[i + 1].trim();
        if (t.isNotEmpty && !t.startsWith('#') && bw > bestBw) {
          bestBw = bw;
          bestUri = t;
        }
      }
    }
    if (bestUri.isEmpty) return null;
    return baseUri.resolveUri(Uri.parse(bestUri)).toString();
  }

  Future<bool> _performHlsDownload(
    DownloadItem item,
    Directory folder,
    File playlistFile,
    CancelToken cancelToken,
    ProgressCallback onProgress,
  ) async {
    final headers = _mediaHeaders();
    final masterText = await _fetchText(item.episode.videoUrl, cancelToken, headers);
    if (masterText.trim().isEmpty) {
      throw StateError('Empty HLS playlist for ${item.id}');
    }

    final masterBase = Uri.parse(item.episode.videoUrl);
    final mediaUrl = _resolveMediaPlaylist(masterBase, masterText);
    final mediaText = mediaUrl == null
        ? masterText
        : await _fetchText(mediaUrl, cancelToken, headers);
    final baseUri = Uri.parse(mediaUrl ?? item.episode.videoUrl);

    final lines = mediaText.split('\n');
    final segmentUris = <String>[
      for (final l in lines)
        if (l.trim().isNotEmpty && !l.trim().startsWith('#')) l.trim(),
    ];
    final totalSegments = segmentUris.length;

    final out = <String>[];
    var segIndex = 0;
    var bytes = 0;
    String? byteRangeSpec;
    String? prevSegmentUrl;
    int? prevRangeEnd;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXT-X-KEY:METHOD=AES-128')) {
        out.add(await _rewriteEncryptionKey(line, baseUri, folder, cancelToken, headers));
        continue;
      }
      if (line.startsWith('#EXT-X-MAP:')) {
        out.add(await _rewriteInitMap(line, baseUri, folder, cancelToken, headers));
        continue;
      }
      if (line.startsWith('#EXT-X-BYTERANGE:')) {
        byteRangeSpec = line.substring('#EXT-X-BYTERANGE:'.length).trim();
        out.add(rawLine);
        continue;
      }
      if (line.startsWith('#')) {
        out.add(rawLine);
        continue;
      }

      // Segment URI.
      final segUrl = baseUri.resolveUri(Uri.parse(line)).toString();
      final segName =
          '${segIndex.toString().padLeft(5, '0')}${_segmentExt(segUrl)}';
      final segFile = File('${folder.path}${Platform.pathSeparator}$segName');

      String? range;
      if (byteRangeSpec != null) {
        final parts = byteRangeSpec.split('@');
        final n = parts.isNotEmpty ? int.tryParse(parts[0]) : null;
        final offset = parts.length > 1 ? int.tryParse(parts[1]) : null;
        if (n != null) {
          final start = offset ?? (prevSegmentUrl == segUrl ? prevRangeEnd : null) ?? 0;
          range = 'bytes=$start-${start + n - 1}';
          prevRangeEnd = start + n;
        }
        byteRangeSpec = null;
      } else {
        prevRangeEnd = null;
      }
      prevSegmentUrl = segUrl;

      await _downloadSegment(segUrl, segFile, range, cancelToken, headers);
      bytes += await segFile.length();
      segIndex++;
      out.add(segName);

      if (totalSegments > 0) {
        final estimatedTotal =
            (bytes / segIndex * totalSegments).round().clamp(0, 1 << 62);
        final updated = item.copyWith(
          status: DownloadStatus.downloading,
          downloadedBytes: bytes,
          totalBytes: estimatedTotal,
        );
        await dataSource.saveDownload(updated);
        onProgress(updated);
      }
    }

    if (!mediaText.contains('#EXT-X-ENDLIST')) {
      out.add('#EXT-X-ENDLIST');
    }
    await playlistFile.writeAsString('${out.join('\n')}\n');

    final finalItem = item.copyWith(
      status: DownloadStatus.downloading,
      downloadedBytes: bytes,
      totalBytes: bytes,
    );
    await dataSource.saveDownload(finalItem);
    onProgress(finalItem);
    return true;
  }

  Future<void> _downloadSegment(
    String url,
    File file,
    String? range,
    CancelToken cancelToken,
    Map<String, String> headers,
  ) async {
    final response = await _dio.get<ResponseBody>(
      url,
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          ...headers,
          if (range != null) HttpHeaders.rangeHeader: range,
        },
        validateStatus: (status) =>
            status == HttpStatus.ok ||
            status == HttpStatus.partialContent ||
            status == 203,
      ),
      cancelToken: cancelToken,
    );
    final raf = await file.open(mode: FileMode.write);
    try {
      final stream = response.data?.stream;
      if (stream == null) {
        throw StateError('Empty segment body for $url');
      }
      await for (final chunk in stream) {
        await raf.writeFrom(chunk);
      }
    } finally {
      await raf.close();
    }
  }

  Future<String> _rewriteEncryptionKey(
    String line,
    Uri baseUri,
    Directory folder,
    CancelToken cancelToken,
    Map<String, String> headers,
  ) async {
    final match = RegExp(r'URI="([^"]+)"').firstMatch(line);
    if (match == null) return line;
    final keyUrl = baseUri.resolveUri(Uri.parse(match.group(1)!)).toString();
    final response = await _dio.get<List<int>>(
      keyUrl,
      options: Options(
        responseType: ResponseType.bytes,
        headers: headers,
      ),
      cancelToken: cancelToken,
    );
    final keyFile = File('${folder.path}${Platform.pathSeparator}key.key');
    await keyFile.writeAsBytes(response.data ?? const <int>[]);
    return line.replaceAll(match.group(1)!, 'key.key');
  }

  Future<String> _rewriteInitMap(
    String line,
    Uri baseUri,
    Directory folder,
    CancelToken cancelToken,
    Map<String, String> headers,
  ) async {
    final match = RegExp(r'URI="([^"]+)"').firstMatch(line);
    if (match == null) return line;
    final initUrl = baseUri.resolveUri(Uri.parse(match.group(1)!)).toString();
    final response = await _dio.get<List<int>>(
      initUrl,
      options: Options(
        responseType: ResponseType.bytes,
        headers: headers,
      ),
      cancelToken: cancelToken,
    );
    final initFile = File('${folder.path}${Platform.pathSeparator}init.mp4');
    await initFile.writeAsBytes(response.data ?? const <int>[]);
    return line.replaceAll(match.group(1)!, 'init.mp4');
  }

  String _segmentExt(String url) {
    final path = url.split('?').first;
    final name = path.split('/').last;
    if (name.contains('.')) {
      final ext = name.substring(name.lastIndexOf('.')).toLowerCase();
      if (ext.length <= 6 && RegExp(r'^\.[a-z0-9]+$').hasMatch(ext)) return ext;
    }
    return '.ts';
  }

  Future<int> _dirSize(Directory dir) async {
    var total = 0;
    try {
      await for (final entity in dir.list()) {
        if (entity is File) {
          try {
            total += await entity.length();
          } catch (_) {}
        }
      }
    } catch (_) {}
    return total;
  }

  Future<_DownloadResult> _performDownload(
    DownloadItem item,
    File file,
    CancelToken cancelToken,
    ProgressCallback onProgress,
  ) async {
    var start = 0;
    if (await file.exists()) {
      start = await file.length();
    }

    final response = await _dio.get<ResponseBody>(
      item.episode.videoUrl,
      options: Options(
        responseType: ResponseType.stream,
        headers: {HttpHeaders.rangeHeader: 'bytes=$start-'},
        validateStatus: (status) =>
            status == HttpStatus.ok ||
            status == HttpStatus.partialContent,
      ),
      cancelToken: cancelToken,
    );

    var total = _totalFromHeaders(response.headers);
    if (response.statusCode == HttpStatus.ok) {
      // Server ignored the Range header and is sending the whole file.
      // Overwrite the partial file from scratch.
      start = 0;
      if (await file.exists()) {
        await file.delete();
      }
    }

    var downloaded = start;
    final stream = response.data?.stream;

    // Throttle progress persistence/emissions.
    final lastEmit = Stopwatch()..start();
    var lastBytes = downloaded;

    final raf = await file.open(mode: FileMode.append);
    try {
      if (stream == null) {
        throw StateError('Empty response body for ${item.id}');
      }
      await for (final chunk in stream) {
        await raf.writeFrom(chunk);
        downloaded += chunk.length;

        // Emit when at least ~250ms elapsed or >1MB since the last emit.
        if (lastEmit.elapsedMilliseconds >= 250 ||
            (downloaded - lastBytes) >= 1024 * 1024) {
          lastEmit.reset();
          lastBytes = downloaded;
          final updated = item.copyWith(
            status: DownloadStatus.downloading,
            downloadedBytes: downloaded,
            totalBytes: total,
          );
          await dataSource.saveDownload(updated);
          onProgress(updated);
        }
      }
    } finally {
      await raf.close();
    }

    if (total != null && total > 0 && downloaded < total) {
      // Stream ended early (e.g., connection reset) - resumable.
      return _DownloadResult.incomplete;
    }
    return _DownloadResult.completed;
  }

  int? _totalFromHeaders(Headers headers) {
    final contentRange = headers.value(HttpHeaders.contentRangeHeader);
    if (contentRange != null) {
      // Format: "bytes 0-1048575/326628636"
      final slash = contentRange.lastIndexOf('/');
      if (slash != -1 && slash < contentRange.length - 1) {
        final totalStr = contentRange.substring(slash + 1);
        if (totalStr != '*') {
          return int.tryParse(totalStr);
        }
      }
    }
    final contentLength = headers.value(HttpHeaders.contentLengthHeader);
    if (contentLength != null) {
      final length = int.tryParse(contentLength);
      if (length != null && length > 0) return length;
    }
    return null;
  }

  /// Cancels an in-flight download. The partial file is kept so [start] can
  /// resume from where it stopped. Also removes the item from the pending queue
  /// if it hasn't started yet.
  void cancel(String id) {
    _pending.removeWhere((q) => q.item.id == id);
    final token = _activeTokens.remove(id);
    if (token != null && !token.isCancelled) {
      token.cancel();
    }
  }

  /// Removes the stored entry and deletes any partial/completed file. For HLS
  /// items the whole artifact folder (playlist + segments) is removed.
  Future<void> delete(String id) async {
    cancel(id);
    final item = await dataSource.getDownload(id);
    if (item?.filePath != null) {
      final file = File(item!.filePath!);
      if (_isHls(item.episode.videoUrl)) {
        final parent = file.parent;
        final downloadsDir = await _downloadsDir();
        if (parent.path != downloadsDir.path && await _safeDirExists(parent)) {
          try {
            await parent.delete(recursive: true);
          } catch (e) {
            debugPrint('DownloadService: failed to delete HLS folder: $e');
          }
        } else if (await _safeExists(file)) {
          try {
            await file.delete();
          } catch (e) {
            debugPrint('DownloadService: failed to delete file: $e');
          }
        }
      } else {
        if (await _safeExists(file)) {
          try {
            await file.delete();
          } catch (e) {
            debugPrint('DownloadService: failed to delete file: $e');
          }
        }
      }
    }
    await dataSource.removeDownload(id);
  }

  Future<bool> _safeExists(File file) async {
    try {
      return await file.exists();
    } catch (e) {
      debugPrint('DownloadService: file exists check failed: $e');
      return false;
    }
  }

  Future<bool> _safeDirExists(Directory dir) async {
    try {
      return await dir.exists();
    } catch (e) {
      debugPrint('DownloadService: dir exists check failed: $e');
      return false;
    }
  }
}

enum _DownloadResult { completed, incomplete }

class _QueuedDownload {
  final DownloadItem item;
  final ProgressCallback onProgress;

  _QueuedDownload(this.item, this.onProgress);
}
