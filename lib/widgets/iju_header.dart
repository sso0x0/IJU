import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../app/colors.dart';
import '../app/router.dart';
import '../app/theme.dart';
import 'iju_icon.dart';

/// 화면 상단 뒤로가기 + 제목 (디자인 시스템 '헤더'). 아이콘 버튼도 48×48.
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
      padding: const EdgeInsets.fromLTRB(8, 12, 20, 8),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go(AppRoutes.home),
              icon: const IjuIcon(
                IjuIcons.back,
                size: 24,
                color: AppColors.text,
              ),
              tooltip: '뒤로',
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppText.subtitle),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: AppText.native.copyWith(
                      fontSize: 14,
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
