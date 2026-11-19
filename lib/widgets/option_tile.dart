import 'package:material_ui/material_ui.dart';

import '../app/colors.dart';

/// 선택형 카드 (Figma 'LangOption', 'MenuOption'의 선택됨/기본 상태).
/// 선택되면 초록 배경, 기본은 흰 배경 + 회색 테두리. 글자색은 [child]에서 정합니다.
class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.selected,
    required this.child,
    this.onTap,
    this.height = 56,
    this.radius = 14,
    this.padding = EdgeInsets.zero,
  });

  final bool selected;
  final Widget child;
  final VoidCallback? onTap;
  final double height;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Material(
        color: selected ? AppColors.primary : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: selected
              ? const BorderSide(color: AppColors.primary, width: 2)
              : const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
