import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:tronskins_app/api/model/notify/notify_models.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
import 'package:tronskins_app/controllers/navbar/nav_controller.dart';
import 'package:tronskins_app/controllers/user/notify_controller.dart';

class TradeNoticeDetailPage extends StatefulWidget {
  const TradeNoticeDetailPage({super.key});

  @override
  State<TradeNoticeDetailPage> createState() => _TradeNoticeDetailPageState();
}

class _TradeNoticeDetailPageState extends State<TradeNoticeDetailPage> {
  final NotifyController _notifyController =
      Get.isRegistered<NotifyController>()
      ? Get.find<NotifyController>()
      : Get.put(NotifyController());

  TradeNotifyItem? _item;

  @override
  void initState() {
    super.initState();
    _resolveItem();
    _markRead();
  }

  void _resolveItem() {
    final arg = Get.arguments;
    if (arg is TradeNotifyItem) {
      _item = arg;
      return;
    }
    if (arg is Map<String, dynamic>) {
      _item = TradeNotifyItem.fromJson(arg);
      return;
    }
    if (arg is String) {
      for (final element in _notifyController.tradeList) {
        if (element.id == arg) {
          _item = element;
          break;
        }
      }
    }
  }

  Future<void> _markRead() async {
    final item = _item;
    if (item == null) return;
    await _notifyController.readTrade(item);
    if (mounted) {
      setState(() {});
    }
  }

  bool get _isChineseLocale {
    final languageCode = Get.locale?.languageCode.toLowerCase();
    return languageCode != null && languageCode.startsWith('zh');
  }

  String _text({required String zh, required String en}) {
    return _isChineseLocale ? zh : en;
  }

  String _formatTime(int? value) {
    if (value == null) return '--';
    final ts = value < 1000000000000 ? value * 1000 : value;
    return DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(ts));
  }

  String _stripHtml(String? value) {
    if (value == null || value.isEmpty) {
      return '';
    }
    return value
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _statusHeadline(TradeNotifyItem item) {
    final cancelDesc = item.cancelDesc?.trim();
    if (cancelDesc != null && cancelDesc.isNotEmpty) {
      return cancelDesc;
    }

    final plainMessage = _stripHtml(item.message).toLowerCase();
    if (plainMessage.contains('cancel') || plainMessage.contains('取消')) {
      return _text(zh: '订单已取消', en: 'Order Cancelled');
    }
    if (plainMessage.contains('shipped') || plainMessage.contains('已发货')) {
      return _text(zh: '卖家已发货', en: 'Seller Shipped');
    }
    if (plainMessage.contains('deliver') || plainMessage.contains('发货')) {
      return _text(zh: '准备发货', en: 'Ready to Deliver');
    }
    if (plainMessage.contains('receive') || plainMessage.contains('收货')) {
      return _text(zh: '待确认收货', en: 'Ready to Receive');
    }
    if (plainMessage.contains('ban') || plainMessage.contains('封禁')) {
      return _text(zh: '店铺已封禁', en: 'Store Suspended');
    }
    return 'app.system.notice.transaction'.tr;
  }

  String _viewOrderLabel() {
    return _text(zh: '查看订单', en: 'View Order');
  }

  String _deliverNowLabel() {
    return _text(zh: '立即发货', en: 'Ship Now');
  }

  /// type 1（出售待发货）和 type 4（求购待发货）需要立即发货
  bool _needsDeliver(int? type) => type == 1 || type == 4;

  /// 判断该 type 是否关联实际订单（正常交易流程、买卖取消、超时取消、Steam异常、7天撤销、其他买卖原因）
  bool _hasRelatedOrder(int? type) {
    if (type == null) return false;
    // 管理员操作类：无订单
    const adminTypes = {
      8,    // ADMIN_REJECT_USER_WITHDRAW
      210,  // DISABLE_USER_SHOP_BY_ADMIN
      211,  // DISABLE_USER_SHOP
      220,  // ENABLE_USER_SHOP_BY_ADMIN
      230,  // FREEZE_USER_FUND_BY_ADMIN
      240,  // THAW_USER_FUND_BY_ADMIN
      250,  // DISABLE_USER_BY_ADMIN
      2501, // DISABLE_USER_BY_MODIFIED_TRADE
      260,  // ENABLE_USER_BY_ADMIN
    };
    if (adminTypes.contains(type)) return false;
    // 管理员取消交易段 290~320：有订单
    if (type >= 290 && type <= 320) return true;
    // 其余所有 type 均关联订单
    return true;
  }

  Widget _buildMessage(BuildContext context, TradeNotifyItem item) {
    const bodyColor = Color(0xFF444653);
    const emphasisColor = Color(0xFF191C1E);
    final message = item.message ?? '';
    if (message.isEmpty) {
      return Text(
        'app.common.no_data'.tr,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: const Color(0xFF757684)),
      );
    }

    return Html(
      data: message,
      style: {
        '*': Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          color: bodyColor,
          fontSize: FontSize(14),
          fontWeight: FontWeight.w400,
          lineHeight: LineHeight.number(1.625),
        ),
        'html': Style(margin: Margins.zero, padding: HtmlPaddings.zero),
        'body': Style(margin: Margins.zero, padding: HtmlPaddings.zero),
        'p': Style(margin: Margins.zero, padding: HtmlPaddings.zero),
        'span': Style(color: bodyColor),
        'strong': Style(color: emphasisColor, fontWeight: FontWeight.w600),
        'b': Style(color: emphasisColor, fontWeight: FontWeight.w600),
      },
    );
  }

  Widget _buildViewOrderButton(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w600,
      height: 20 / 14,
    );

    return SizedBox(
      width: double.infinity,
      height: 44,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFF1E40AF),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.05),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              // 跳转到出售页面的出售记录 tab
              final navController = Get.isRegistered<NavController>()
                  ? Get.find<NavController>()
                  : Get.put(NavController(), permanent: true);
              navController.switchToShopTab(NavController.shopTabSaleRecord);
              Get.until((route) => route.isFirst);
            },
            child: Center(child: Text(_viewOrderLabel(), style: textStyle)),
          ),
        ),
      ),
    );
  }

  Widget _buildDeliverNowButton(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w600,
      height: 20 / 14,
    );

    return SizedBox(
      width: double.infinity,
      height: 44,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF3B82F6), Color(0xFF00288E)],
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(59, 130, 246, 0.35),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              // 跳转到出售页面的待发货 tab
              final navController = Get.isRegistered<NavController>()
                  ? Get.find<NavController>()
                  : Get.put(NavController(), permanent: true);
              navController.switchToShopTab(NavController.shopTabPending);
              Get.until((route) => route.isFirst);
            },
            child: Center(child: Text(_deliverNowLabel(), style: textStyle)),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard(BuildContext context, TradeNotifyItem item) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.04),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    _statusHeadline(item),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF191C1E),
                      fontWeight: FontWeight.w700,
                      height: 20 / 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    _formatTime(item.createTime),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF757684),
                      fontWeight: FontWeight.w500,
                      height: 16 / 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildMessage(context, item),
            const SizedBox(height: 20),
            if (_needsDeliver(item.type))
              _buildDeliverNowButton(context)
            else if (_hasRelatedOrder(item.type))
              _buildViewOrderButton(context),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    return Scaffold(
      appBar: SettingsStyleAppBar(
        title: Text('app.system.notice.transaction'.tr),
      ),
      body: Container(
        color: const Color(0xFFF7F9FB),
        child: item == null
            ? Center(child: Text('app.common.no_data'.tr))
            : Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 390),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                    children: [_buildDetailCard(context, item)],
                  ),
                ),
              ),
      ),
    );
  }
}
