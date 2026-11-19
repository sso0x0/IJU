import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../app/colors.dart';
import '../app/router.dart';
import 'iju_icon.dart';

/// 화면 상단 뒤로가기 + 제목 (Figma 'Header').
class IjuHeader extends StatelessWidget {
  const IjuHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.backgroundColor,
  });

  final String title;
  final String? subtitle;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go(AppRoutes.home),
              icon: const IjuIcon(IjuIcons.back, size: 22),
              tooltip: '뒤로',
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSub,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
