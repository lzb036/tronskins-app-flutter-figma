import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/routes/app_routes.dart';

class LoginRequiredPrompt extends StatelessWidget {
  const LoginRequiredPrompt({super.key});

  static const _cardBackground = Color(0xFFF3F7FF);
  static const _cardBorder = Color(0xFFD9E5FF);
  static const _titleColor = Color(0xFF2547C8);
  static const _subtitleColor = Color(0xFF5C7AB3);
  static const _iconBackground = Color(0xFFE4EEFF);
  static const _iconColor = Color(0xFF355DDB);
  static const _buttonBackground = Color(0xFF2A58D8);

  void _goLogin() => Get.toNamed(Routers.LOGIN);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final horizontalPadding = compact ? 12.0 : 16.0;
        final topPadding = compact ? 88.0 : 96.0;
        final content = Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            topPadding,
            horizontalPadding,
            24,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 12 : 14,
                  vertical: compact ? 12 : 14,
                ),
                decoration: BoxDecoration(
                  color: _cardBackground,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _cardBorder),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromRGBO(37, 71, 200, 0.06),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildStatusIcon(compact),
                    SizedBox(width: compact ? 10 : 12),
                    Expanded(child: _buildCopyBlock(compact)),
                    SizedBox(width: compact ? 10 : 12),
                    _buildLoginButton(compact),
                  ],
                ),
              ),
            ),
          ),
        );

        if (!constraints.hasBoundedHeight) {
          return content;
        }

        return SizedBox(
          width: double.infinity,
          height: constraints.maxHeight,
          child: content,
        );
      },
    );
  }

  Widget _buildStatusIcon(bool compact) {
    final size = compact ? 34.0 : 38.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _iconBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Icon(
        Icons.account_circle_outlined,
        size: compact ? 20 : 22,
        color: _iconColor,
      ),
    );
  }

  Widget _buildCopyBlock(bool compact) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'app.user.login.required_title'.tr,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _titleColor,
            fontSize: compact ? 14 : 15,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'app.user.login.required_subtitle'.tr,
          maxLines: compact ? 3 : 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _subtitleColor,
            fontSize: compact ? 11.5 : 12,
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton(bool compact) {
    return SizedBox(
      width: compact ? 84 : 92,
      height: compact ? 38 : 40,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _goLogin,
          child: Ink(
            decoration: BoxDecoration(
              color: _buttonBackground,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(42, 88, 216, 0.24),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                'app.user.login.title'.tr,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 14 : 15,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
