import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// The drama sites on the dramafren network are Cloudflare-protected against
/// plain HTTP clients but work fine in a real browser, so the app embeds them
/// in a visible WebView. Each site is a complete SPA (grid, search, detail,
/// player), so browsing and playback work with zero API scraping.
const Map<String, String> dramafrenSites = {
  'shortwave': 'https://shortwave.dramafren.org',
  'dramafren_dramabox': 'https://dramabox.dramafren.org',
};

bool isDramafrenEmbeddedProvider(String key) =>
    dramafrenSites.containsKey(key);

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

/// Renders a dramafren site inside the app.
///
/// [initialPath] is appended to [baseUrl] (e.g. a deep link into the SPA's
/// detail view); when empty the site's home is shown.
class DramafrenWebViewPage extends StatefulWidget {
  final String baseUrl;
  final String initialPath;

  const DramafrenWebViewPage({
    super.key,
    required this.baseUrl,
    this.initialPath = '',
  });

  @override
  State<DramafrenWebViewPage> createState() => _DramafrenWebViewPageState();
}

class _DramafrenWebViewPageState extends State<DramafrenWebViewPage> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _error = false;

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
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
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
    _load();
  }

  void _load() {
    final url = widget.initialPath.isEmpty
        ? widget.baseUrl
        : '${widget.baseUrl}/${widget.initialPath}';
    _controller.loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
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
                    _load();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
