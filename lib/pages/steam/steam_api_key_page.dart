import 'package:flutter/material.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/common/utils/steam_webview_english.dart';
import 'package:webview_flutter/webview_flutter.dart';

class SteamApiKeyPage extends StatefulWidget {
  const SteamApiKeyPage({super.key});

  @override
  State<SteamApiKeyPage> createState() => _SteamApiKeyPageState();
}

class _SteamApiKeyPageState extends State<SteamApiKeyPage> {
  final WebViewCookieManager _cookieManager = WebViewCookieManager();
  late final WebViewController _controller;
  bool _isPageLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() => _isPageLoading = true);
            }
          },
          onPageFinished: (_) {
            if (mounted) {
              setState(() => _isPageLoading = false);
            }
          },
        ),
      );
    Future.microtask(_loadApiKeyPage);
  }

  Future<void> _loadApiKeyPage() async {
    await SteamWebViewEnglish.load(
      _controller,
      _cookieManager,
      'https://steamcommunity.com/dev/apikey',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SettingsStyleAppBar(title: Text('app.steam.api_key.setting'.tr)),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isPageLoading) const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }
}
