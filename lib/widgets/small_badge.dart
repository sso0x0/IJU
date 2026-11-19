import 'package:material_ui/material_ui.dart';

import '../app/colors.dart';

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
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: strong ? Colors.white : AppColors.primaryDark,
        ),
      ),
    );
  }
}
