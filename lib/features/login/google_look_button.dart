import 'package:material_ui/material_ui.dart';

import '../../app/colors.dart';
import '../../app/theme.dart';

/// 다른 버튼(56 높이 · 둥근 16 · 테두리 2)과 같은 크기의 'Google로 계속하기' 버튼 모양.
///
/// 웹에서는 이 버튼 위에 구글 공식 버튼을 투명하게 겹쳐 눌리게 하고,
/// 앱에서는 [onTap]으로 안내를 띄워요.
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

/// 구글 'G' 표시 (네 가지 색).
class _GoogleG extends StatelessWidget {
  const _GoogleG();

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (rect) => const SweepGradient(
        colors: [
          Color(0xFFEA4335),
          Color(0xFFFBBC05),
          Color(0xFF34A853),
          Color(0xFF4285F4),
          Color(0xFFEA4335),
        ],
        stops: [0, 0.25, 0.5, 0.75, 1],
      ).createShader(rect),
      child: const Text(
        'G',
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 22,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}
