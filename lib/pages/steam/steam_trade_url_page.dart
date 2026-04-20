import 'package:flutter/material.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/common/utils/steam_webview_english.dart';
import 'package:webview_flutter/webview_flutter.dart';

class SteamTradeUrlPage extends StatefulWidget {
  const SteamTradeUrlPage({super.key});

  @override
  State<SteamTradeUrlPage> createState() => _SteamTradeUrlPageState();
}

class _SteamTradeUrlPageState extends State<SteamTradeUrlPage> {
  final WebViewCookieManager _cookieManager = WebViewCookieManager();
  late final WebViewController _controller;
  bool _isPageLoading = true;
  String? _steamId;

  String get _tradeUrl =>
      'https://steamcommunity.com/profiles/$_steamId/tradeoffers/privacy#trade_offer_access_url';

  @override
  void initState() {
    super.initState();
    _steamId = Get.arguments as String?;
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
    if (_steamId != null && _steamId!.isNotEmpty) {
      Future.microtask(_loadTradeUrlPage);
    }
  }

  Future<void> _loadTradeUrlPage() async {
    await SteamWebViewEnglish.load(_controller, _cookieManager, _tradeUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SettingsStyleAppBar(title: Text('app.steam.tradeLink_get'.tr)),
      body: Stack(
        children: [
          if (_steamId != null && _steamId!.isNotEmpty)
            WebViewWidget(controller: _controller)
          else
            Center(child: Text('app.user.login.message.error'.tr)),
          if (_isPageLoading) const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }
}
