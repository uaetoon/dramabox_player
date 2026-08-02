import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Renders the ShortWave site itself. The dramafren SPA is Cloudflare-
/// protected against plain HTTP clients but works fine in a real browser, so
/// embedding the site in a visible WebView guarantees browsing, detail pages
/// and playback on any device where the site opens.
///
/// [initialPath] lets us deep-link into the SPA detail view using the same
/// `?id=<dramaId>&slug=<slug>` format the site itself uses.
class ShortWaveWebViewPage extends StatefulWidget {
  final String initialPath;

  const ShortWaveWebViewPage({super.key, this.initialPath = ''});

  static const String baseUrl = 'https://shortwave.dramafren.org';

  @override
  State<ShortWaveWebViewPage> createState() => _ShortWaveWebViewPageState();
}

class _ShortWaveWebViewPageState extends State<ShortWaveWebViewPage> {
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
        ? ShortWaveWebViewPage.baseUrl
        : '${ShortWaveWebViewPage.baseUrl}?${widget.initialPath}';
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
                const Text('Failed to load ShortWave. Check your connection.'),
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
