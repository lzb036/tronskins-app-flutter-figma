import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ShopStoreInfoBadge {
  const ShopStoreInfoBadge({
    required this.label,
    this.onTap,
    this.backgroundColor = const Color(0xFFDCE8FF),
    this.foregroundColor = const Color(0xFF2F6FCB),
  });

  final String label;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final Color foregroundColor;
}

class ShopStoreInfoMetric {
  const ShopStoreInfoMetric({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;
}

class ShopStoreInfoCard extends StatelessWidget {
  const ShopStoreInfoCard({
    super.key,
    required this.title,
    required this.avatarUrl,
    this.badges = const <ShopStoreInfoBadge>[],
    this.metrics = const <ShopStoreInfoMetric>[],
    this.onTap,
    this.fallbackIcon = Icons.storefront_outlined,
    this.showOnline = false,
    this.isOnline,
    this.showChevron = false,
    this.trailing,
  });

  final String title;
  final String avatarUrl;
  final List<ShopStoreInfoBadge> badges;
  final List<ShopStoreInfoMetric> metrics;
  final VoidCallback? onTap;
  final IconData fallbackIcon;
  final bool showOnline;
  final bool? isOnline;
  final bool showChevron;
  final Widget? trailing;

  static const Color _cardColor = Colors.white;
  static const Color _textPrimary = Color(0xFF191C1E);
  static const Color _textSecondary = Color(0xFF757684);
  static const Color _metricBlue = Color(0xFF8DA8F8);
  static const Color _dividerColor = Color(0xFFE9EDF3);
  static const Color _avatarSurface = Color(0xFFF2F4F7);
  static const Color _successGreen = Color(0xFF22C55E);
  static const Color _offlineGray = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) {
    final avatarOnline = isOnline ?? (showOnline ? true : null);
    final content = Ink(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(15, 23, 42, 0.10),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _ShopStoreAvatar(
            avatarUrl: avatarUrl,
            fallbackIcon: fallbackIcon,
            online: avatarOnline,
          ),
          const SizedBox(width: 12),
          Expanded(child: _buildIdentity()),
          if (metrics.isNotEmpty) ...[
            const SizedBox(width: 12),
            Container(width: 1, height: 62, color: _dividerColor),
            const SizedBox(width: 12),
            _buildMetrics(),
          ],
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          if (showChevron) ...[
            const SizedBox(width: 2),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: _textSecondary,
            ),
          ],
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: content,
      ),
    );
  }

  Widget _buildIdentity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _textPrimary,
            fontSize: 16,
            height: 20 / 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (badges.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: badges.map(_buildBadge).toList(growable: false),
          ),
        ],
      ],
    );
  }

  Widget _buildBadge(ShopStoreInfoBadge badge) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: badge.backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        badge.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: badge.foregroundColor,
          fontSize: 10,
          height: 13 / 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    if (badge.onTap == null) {
      return chip;
    }
    return GestureDetector(
      onTap: badge.onTap,
      behavior: HitTestBehavior.opaque,
      child: chip,
    );
  }

  Widget _buildMetrics() {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 72, maxWidth: 88),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: metrics
            .take(2)
            .toList(growable: false)
            .asMap()
            .entries
            .map((entry) => _buildMetric(entry.value, entry.key))
            .toList(growable: false),
      ),
    );
  }

  Widget _buildMetric(ShopStoreInfoMetric metric, int index) {
    return Padding(
      padding: EdgeInsets.only(bottom: index == 0 ? 8 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            metric.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 10,
              height: 11 / 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                metric.value,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color:
                      metric.valueColor ??
                      (index == 0 ? _textPrimary : _metricBlue),
                  fontSize: 15,
                  height: 17 / 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopStoreAvatar extends StatelessWidget {
  const _ShopStoreAvatar({
    required this.avatarUrl,
    required this.fallbackIcon,
    required this.online,
  });

  final String avatarUrl;
  final IconData fallbackIcon;
  final bool? online;

  static const double _size = 64;

  @override
  Widget build(BuildContext context) {
    final currentOnline = online;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: _size,
          height: _size,
          decoration: const BoxDecoration(
            color: ShopStoreInfoCard._avatarSurface,
            shape: BoxShape.circle,
          ),
          clipBehavior: Clip.hardEdge,
          child: avatarUrl.isEmpty
              ? Icon(
                  fallbackIcon,
                  color: ShopStoreInfoCard._textSecondary,
                  size: 32,
                )
              : CachedNetworkImage(
                  imageUrl: avatarUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Icon(
                    fallbackIcon,
                    color: ShopStoreInfoCard._textSecondary,
                    size: 32,
                  ),
                  errorWidget: (_, __, ___) => Icon(
                    fallbackIcon,
                    color: ShopStoreInfoCard._textSecondary,
                    size: 32,
                  ),
                ),
        ),
        if (currentOnline != null)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 15,
              height: 15,
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: currentOnline
                      ? ShopStoreInfoCard._successGreen
                      : ShopStoreInfoCard._offlineGray,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
