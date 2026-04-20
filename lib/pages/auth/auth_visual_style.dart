import 'package:flutter/material.dart';
import 'package:tronskins_app/common/widgets/scale_button.dart';

class AuthVisualStyle {
  const AuthVisualStyle._();

  static const background = Color(0xFFF7F9FB);
  static const backgroundEnd = Color(0xFFF0F4F8);
  static const surface = Colors.white;
  static const text = Color(0xFF191C1E);
  static const mutedText = Color(0xFF757684);
  static const inputFill = Color(0xFFF2F4F6);
  static const border = Color(0xFFE6E8EA);
  static const primary = Color(0xFF1E40AF);
  static const primaryEnd = Color(0xFF3B82F6);
  static const darkButton = Color(0xFF191C1E);
  static const softButton = Color(0xFFE6E8EA);
  static const actionText = Color(0xFF00288E);

  static const screenGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [background, backgroundEnd],
  );

  static TextStyle titleStyle({double fontSize = 28}) {
    return TextStyle(
      color: text,
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.4,
      height: 1.12,
    );
  }

  static const subtitleStyle = TextStyle(
    color: mutedText,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.55,
  );
}

class AuthCard extends StatelessWidget {
  const AuthCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 24, 20, 22),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AuthVisualStyle.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.88)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 36,
            offset: const Offset(0, 22),
          ),
        ],
      ),
      child: child,
    );
  }
}

class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: AuthVisualStyle.titleStyle(
            fontSize: 28,
          ).copyWith(letterSpacing: 1.0),
        ),
      ],
    );
  }
}

class AuthPageHeader extends StatelessWidget {
  const AuthPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AuthVisualStyle.titleStyle()),
        const SizedBox(height: 10),
        Text(subtitle, style: AuthVisualStyle.subtitleStyle),
      ],
    );
  }
}

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return ScaleButton(
      onPressed: enabled ? onPressed : null,
      scale: 0.97,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: enabled || loading
                ? const [AuthVisualStyle.primary, AuthVisualStyle.primaryEnd]
                : [
                    AuthVisualStyle.primary.withValues(alpha: 0.52),
                    AuthVisualStyle.primaryEnd.withValues(alpha: 0.52),
                  ],
          ),
          boxShadow: enabled || loading
              ? [
                  BoxShadow(
                    color: AuthVisualStyle.primaryEnd.withValues(alpha: 0.28),
                    blurRadius: 18,
                    offset: const Offset(0, 9),
                  ),
                ]
              : null,
        ),
        child: loading
            ? const SizedBox(
                width: 23,
                height: 23,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.4,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
      ),
    );
  }
}

class AuthSecondaryButton extends StatelessWidget {
  const AuthSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.background = AuthVisualStyle.softButton,
    this.foreground = AuthVisualStyle.actionText,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return ScaleButton(
      onPressed: onPressed,
      scale: 0.97,
      child: Container(
        width: double.infinity,
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: foreground, size: 22),
              const SizedBox(width: 10),
            ],
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthInlineActionButton extends StatelessWidget {
  const AuthInlineActionButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: enabled
              ? AuthVisualStyle.primary
              : AuthVisualStyle.softButton,
          foregroundColor: enabled ? Colors.white : AuthVisualStyle.mutedText,
          disabledForegroundColor: AuthVisualStyle.mutedText,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(0, 38),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
