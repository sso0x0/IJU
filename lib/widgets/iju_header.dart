import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../app/colors.dart';
import '../app/router.dart';

/// 화면 상단 뒤로가기 + 제목 (Figma 'Header').
class IjuHeader extends StatelessWidget {
  const IjuHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go(AppRoutes.home),
              icon: const Icon(Icons.chevron_left, size: 26),
              color: AppColors.text,
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
                      fontSize: 12,
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
