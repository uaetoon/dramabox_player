import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'faststart_mp4.dart';

class VideoProxyService {
  HttpServer? _server;
  int _port = 0;
  final String _localIp = '127.0.0.1';

  final HttpClient _httpClient = HttpClient();

  /// Parsed faststart layouts keyed by original URL, to avoid re-fetching the
  /// file head/tail for every range request.
  final Map<String, FastStartMp4> _fastStartCache = {};

  /// URLs whose faststart build failed or that are already faststart, so the
  /// head/tail fetches are not re-triggered on every range request.
  final Set<String> _failedFastStart = {};

  /// In-flight (or finished) build futures keyed by original URL, so that
  /// concurrent/retried requests share a single head/tail fetch.
  final Map<String, Future<FastStartMp4?>> _pendingBuilds = {};

  static const int _maxFastStartCacheEntries = 20;

  /// Initializes the proxy server.
  /// Only starts the server on Android.
  Future<void> init() async {
    try {
      // Bind to loopback interface (localhost) on an ephemeral port (0)
      _server = await HttpServer.bind(_localIp, 0);
      _port = _server!.port;
      _httpClient.connectionTimeout = const Duration(seconds: 15);
      debugPrint(
        'VideoProxyService: Server running on http://$_localIp:$_port/',
      );

      _server!.listen(_handleRequest);
    } catch (e) {
      debugPrint('VideoProxyService: Failed to start server: $e');
    }
  }

  /// Returns the proxied URL for Android, or the original URL for other platforms.
  /// Returns the proxied URL if the server is available, otherwise returns the original URL.
  ///
  /// When [faststart] is true the proxy reassembles non-faststart MP4s
  /// (moov atom at the end) into a streamable faststart layout. The reassembly
  /// is built (awaiting the head/tail fetch) *before* the URL is returned, so
  /// the player's first request finds it cached and gets response headers
  /// immediately instead of stalling the connection (and hitting ExoPlayer's
  /// read timeout) while the layout downloads.
  Future<String> getProxyUrl(
    String originalUrl, {
    bool faststart = false,
  }) async {
    if (_server == null) {
      return originalUrl;
    }
    // HLS (m3u8) playlists use relative segment URLs that must resolve against
    // the origin host. Routing them through the proxy would break those
    // segments, so let the player fetch the playlist directly. This covers both
    // plain .m3u8 URLs and token-wrapped ones (e.g. iDrama's /e/m/<token>
    // whose base64 payload references an .m3u8 source).
    if (_isHlsUrl(originalUrl)) {
      return originalUrl;
    }
    if (faststart) {
      await _ensureFastStart(Uri.parse(originalUrl));
    }
    // Encode the original URL to safely pass it as a query parameter
    final encodedUrl = Uri.encodeComponent(originalUrl);
    final faststartParam = faststart ? '&faststart=1' : '';
    return 'http://$_localIp:$_port/?url=$encodedUrl$faststartParam';
  }

  /// Whether [url] points at an HLS playlist, either directly (.m3u8/.m3u) or
  /// wrapped inside a base64 token whose payload references an .m3u8 source.
  bool _isHlsUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.m3u8') || lower.contains('.m3u')) return true;
    try {
      final segment = Uri.parse(url).pathSegments.last.split('.').first;
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(segment)),
        allowMalformed: true,
      );
      if (payload.contains('.m3u8') || payload.contains('.m3u')) return true;
    } catch (_) {
      // Not a token URL; fall through to the default proxy path.
    }
    return false;
  }

  /// Handles incoming requests from the video player.
  Future<void> _handleRequest(HttpRequest request) async {
    final originalUrl = request.uri.queryParameters['url'];
    final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
    debugPrint(
      'VideoProxyService: ${request.method} '
      'faststart=${request.uri.queryParameters['faststart']} '
      '${rangeHeader != null ? 'range=$rangeHeader' : 'no-range'}',
    );
    if (originalUrl == null) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.close();
      return;
    }

    if (request.uri.queryParameters['faststart'] == '1') {
      await _handleFastStart(request, originalUrl);
      return;
    }

    await _passthrough(request, originalUrl);
  }

  // ---------------------------------------------------------------------------
  // Faststart MP4 serving
  // ---------------------------------------------------------------------------

  Future<void> _handleFastStart(
    HttpRequest request,
    String originalUrl,
  ) async {
    final uri = Uri.parse(originalUrl);
    final stopwatch = Stopwatch()..start();
    try {
      final fs = await _ensureFastStart(uri);
      if (fs == null) {
        debugPrint(
          'VideoProxyService: faststart parse failed '
          '(${stopwatch.elapsedMilliseconds}ms), passthrough for $originalUrl',
        );
        await _passthrough(request, originalUrl);
        return;
      }
      await _serveFastStart(request, uri, fs);
      debugPrint(
        'VideoProxyService: served faststart in '
        '${stopwatch.elapsedMilliseconds}ms',
      );
    } catch (e) {
      debugPrint('VideoProxyService: faststart error: $e');
      try {
        await _passthrough(request, originalUrl);
      } catch (_) {}
    }
  }

  /// Returns the cached faststart layout for [uri], or starts building it
  /// (deduplicating concurrent builds for the same URL). Negative results are
  /// also memoized so already-faststart/unparseable files do not re-trigger the
  /// head/tail fetches for every subsequent range request.
  Future<FastStartMp4?> _ensureFastStart(Uri uri) {
    final urlKey = uri.toString();
    final cached = _fastStartCache[urlKey];
    if (cached != null) return Future.value(cached);
    if (_failedFastStart.contains(urlKey)) return Future.value(null);

    final pending = _pendingBuilds[urlKey];
    if (pending != null) return pending;

    final future = _buildFastStart(uri).then((fs) {
      _pendingBuilds.remove(urlKey);
      if (fs != null) {
        _fastStartCache[urlKey] = fs;
        debugPrint(
          'VideoProxyService: faststart ready for $urlKey '
          '(moov ${fs.moovSize} bytes moved to front)',
        );
        while (_fastStartCache.length > _maxFastStartCacheEntries) {
          final oldest = _fastStartCache.keys.first;
          _fastStartCache.remove(oldest);
        }
      } else {
        _failedFastStart.add(urlKey);
        while (_failedFastStart.length > _maxFastStartCacheEntries) {
          _failedFastStart.remove(_failedFastStart.first);
        }
      }
      return fs;
    });
    _pendingBuilds[urlKey] = future;
    return future;
  }

  /// Fetches the file head (to read the ftyp box and total length) and tail
  /// (to read the moov box), then builds the faststart layout.
  Future<FastStartMp4?> _buildFastStart(Uri url) async {
    const headSize = 256 * 1024;
    const tailSize = 2 * 1024 * 1024;

    // The tail range needs the total length (from the head response), so the
    // head is fetched first and the tail second.
    final head = await _fetchRange(url, 0, headSize - 1);
    if (head == null) {
      debugPrint('VideoProxyService: head fetch failed for $url');
      return null;
    }

    final totalLength = _totalFromContentRange(head.contentRange);
    if (totalLength == null || totalLength <= 0) {
      debugPrint(
        'VideoProxyService: bad content-range "${head.contentRange}" for $url',
      );
      return null;
    }

    var tail = await _fetchRange(url, totalLength - tailSize, totalLength - 1);
    if (tail == null) {
      debugPrint('VideoProxyService: tail fetch failed for $url');
      return null;
    }

    final parsed = FastStartMp4.tryParse(
      head: head.bytes,
      tail: tail.bytes,
      fileLength: totalLength,
    );
    if (parsed != null) {
      return parsed;
    }

    // moov not found in the small tail: fall back to a large tail fetch.
    const bigTailSize = 8 * 1024 * 1024;
    if (totalLength - bigTailSize < headSize) return null;
    final bigTail =
        await _fetchRange(url, totalLength - bigTailSize, totalLength - 1);
    if (bigTail == null) return null;
    return FastStartMp4.tryParse(
      head: head.bytes,
      tail: bigTail.bytes,
      fileLength: totalLength,
    );
  }

  Future<_RangeFetch?> _fetchRange(Uri url, int start, int end) async {
    try {
      final req = await _httpClient.getUrl(url);
      req.headers.set(HttpHeaders.rangeHeader, 'bytes=$start-$end');
      final resp = await req.close();
      if (resp.statusCode != HttpStatus.partialContent) {
        debugPrint(
          'VideoProxyService: range $start-$end -> ${resp.statusCode} '
          '(not 206)',
        );
        return null;
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in resp) {
        builder.add(chunk);
      }
      return _RangeFetch(
        bytes: builder.takeBytes(),
        contentRange: resp.headers.value(HttpHeaders.contentRangeHeader),
      );
    } catch (e) {
      debugPrint('VideoProxyService: range fetch error: $e');
      return null;
    }
  }

  int? _totalFromContentRange(String? contentRange) {
    if (contentRange == null) return null;
    // Format: "bytes 0-1048575/326628636"
    final slash = contentRange.lastIndexOf('/');
    if (slash == -1) return null;
    return int.tryParse(contentRange.substring(slash + 1));
  }

  Future<void> _serveFastStart(
    HttpRequest request,
    Uri url,
    FastStartMp4 fs,
  ) async {
    final response = request.response;
    final total = fs.faststartLength;
    final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);

    response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    response.headers.contentType ??= ContentType.parse('video/mp4');

    // ExoPlayer's first request carries no Range header and expects the whole
    // file. Serving the entire episode in one response lets ExoPlayer buffer
    // everything into memory at once, which OOMs on constrained devices/slow
    // decoders. Instead every response (range or not) is capped to a bounded
    // window below; ExoPlayer follows up with further Range requests for the
    // rest, which the proxy already serves.
    final requestedRange = (rangeHeader != null && rangeHeader.startsWith('bytes='))
        ? rangeHeader.substring('bytes='.length)
        : '0-';

    // Parse "bytes=start-end" / "bytes=start-".
    final dash = requestedRange.indexOf('-');
    final start = int.tryParse(requestedRange.substring(0, dash)) ?? 0;
    final endText = requestedRange.substring(dash + 1);
    var clampedEnd = (endText.isNotEmpty ? int.tryParse(endText) : null) ??
        total - 1;

    if (clampedEnd > total - 1) clampedEnd = total - 1;
    if (clampedEnd < 0) clampedEnd = 0;
    if (start > clampedEnd) {
      response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
      response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes */$total',
      );
      await response.close();
      return;
    }

    const chunkSize = 8 * 1024 * 1024;
    if (clampedEnd > start + chunkSize - 1) {
      clampedEnd = start + chunkSize - 1;
    }

    response.statusCode = HttpStatus.partialContent;
    response.headers.set(
      HttpHeaders.contentRangeHeader,
      'bytes $start-$clampedEnd/$total',
    );
    response.headers.contentLength = clampedEnd - start + 1;

    final mediaStart = fs.mediaStart;

    // Segment 1: ftyp region [0, ftypEnd).
    if (start < fs.ftypEnd) {
      final a = start;
      final b = clampedEnd < fs.ftypEnd ? clampedEnd : fs.ftypEnd - 1;
      response.add(fs.ftypBytes.sublist(a, b + 1));
    }

    // Segment 2: moov region [ftypEnd, mediaStart).
    if (clampedEnd >= fs.ftypEnd && start < mediaStart) {
      final a = (start > fs.ftypEnd ? start : fs.ftypEnd) - fs.ftypEnd;
      final b = (clampedEnd < mediaStart ? clampedEnd : mediaStart - 1) -
          fs.ftypEnd;
      response.add(fs.moov.sublist(a, b + 1));
    }

    // Segment 3: media region, translated back to origin offsets.
    if (clampedEnd >= mediaStart) {
      final a = (start > mediaStart ? start : mediaStart) - fs.moovSize;
      final b = clampedEnd - fs.moovSize;
      try {
        await _pipeOriginRange(url, a, b, response);
      } catch (e) {
        debugPrint('VideoProxyService: range stream aborted: $e');
      }
    }

    try {
      await response.close();
    } catch (_) {}
  }

  /// Streams origin bytes [start, end] into [response].
  Future<void> _pipeOriginRange(
    Uri url,
    int start,
    int end,
    HttpResponse response,
  ) async {
    final req = await _httpClient.getUrl(url);
    req.headers.set(HttpHeaders.rangeHeader, 'bytes=$start-$end');
    final resp = await req.close();
    if (resp.statusCode != HttpStatus.partialContent &&
        resp.statusCode != HttpStatus.ok) {
      debugPrint(
        'VideoProxyService: origin range $start-$end -> ${resp.statusCode}',
      );
      await resp.drain<void>();
      throw HttpException(
        'origin range request failed: ${resp.statusCode}',
      );
    }
    await resp.pipe(response);
  }

  // ---------------------------------------------------------------------------
  // Plain passthrough proxy
  // ---------------------------------------------------------------------------

  /// Handles incoming requests from the video player.
  Future<void> _passthrough(
    HttpRequest request,
    String originalUrl,
  ) async {
    try {
      final actualUrl = Uri.parse(originalUrl);
      final proxyRequest = await _httpClient.getUrl(actualUrl);

      // Forward headers from the original request
      String? rangeHeaderText;
      request.headers.forEach((name, values) {
        if (name.toLowerCase() == 'range') {
          rangeHeaderText = values.first;
        }
        if (name.toLowerCase() != 'host' &&
            name.toLowerCase() != 'connection') {
          for (var value in values) {
            proxyRequest.headers.add(name, value);
          }
        }
      });

      final proxyResponse = await proxyRequest.close();
      final response = request.response;

      // Extract requested range
      int start = 0;
      int? end;
      bool isRangeRequest = rangeHeaderText != null;

      if (isRangeRequest) {
        final parts = rangeHeaderText!.split('=');
        if (parts.length == 2 && parts[0] == 'bytes') {
          final rangeParts = parts[1].split('-');
          start = int.tryParse(rangeParts[0]) ?? 0;
          if (rangeParts.length > 1 && rangeParts[1].isNotEmpty) {
            end = int.tryParse(rangeParts[1]);
          }
        }
      }

      final totalLength = proxyResponse.contentLength; // -1 if unknown

      debugPrint(
        'VideoProxyService: passthrough origin ${proxyResponse.statusCode} '
        'for $originalUrl range=$rangeHeaderText',
      );

      // OPTIMIZATION: Fast path if no range is needed, or if server already handled it,
      // or if the player asks for a range starting at 0 and server gave the full file.
      if (proxyResponse.statusCode == HttpStatus.partialContent ||
          !isRangeRequest ||
          (proxyResponse.statusCode == HttpStatus.ok &&
              start == 0 &&
              end == null)) {
        response.statusCode = proxyResponse.statusCode;
        proxyResponse.headers.forEach((name, values) {
          for (var value in values) {
            response.headers.add(name, value);
          }
        });

        response.headers.contentType ??= ContentType.parse("video/mp4");

        if (!isRangeRequest && proxyResponse.statusCode == HttpStatus.ok) {
          response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
        }

        await proxyResponse.pipe(response);
        return;
      }

      // Case: Manual Slicing (Server returned 200 OK but a range (>0 or chunked) was requested)
      if (proxyResponse.statusCode == HttpStatus.ok) {
        int actualEnd = end ?? (totalLength != -1 ? totalLength - 1 : -1);

        response.statusCode = HttpStatus.partialContent;

        // Forward headers except content-length (calculated manually)
        proxyResponse.headers.forEach((name, values) {
          if (name.toLowerCase() != 'content-length' &&
              name.toLowerCase() != 'content-range') {
            for (var value in values) {
              response.headers.add(name, value);
            }
          }
        });

        // Set mandatory range headers
        if (totalLength != -1) {
          int headerEnd = (actualEnd == -1) ? totalLength - 1 : actualEnd;
          response.headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes $start-$headerEnd/$totalLength',
          );
          response.headers.contentLength = headerEnd - start + 1;
        } else if (actualEnd != -1) {
          // We have an end but not total length
          response.headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes $start-$actualEnd/*',
          );
          response.headers.contentLength = actualEnd - start + 1;
        }

        response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
        response.headers.contentType ??= ContentType.parse("video/mp4");

        debugPrint(
          "Proxy: Manual Range slice for $originalUrl ($start-${actualEnd == -1 ? '' : actualEnd}/${totalLength == -1 ? '*' : totalLength})",
        );

        int bytesServed = 0;
        await for (final chunk in proxyResponse) {
          // Entire chunk is before the start point
          if (bytesServed + chunk.length <= start) {
            bytesServed += chunk.length;
            continue;
          }

          // Calculate what part of this chunk we need
          int chunkStart = (start > bytesServed) ? (start - bytesServed) : 0;
          int chunkEnd = chunk.length - 1;

          if (actualEnd != -1 && bytesServed + chunk.length - 1 > actualEnd) {
            chunkEnd = actualEnd - bytesServed;
          }

          if (chunkStart <= chunkEnd) {
            // Avoid sublist if the whole chunk is used
            if (chunkStart == 0 && chunkEnd == chunk.length - 1) {
              response.add(chunk);
            } else {
              response.add(chunk.sublist(chunkStart, chunkEnd + 1));
            }
          }

          bytesServed += chunk.length;
          if (actualEnd != -1 && bytesServed > actualEnd) break;
        }
        await response.close();
      } else {
        // Handle error status from upstream (404, 403, etc.)
        response.statusCode = proxyResponse.statusCode;
        await proxyResponse.pipe(response);
      }
    } catch (e) {
      debugPrint('VideoProxyService: Error handling request: $e');
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.close();
      } catch (_) {}
    }
  }

  void dispose() {
    _server?.close();
  }
}

class _RangeFetch {
  _RangeFetch({required this.bytes, this.contentRange});

  final Uint8List bytes;
  final String? contentRange;
}
