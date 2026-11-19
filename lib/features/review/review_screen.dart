import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/colors.dart';
import '../../app/router.dart';
import '../../widgets/iju_button.dart';
import '../../widgets/iju_icon.dart';
import '../../widgets/iju_tab_bar.dart';
import '../../widgets/mission_card.dart';
import '../practice/practice_screen.dart';
import '../scenario/scenarios.dart';

/// 복습 탭: 미션을 끝내고 저장한 문장 카드 목록.
/// Figma에는 이 화면이 없어 '7 영수증 인증 · 보상'의 ReviewCard 스타일로 만들었습니다.
/// TODO(개발자3): 서버에 저장한 복습 카드 목록으로 교체. 지금은 시연용 고정 데이터입니다.
class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});

  static const _cards = [
    _Review(
      sentence: '목살 300그램 찌개용으로 주세요.',
      meaning: 'Cho tôi 300g thịt nạc vai để nấu canh.',
      scenario: butcher,
      due: '오늘',
      score: 76,
    ),
    _Review(
      sentence: '삼겹살 600그램 구이용으로 주세요.',
      meaning: 'Cho tôi 600g thịt ba chỉ để nướng.',
      scenario: butcher,
      due: '내일',
      score: 82,
    ),
    _Review(
      sentence: '제육볶음 하나 덜 맵게 해 주세요.',
      meaning: 'Cho tôi một phần thịt heo xào, ít cay.',
      scenario: restaurant,
      due: '3일 뒤',
      score: 90,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final today = _cards.where((c) => c.due == '오늘').length;

    return IjuTabScaffold(
      tab: IjuTab.review,
      title: '복습',
      sub: 'Ôn tập',
      children: [
        _TodaySummary(today: today, total: _cards.length),
        const IjuListTitle('저장한 문장'),
        for (final card in _cards) ...[
          _ReviewCard(
            review: card,
            onPractice: () => context.push(
              AppRoutes.practice,
              extra: PracticeArgs(
                sentence: card.sentence,
                meaning: card.meaning,
                scenario: card.scenario,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _Review {
  const _Review({
    required this.sentence,
    required this.meaning,
    required this.scenario,
    required this.due,
    required this.score,
  });

  final String sentence;
  final String meaning;
  final Scenario scenario;

  /// 다음 복습 날 ('오늘', '내일', 'N일 뒤')
  final String due;

  /// 마지막 발음 점수
  final int score;
}

class _TodaySummary extends StatelessWidget {
  const _TodaySummary({required this.today, required this.total});

  final int today;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const IjuIcon(
              IjuIcons.reviewCard,
              size: 24,
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
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '저장한 문장 $total개 · 잊기 전에 다시 말해 봐요',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.onPrimaryMuted,
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
  const _ReviewCard({required this.review, required this.onPractice});

  final _Review review;
  final VoidCallback onPractice;

  @override
  Widget build(BuildContext context) {
    final isToday = review.due == '오늘';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: isToday ? Border.all(color: AppColors.primary) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${review.scenario.place} · 지난 점수 ${review.score}점',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSub,
                  ),
                ),
              ),
              SmallBadge('${review.due} 복습', strong: isToday),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            review.sentence,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            review.meaning,
            style: const TextStyle(fontSize: 13, color: AppColors.textBody),
          ),
          const SizedBox(height: 14),
          IjuButton(
            label: '다시 말해 보기',
            type: isToday ? IjuButtonType.primary : IjuButtonType.secondary,
            height: 44,
            radius: 12,
            fontSize: 14,
            onPressed: onPractice,
          ),
        ],
      ),
    );
  }
}
