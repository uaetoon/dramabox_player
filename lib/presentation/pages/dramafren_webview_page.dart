import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// The drama sites on the dramafren network are Cloudflare-protected against
/// plain HTTP clients but work fine in a real browser, so the app embeds them
/// in a visible WebView. Each site is a complete SPA (grid, search, detail,
/// player), so browsing and playback work with zero API scraping.
const Map<String, String> dramafrenSites = {
  'shortwave': 'https://shortwave.dramafren.org',
  'dramafren_dramabox': 'https://dramabox.dramafren.org',
};

bool isDramafrenEmbeddedProvider(String key) => dramafrenSites.containsKey(key);

String dramafrenSiteTitle(String siteKey) {
  switch (siteKey) {
    case 'dramafren_dramabox':
      return 'DramaFren Box';
    case 'shortwave':
      return 'ShortWave';
    default:
      return 'DramaFren';
  }
}

/// Builds the detail deep-link path for a site.
/// shortwave uses `?id=..&slug=..`; dramabox uses `index.php?page=detail&id=..&slug=..`.
String dramafrenDetailPath(String siteKey, String bookId, String title) {
  final slug = title.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '-');
  final cleanSlug = slug.replaceAll(RegExp(r'^-+|-+$'), '');
  if (siteKey == 'dramafren_dramabox') {
    return 'index.php?page=detail&id=$bookId&slug=$cleanSlug';
  }
  return 'id=$bookId&slug=$cleanSlug';
}

/// Parses an external DramaBox/dramafren share link and extracts the numeric
/// drama id plus its slug. Handles formats like:
///   https://www.dramaboxdb.com/ar/ep/41000116643_divorced-at-the-wedding-day/594240384_Episode-1
///   https://dramabox.dramafren.org/index.php?page=detail&id=41000116643&slug=...
///   play.dramabox.com/detail/41000116643
class ParsedDramafrenLink {
  final String? id;
  final String? slug;
  final Uri? uri;

  const ParsedDramafrenLink({this.id, this.slug, this.uri});
}

ParsedDramafrenLink parseDramafrenShareLink(String input) {
  final text = input.trim();
  if (text.isEmpty) return const ParsedDramafrenLink();

  Uri? uri;
  try {
    uri = Uri.parse(text.contains('://') ? text : 'https://$text');
  } catch (_) {}
  final uriText = uri?.toString() ?? text;

  final idWithSlug = RegExp(
    r'(\d{6,})_([a-z][a-z0-9]*(?:[-_][a-z0-9]+)*)',
  ).firstMatch(uriText);
  if (idWithSlug != null) {
    return ParsedDramafrenLink(
      id: idWithSlug.group(1),
      slug: idWithSlug.group(2)!.replaceAll('_', '-'),
      uri: uri,
    );
  }

  final queryId = uri?.queryParameters['id'];
  if (queryId != null && queryId.length >= 6) {
    return ParsedDramafrenLink(
      id: queryId,
      slug: uri?.queryParameters['slug'],
      uri: uri,
    );
  }

  final bareId = RegExp(r'(\d{6,})').firstMatch(uriText);
  if (bareId != null) {
    return ParsedDramafrenLink(id: bareId.group(1), uri: uri);
  }

  return ParsedDramafrenLink(uri: uri);
}

/// Renders a dramafren site inside the app.
///
/// [initialPath] is appended to [baseUrl] (e.g. a deep link into the SPA's
/// detail view); when empty the site's home is shown.
class DramafrenWebViewPage extends StatefulWidget {
  final String siteKey;
  final String baseUrl;
  final String initialPath;

  const DramafrenWebViewPage({
    super.key,
    required this.baseUrl,
    this.siteKey = '',
    this.initialPath = '',
  });

  @override
  State<DramafrenWebViewPage> createState() => _DramafrenWebViewPageState();
}

class _DramafrenWebViewPageState extends State<DramafrenWebViewPage> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _error = false;
  bool _autoOpenPending = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            setState(() {
              _loading = true;
              _error = false;
            });
          },
          onPageFinished: (url) {
            if (mounted) setState(() => _loading = false);
            if (_autoOpenPending && url.contains('page=search_result')) {
              _autoOpenPending = false;
              Future.delayed(const Duration(milliseconds: 1500), () {
                if (mounted) _autoOpenFirstResult();
              });
            }
          },
          onWebResourceError: (err) {
            if (err.isForMainFrame == true &&
                err.errorCode == -6 &&
                mounted) {
              setState(() {
                _error = true;
                _loading = false;
              });
            }
          },
        ),
      );
    _load(widget.initialPath);
  }

  void _load(String initialPath) {
    final url = initialPath.isEmpty
        ? widget.baseUrl
        : '${widget.baseUrl}/$initialPath';
    _controller.loadRequest(Uri.parse(url));
  }

  String get _siteKey =>
      widget.siteKey.isNotEmpty
          ? widget.siteKey
          : (widget.baseUrl.contains('dramabox')
              ? 'dramafren_dramabox'
              : 'shortwave');

  Future<void> _showPasteDialog() async {
    final controller = TextEditingController();
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    if (clip?.text != null && clip!.text!.trim().isNotEmpty) {
      controller.text = clip.text!.trim();
    }
    final entered = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Paste DramaBox link'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          autocorrect: false,
          decoration: const InputDecoration(
            hintText: 'https://www.dramaboxdb.com/ar/ep/...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Open'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (entered == null || entered.isEmpty) return;
    _resolveLink(entered);
  }

  void _resolveLink(String text) {
    final parsed = parseDramafrenShareLink(text);
    if (parsed.id != null) {
      final slug = (parsed.slug == null || parsed.slug!.isEmpty)
          ? parsed.id!
          : parsed.slug!;
      _load(dramafrenDetailPath(_siteKey, parsed.id!, slug));
      return;
    }
    if (parsed.uri != null) {
      _controller.loadRequest(parsed.uri!);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not read that link.')));
  }

  bool get _searchSupported => _siteKey == 'dramafren_dramabox';

  Future<void> _showSearchDialog() async {
    final controller = TextEditingController();
    final entered = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Search dramas'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          autocorrect: false,
          decoration: const InputDecoration(
            hintText: 'Type drama title...',
            prefixIcon: Icon(Icons.search),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Search'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (entered == null || entered.isEmpty) return;
    _openSearch(entered);
  }

  void _openSearch(String query) {
    final url =
        '${widget.baseUrl}/index.php?page=search_result'
        '&q=${Uri.encodeQueryComponent(query)}&lang=en';
    _autoOpenPending = true;
    _controller.loadRequest(Uri.parse(url));
  }

  /// After a search loads, auto-open the top (best) match so the drama is
  /// ready to play; Back then returns to the site (the SPA re-serves its home
  /// when a search page is restored via history).
  void _autoOpenFirstResult() {
    const js = r'''
      (()=>{
        const a = document.querySelector('a[href*="page=detail"]');
        if(!a) return 'NONE';
        a.click();
        return 'OPEN';
      })()
    ''';
    _controller
        .runJavaScriptReturningResult(js)
        .then((v) {
          if ((v as String?) == '"NONE"' && mounted) {
            Future.delayed(const Duration(milliseconds: 700), () {
              if (mounted) _autoOpenFirstResult();
            });
          }
        })
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final canPop = navigator.canPop();
        if (await _controller.canGoBack()) {
          await _controller.goBack();
          return;
        }
        if (canPop) {
          navigator.pop(result);
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(dramafrenSiteTitle(_siteKey)),
          actions: [
            if (_searchSupported)
              IconButton(
                tooltip: 'Search dramas',
                icon: const Icon(Icons.search),
                onPressed: _showSearchDialog,
              ),
            IconButton(
              tooltip: 'Paste DramaBox link',
              icon: const Icon(Icons.link_rounded),
              onPressed: _showPasteDialog,
            ),
          ],
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_loading && !_error)
              const Center(child: CircularProgressIndicator()),
            if (_error)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Failed to load. Check your connection.'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _error = false;
                          _loading = true;
                        });
                        _load(widget.initialPath);
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
