import 'package:material_ui/material_ui.dart';

import '../app/colors.dart';

/// 진행 표시 (01 공통 컴포넌트 '진행 표시').

/// 미션 4단계 이름.
const missionSteps = ['메뉴판 찍기', '메뉴 고르기', '말하기 연습', '주문·영수증'];

/// 미션 4단계 스테퍼. [current]는 0부터 셉니다.
/// [onPrimary]면 초록 카드 위에 흰 선으로 그립니다.
class MissionStepper extends StatelessWidget {
  const MissionStepper({
    super.key,
    required this.current,
    this.onPrimary = false,
    this.steps = missionSteps,
  });

  final int current;
  final bool onPrimary;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final line = onPrimary
        ? Colors.white.withValues(alpha: 0.45)
        : AppColors.disabledBg;
    return Stack(
      children: [
        Positioned(
          top: 13,
          left: 0,
          right: 0,
          child: FractionallySizedBox(
            widthFactor: 0.76,
            child: Container(height: 2, color: line),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < steps.length; i++) Expanded(child: _step(i)),
          ],
        ),
      ],
    );
  }

  Widget _step(int i) {
    final done = i < current;
    final now = i == current;
    final Color fill;
    final Color border;
    final Color numColor;
    final Color labelColor;
    if (onPrimary) {
      fill = done || now ? Colors.white : AppColors.primary;
      border = done || now
          ? Colors.white
          : Colors.white.withValues(alpha: 0.55);
      numColor = done || now
          ? AppColors.primaryDark
          : Colors.white.withValues(alpha: 0.85);
      labelColor = now ? Colors.white : Colors.white.withValues(alpha: 0.82);
    } else {
      fill = done || now ? AppColors.primary : AppColors.surface;
      border = done || now ? AppColors.primary : const Color(0xFFC3CAC6);
      numColor = done || now ? Colors.white : AppColors.textSub;
      labelColor = now ? AppColors.text : AppColors.textSub;
    }
    return Semantics(
      label:
          '${i + 1}단계 ${steps[i]}${now
              ? ' · 지금'
              : done
              ? ' · 완료'
              : ''}',
      excludeSemantics: true,
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: fill,
              shape: BoxShape.circle,
              border: Border.all(color: border, width: 2),
              boxShadow: now
                  ? [
                      BoxShadow(
                        color: onPrimary
                            ? Colors.white.withValues(alpha: 0.25)
                            : AppColors.primarySoft,
                        spreadRadius: 4,
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: done
                ? Icon(Icons.check, size: 16, color: numColor)
                : Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: numColor,
                    ),
                  ),
          ),
          const SizedBox(height: 6),
          Text(
            steps[i],
            maxLines: 1,
            overflow: TextOverflow.visible,
            softWrap: false,
            style: TextStyle(
              fontSize: 13,
              fontWeight: now ? FontWeight.w700 : FontWeight.w500,
              color: labelColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// 칸으로 나뉜 진행 바 (온보딩 진행 바 · 미션 카드 단계).
class SegmentBar extends StatelessWidget {
  const SegmentBar({super.key, required this.total, required this.filled});

  final int total;
  final int filled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$total단계 중 $filled단계',
      child: Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: i < filled
                      ? AppColors.primary
                      : const Color(0xFFDCE1DE),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 복습 1·2·3단계 점.
class StageDots extends StatelessWidget {
  const StageDots({super.key, required this.cleared, this.total = 3});

  final int cleared;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '복습 $cleared/$total단계',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: 5),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < cleared ? AppColors.primary : AppColors.surface,
                border: Border.all(
                  color: i < cleared
                      ? AppColors.primary
                      : const Color(0xFFC3CAC6),
                  width: 2,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
