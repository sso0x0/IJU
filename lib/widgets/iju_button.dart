import 'package:material_ui/material_ui.dart';

import '../app/colors.dart';

enum IjuButtonType { primary, secondary }

/// Figma 컴포넌트 'Button' (Type=Primary / Secondary).
class IjuButton extends StatelessWidget {
  const IjuButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.type = IjuButtonType.primary,
    this.height = 56,
  });

  final String label;
  final VoidCallback? onPressed;
  final IjuButtonType type;
  final double height;

  @override
  Widget build(BuildContext context) {
    final isPrimary = type == IjuButtonType.primary;
    return SizedBox(
      height: height,
      child: Material(
        color: isPrimary ? AppColors.primary : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
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
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isPrimary ? FontWeight.w700 : FontWeight.w400,
                  color: isPrimary ? Colors.white : AppColors.text,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
