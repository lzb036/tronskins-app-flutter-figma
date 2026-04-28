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
  const ShopStoreInfoMetric({required this.label, required this.value});

  final String label;
  final String value;
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
  final bool showChevron;
  final Widget? trailing;

  static const Color _cardColor = Colors.white;
  static const Color _textPrimary = Color(0xFF191C1E);
  static const Color _textSecondary = Color(0xFF757684);
  static const Color _brandBlue = Color(0xFF3B82F6);
  static const Color _dividerColor = Color(0xFFE7ECF3);
  static const Color _avatarSurface = Color(0xFFF1F5F9);
  static const Color _successGreen = Color(0xFF22C55E);

  @override
  Widget build(BuildContext context) {
    final content = Ink(
      padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(25, 28, 30, 0.06),
            blurRadius: 28,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          _ShopStoreAvatar(
            avatarUrl: avatarUrl,
            fallbackIcon: fallbackIcon,
            showOnline: showOnline,
          ),
          const SizedBox(width: 12),
          Expanded(child: _buildIdentity()),
          if (metrics.isNotEmpty) ...[
            const SizedBox(width: 12),
            Container(width: 1, height: 60, color: _dividerColor),
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
            height: 22 / 16,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
          height: 14 / 10,
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
      constraints: const BoxConstraints(minWidth: 70, maxWidth: 86),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: metrics.take(2).map(_buildMetric).toList(growable: false),
      ),
    );
  }

  Widget _buildMetric(ShopStoreInfoMetric metric) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
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
              height: 12 / 10,
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
                style: const TextStyle(
                  color: _brandBlue,
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
    required this.showOnline,
  });

  final String avatarUrl;
  final IconData fallbackIcon;
  final bool showOnline;

  static const double _size = 58;

  @override
  Widget build(BuildContext context) {
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
                  size: 28,
                )
              : CachedNetworkImage(
                  imageUrl: avatarUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Icon(
                    fallbackIcon,
                    color: ShopStoreInfoCard._textSecondary,
                    size: 28,
                  ),
                  errorWidget: (_, __, ___) => Icon(
                    fallbackIcon,
                    color: ShopStoreInfoCard._textSecondary,
                    size: 28,
                  ),
                ),
        ),
        if (showOnline)
          Positioned(
            right: 2,
            bottom: 2,
            child: Container(
              width: 11,
              height: 11,
              decoration: const BoxDecoration(
                color: ShopStoreInfoCard._successGreen,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}
