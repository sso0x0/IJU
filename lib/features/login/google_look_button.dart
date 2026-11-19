import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/colors.dart';
import '../../app/theme.dart';

/// 다른 버튼(56 높이 · 둥근 16 · 테두리 2)과 같은 크기의 'Google로 계속하기' 버튼 모양.
///
/// 웹에서는 이 버튼 위에 구글 공식 버튼을 투명하게 겹쳐 눌리게 하고,
/// 앱(Android)에서는 [onTap]으로 기기 구글 계정 선택 창을 띄워요.
class GoogleLookButton extends StatelessWidget {
  const GoogleLookButton({super.key, required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSpace.buttonHeight,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          side: const BorderSide(color: AppColors.border, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const _GoogleG(),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 구글 공식 'G' 로고 (assets/icons/google.svg).
class _GoogleG extends StatelessWidget {
  const _GoogleG();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/google.svg',
      width: 22,
      height: 22,
      excludeFromSemantics: true,
    );
  }
}
