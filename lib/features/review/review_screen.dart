import 'package:go_router/go_router.dart';

import '../../app/languages.dart';

import 'package:material_ui/material_ui.dart';

import '../../app/colors.dart';
import '../../app/theme.dart';
import '../../app/router.dart';
import '../../widgets/iju_button.dart';
import '../../widgets/iju_icon.dart';
import '../../widgets/iju_tab_bar.dart';
import '../../widgets/small_badge.dart';
import 'review_steps_screen.dart';
import 'review_store.dart';

/// 복습 탭: 내가 한 미션 문장 목록. 문장마다 3단계로 복습합니다.
///
/// 1단계 전에 한 문장 그대로 → 2단계 카드 하나를 바꾼 문장 → 3단계 더 길어진 문장을
/// 뜻만 보고 말하기. 단계를 끝낼 때마다 다음 복습 날이 1·3·7일 뒤로 밀립니다.
/// Figma에는 이 화면이 없어 '7 영수증 인증 · 보상'의 ReviewCard 스타일로 만들었습니다.
class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: ReviewStore.items,
      builder: (context, items, _) {
        final now = DateTime.now();
        final today = items.where((c) => c.dueLabel(now) == '오늘').length;
        return IjuTabScaffold(
          tab: IjuTab.review,
          title: '복습',
          sub: nt('Ôn tập'),
          trailing: _MapButton(onTap: () => context.push(AppRoutes.orderMap)),
          children: [
            _TodaySummary(today: today, total: items.length),
            const IjuListTitle('내가 한 미션 문장'),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    '미션을 연습하면 여기에 문장이 쌓여요',
                    style: TextStyle(fontSize: 15, color: AppColors.textSub),
                  ),
                ),
              ),
            for (final item in items) ...[
              _ReviewCard(
                item: item,
                due: item.dueLabel(now),
                onPractice: () {
                  final stage = item.stage;
                  final (sentence, meaning) = item.textFor(stage);
                  // 보여주기 → 따라 말하기 → 빈칸 말하기 → 혼자 말하기 순서로 복습해요.
                  context.push(
                    AppRoutes.reviewSteps,
                    extra: ReviewStepsArgs(
                      sentence: sentence,
                      meaning: meaning,
                      reviewId: item.id,
                      stage: stage,
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _TodaySummary extends StatelessWidget {
  const _TodaySummary({required this.today, required this.total});

  final int today;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary50,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.primarySoft),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const IjuIcon(
              IjuIcons.reviewCard,
              size: 26,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '오늘 복습할 문장 $today개',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '미션 문장 $total개 · 1→2→3단계로 점점 어렵게',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textBody,
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

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.item,
    required this.due,
    required this.onPractice,
  });

  final ReviewItem item;
  final String due;
  final VoidCallback onPractice;

  @override
  Widget build(BuildContext context) {
    final isToday = due == '오늘';
    final stage = item.stage;
    final (sentence, meaning) = item.textFor(stage);
    final hide = stage == ReviewStage.hard;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: isToday
            ? Border.all(color: AppColors.primary, width: 2)
            : Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  [
                    item.scenario.place,
                    if (item.score != null) '지난 점수 ${item.score}점',
                  ].join(' · '),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSub,
                  ),
                ),
              ),
              SmallBadge(item.done ? '완료 · $due' : '$due 복습', strong: isToday),
            ],
          ),
          const SizedBox(height: 10),
          _StageSteps(cleared: item.cleared, current: stage),
          const SizedBox(height: 10),
          Text(
            '${stage.number}단계 · ${stage.description}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 6),
          // 3단계는 한국어를 가리고 뜻만 보여 줍니다.
          Text(
            hide ? meaning : sentence,
            style: const TextStyle(
              fontSize: 22,
              height: 1.35,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          if (!hide) ...[
            const SizedBox(height: 4),
            Text(meaning, style: AppText.native),
          ],
          if (stage != ReviewStage.same) ...[
            const SizedBox(height: 6),
            Text(
              '처음 문장: ${item.sentence}',
              style: const TextStyle(fontSize: 14, color: AppColors.textSub),
            ),
          ],
          const SizedBox(height: 14),
          IjuButton(
            label: '${stage.number}단계 · ${stage.action}',
            type: isToday ? IjuButtonType.primary : IjuButtonType.secondary,
            height: 48,
            radius: 14,
            fontSize: 16,
            onPressed: onPractice,
          ),
        ],
      ),
    );
  }
}

/// 1·2·3단계 진행 표시. 끝낸 단계는 채우고 지금 단계는 테두리만.
class _StageSteps extends StatelessWidget {
  const _StageSteps({required this.cleared, required this.current});

  final int cleared;
  final ReviewStage current;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final s in ReviewStage.values) ...[
          if (s.number > 1) const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: s.number <= cleared
                    ? AppColors.primary
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  width: 1.5,
                  color: s == current || s.number <= cleared
                      ? AppColors.primary
                      : AppColors.border,
                ),
              ),
              child: Text(
                '${s.number}단계${s.number <= cleared ? ' ✓' : ''}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: s.number <= cleared
                      ? Colors.white
                      : s == current
                      ? AppColors.primaryDark
                      : AppColors.textSub,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 주문 지도로 가는 버튼 (영수증 인증한 가게 모음).
class _MapButton extends StatelessWidget {
  const _MapButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Material(
        color: AppColors.surface,
        shape: const StadiumBorder(side: BorderSide(color: AppColors.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.map_outlined, size: 20, color: AppColors.primary),
                SizedBox(width: 6),
                Text(
                  '주문 지도',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
