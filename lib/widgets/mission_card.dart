import 'package:material_ui/material_ui.dart';

import '../app/colors.dart';
import 'iju_icon.dart';

/// Figma 'MissionCard' (아이콘 + 제목 + 가게·레벨·거리).
/// [trailing]에는 '완료' 같은 작은 표시를 넣을 수 있습니다.
class MissionCard extends StatelessWidget {
  const MissionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.meta,
    required this.onTap,
    this.trailing,
    this.muted = false,
  });

  final String icon; // IjuIcons 이름
  final String title;
  final String meta;
  final VoidCallback? onTap;
  final Widget? trailing;

  /// 끝난 미션처럼 흐리게 보여 줄 때
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: muted ? AppColors.background : AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: IjuIcon(
                  icon,
                  size: 22,
                  color: muted ? AppColors.textSub : null,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: muted ? AppColors.textSub : AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSub,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

/// 카드 오른쪽의 작은 둥근 표시 (예: '완료', '오늘').
class SmallBadge extends StatelessWidget {
  const SmallBadge(this.label, {super.key, this.strong = false});

  final String label;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: strong ? AppColors.primary : AppColors.primarySoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: strong ? Colors.white : AppColors.primaryDark,
        ),
      ),
    );
  }
}
