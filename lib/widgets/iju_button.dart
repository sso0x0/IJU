import 'package:material_ui/material_ui.dart';

import '../app/colors.dart';
import '../app/theme.dart';

/// 디자인 시스템 '버튼'.
/// - primary: 초록 채움 (화면당 1개, 하단 고정)
/// - secondary: 흰 바탕 + 초록 2px 테두리
/// - ghost: 바탕·테두리 없는 초록 글자
///
/// [onPressed]가 null이면 회색 비활성 모양이 됩니다.
/// 카드 안의 작은 버튼은 height 44~48, radius 12, fontSize 14~15로 씁니다.
enum IjuButtonType { primary, secondary, ghost }

class IjuButton extends StatelessWidget {
  const IjuButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.type = IjuButtonType.primary,
    this.sub,
    this.icon,
    this.height = AppSpace.buttonHeight,
    this.radius = AppRadius.button,
    this.fontSize = 18,
  });

  final String label;

  /// 한국어 뒤에 붙는 모국어 보조 문구 (예: '· Bắt đầu').
  final String? sub;
  final IconData? icon;
  final VoidCallback? onPressed;
  final IjuButtonType type;
  final double height;
  final double radius;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final (Color bg, Color fg, BorderSide side) = switch (type) {
      _ when !enabled && type == IjuButtonType.primary => (
        AppColors.disabledBg,
        AppColors.disabledText,
        BorderSide.none,
      ),
      IjuButtonType.primary => (
        AppColors.primary,
        Colors.white,
        BorderSide.none,
      ),
      IjuButtonType.secondary => (
        AppColors.surface,
        enabled ? AppColors.primaryDark : AppColors.disabledText,
        BorderSide(
          color: enabled ? AppColors.primary : AppColors.disabledBg,
          width: 2,
        ),
      ),
      IjuButtonType.ghost => (
        Colors.transparent,
        enabled ? AppColors.primaryDark : AppColors.disabledText,
        BorderSide.none,
      ),
    };
    return SizedBox(
      height: height,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: side,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          highlightColor: type == IjuButtonType.primary
              ? AppColors.primary900.withValues(alpha: 0.35)
              : null,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              // 좁은 화면에서는 글자를 자르지 않고 살짝 줄여서 다 보여줍니다.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: fontSize + 4, color: fg),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w700,
                        color: fg,
                      ),
                    ),
                    if (sub != null) ...[
                      const SizedBox(width: 8),
                      Opacity(
                        opacity: 0.88,
                        child: Text(
                          '· $sub',
                          maxLines: 1,
                          style: AppText.native.copyWith(
                            fontSize: fontSize - 3,
                            color: fg,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 밑줄 친 초록 글자 링크 ('비밀번호를 잊었어요', '실전으로 가기' 등).
class IjuTextLink extends StatelessWidget {
  const IjuTextLink({
    super.key,
    required this.label,
    required this.onTap,
    this.fontSize = 15,
    this.bold = false,
  });

  final String label;
  final VoidCallback? onTap;
  final double fontSize;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                color: AppColors.primaryDark,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.primaryDark,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
