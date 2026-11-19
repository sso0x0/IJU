import 'package:material_ui/material_ui.dart';

import '../app/colors.dart';

enum IjuButtonType { primary, secondary }

/// Figma 컴포넌트 'Button' (Type=Primary / Secondary).
/// 카드 안의 작은 버튼은 height 44~48, radius 12, fontSize 14~15로 씁니다.
class IjuButton extends StatelessWidget {
  const IjuButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.type = IjuButtonType.primary,
    this.height = 56,
    this.radius = 16,
    this.fontSize = 16,
  });

  final String label;
  final VoidCallback? onPressed;
  final IjuButtonType type;
  final double height;
  final double radius;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final isPrimary = type == IjuButtonType.primary;
    return SizedBox(
      height: height,
      child: Material(
        color: isPrimary ? AppColors.primary : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: isPrimary
              ? BorderSide.none
              : const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              // 좁은 화면에서는 글자를 자르지 않고 살짝 줄여서 다 보여줍니다.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: isPrimary ? FontWeight.w700 : FontWeight.w400,
                    color: isPrimary ? Colors.white : AppColors.text,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 밑줄 친 초록 글자 링크 (Figma '비밀번호를 잊었어요', '실전으로 가기' 등).
class IjuTextLink extends StatelessWidget {
  const IjuTextLink({
    super.key,
    required this.label,
    required this.onTap,
    this.fontSize = 14,
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
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            color: AppColors.primary,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.primary,
          ),
        ),
      ),
    );
  }
}
