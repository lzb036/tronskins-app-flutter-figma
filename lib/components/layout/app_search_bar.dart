import 'package:flutter/material.dart';

const _kSearchBarHeight = 40.0;
const _kSearchBarRadius = 12.0;
const _kSearchBarBackground = Color(0xFFF1F5F9);
const _kSearchBarIconColor = Color(0xFF94A3B8);
const _kSearchBarHintColor = Color(0xFF6B7280);
const _kSearchBarTextColor = Color(0xFF1E293B);

class AppSearchTriggerBar extends StatelessWidget {
  const AppSearchTriggerBar({
    super.key,
    required this.hintText,
    required this.onTap,
    this.text,
    this.onClearTap,
  });

  final String hintText;
  final VoidCallback onTap;
  final String? text;
  final VoidCallback? onClearTap;

  @override
  Widget build(BuildContext context) {
    final hasText = text != null && text!.trim().isNotEmpty;

    return Material(
      color: _kSearchBarBackground,
      borderRadius: BorderRadius.circular(_kSearchBarRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(_kSearchBarRadius),
        onTap: onTap,
        child: SizedBox(
          height: _kSearchBarHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: _kSearchBarIconColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasText ? text!.trim() : hintText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: hasText
                          ? _kSearchBarTextColor
                          : _kSearchBarHintColor,
                      fontSize: 14,
                      height: 20 / 14,
                      fontWeight: hasText ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ),
                if (hasText && onClearTap != null) ...[
                  const SizedBox(width: 6),
                  _SearchBarIconButton(
                    icon: Icons.close_rounded,
                    color: _kSearchBarHintColor,
                    onTap: onClearTap!,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppSearchInputBar extends StatelessWidget {
  const AppSearchInputBar({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.onSearchTap,
    this.onClearTap,
    this.textInputAction = TextInputAction.search,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onSearchTap;
  final VoidCallback? onClearTap;
  final TextInputAction textInputAction;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final hasKeyword = controller.text.trim().isNotEmpty;

    return Container(
      height: _kSearchBarHeight,
      decoration: BoxDecoration(
        color: _kSearchBarBackground,
        borderRadius: BorderRadius.circular(_kSearchBarRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 12, right: 6),
        child: Row(
          children: [
            const Icon(
              Icons.search_rounded,
              size: 20,
              color: _kSearchBarIconColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                readOnly: readOnly,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                textInputAction: textInputAction,
                textAlignVertical: TextAlignVertical.center,
                style: const TextStyle(
                  color: _kSearchBarTextColor,
                  fontSize: 14,
                  height: 20 / 14,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: const TextStyle(
                    color: _kSearchBarHintColor,
                    fontSize: 14,
                    height: 20 / 14,
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (hasKeyword && onClearTap != null)
              _SearchBarIconButton(
                icon: Icons.close_rounded,
                color: _kSearchBarHintColor,
                onTap: onClearTap!,
              ),
            if (onSearchTap != null)
              _SearchBarIconButton(
                icon: Icons.search_rounded,
                color: hasKeyword
                    ? const Color(0xFF64748B)
                    : _kSearchBarIconColor,
                onTap: onSearchTap!,
              ),
          ],
        ),
      ),
    );
  }
}

class _SearchBarIconButton extends StatelessWidget {
  const _SearchBarIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}
