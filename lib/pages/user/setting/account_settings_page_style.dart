import 'package:flutter/material.dart';

class AccountSettingsPalette {
  const AccountSettingsPalette._();

  static const background = Color(0xFFF7F9FB);
  static const heading = Color(0xFF1E3A8A);
  static const body = Color(0xFF64748B);
  static const label = Color.fromRGBO(30, 58, 138, 0.8);
  static const border = Color(0xFFE2E8F0);
  static const hint = Color(0xFF94A3B8);
  static const buttonStart = Color(0xFF1E40AF);
  static const buttonEnd = Color(0xFF3B82F6);
  static const buttonShadow = Color.fromRGBO(59, 130, 246, 0.2);
}

class AccountSettingsHero extends StatelessWidget {
  const AccountSettingsHero({super.key, required this.title, this.description});

  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final descriptionText = description?.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.headlineMedium?.copyWith(
            color: AccountSettingsPalette.heading,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        if (descriptionText.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            descriptionText,
            style: textTheme.bodyMedium?.copyWith(
              color: AccountSettingsPalette.body,
              fontSize: 14,
              height: 20 / 14,
            ),
          ),
        ],
      ],
    );
  }
}

class AccountSettingsPrimaryButton extends StatelessWidget {
  const AccountSettingsPrimaryButton({
    super.key,
    required this.child,
    this.onPressed,
  });

  final Widget child;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.72,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              AccountSettingsPalette.buttonStart,
              AccountSettingsPalette.buttonEnd,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: AccountSettingsPalette.buttonShadow,
              blurRadius: 15,
              offset: Offset(0, 10),
              spreadRadius: -3,
            ),
            BoxShadow(
              color: AccountSettingsPalette.buttonShadow,
              blurRadius: 6,
              offset: Offset(0, 4),
              spreadRadius: -4,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration buildAccountSettingsInputDecoration({
  required String hintText,
  Widget? prefixIcon,
  Widget? suffixIcon,
}) {
  const borderRadius = BorderRadius.all(Radius.circular(16));
  const borderSide = BorderSide(color: AccountSettingsPalette.border);

  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(
      color: AccountSettingsPalette.hint,
      fontSize: 16,
      height: 1.4,
    ),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    border: const OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: borderSide,
    ),
    enabledBorder: const OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: borderSide,
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(
        color: AccountSettingsPalette.buttonStart,
        width: 1.2,
      ),
    ),
  );
}

class AccountSettingsTipLine extends StatelessWidget {
  const AccountSettingsTipLine({
    super.key,
    required this.child,
    this.icon = Icons.info_outline,
    this.topPadding = 0,
  });

  final Widget child;
  final IconData icon;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topPadding, left: 4, right: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 15, color: AccountSettingsPalette.body),
          ),
          const SizedBox(width: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class AccountSettingsFooterNote extends StatelessWidget {
  const AccountSettingsFooterNote({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final footerText = text.trim();
    if (footerText.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        footerText,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AccountSettingsPalette.hint,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1.5,
          letterSpacing: 2,
        ),
      ),
    );
  }
}
