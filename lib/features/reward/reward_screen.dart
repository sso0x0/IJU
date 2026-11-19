import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/colors.dart';
import '../../app/router.dart';
import '../../widgets/iju_button.dart';
import '../../widgets/iju_icon.dart';

/// Figma '7 영수증 인증 · 보상'. 담당: 개발자3
/// TODO(개발자3): POST /receipts 결과(가게, 구매 품목, 쿠폰)로 교체. 지금은 시연용 고정 데이터입니다.
class RewardScreen extends StatelessWidget {
  const RewardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
                children: const [
                  _Done(),
                  SizedBox(height: 20),
                  _ReceiptSummary(
                    rows: [
                      ('가게', '[가게 이름] 정육점', false),
                      ('구매', '삼겹살 600g', false),
                      ('도달 단계', '3단계 · 빈칸 말하기', true),
                    ],
                  ),
                  SizedBox(height: 20),
                  _Coupon(amount: '[쿠폰 금액] 할인', points: 50),
                  SizedBox(height: 20),
                  _ReviewCard(
                    sentence: '삼겹살 600그램 구이용으로 주세요.',
                    next: '내일 복습: 목살 300그램 찌개용으로 주세요.',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  IjuButton(
                    label: '다음 미션 보기',
                    onPressed: () => context.go(AppRoutes.home),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: IjuTextLink(
                      label: '다음엔 4단계 혼자 말하기 도전',
                      fontSize: 15,
                      onTap: () => context.go(AppRoutes.home),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Done extends StatelessWidget {
  const _Done();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: const IjuIcon(IjuIcons.checkLarge, size: 36),
        ),
        const SizedBox(height: 10),
        const Text(
          '미션 완료!',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Hoàn thành nhiệm vụ!',
          style: TextStyle(fontSize: 15, color: AppColors.textBody),
        ),
      ],
    );
  }
}

class _ReceiptSummary extends StatelessWidget {
  const _ReceiptSummary({required this.rows});

  /// (항목, 값, 값을 굵게)
  final List<(String, String, bool)> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '영수증 인증 완료',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          for (final (label, value, bold) in rows) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSub,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Coupon extends StatelessWidget {
  const _Coupon({required this.amount, required this.points});

  final String amount;
  final int points;

  @override
  Widget build(BuildContext context) {
    const small = TextStyle(fontSize: 13, color: AppColors.couponText);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      constraints: const BoxConstraints(minHeight: 74),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '다음 방문 쿠폰',
                  style: small.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  amount,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.couponTextStrong,
                  ),
                ),
                const SizedBox(height: 4),
                const Text('같은 가게에서 30일 안에 사용', style: small),
              ],
            ),
          ),
          Text(
            '+${points}P',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.couponTextStrong,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.sentence, required this.next});

  final String sentence;
  final String next;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              IjuIcon(IjuIcons.reviewCard, size: 18),
              SizedBox(width: 8),
              Text(
                '복습 카드에 저장했어요',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            sentence,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            next,
            style: const TextStyle(fontSize: 13, color: AppColors.textBody),
          ),
        ],
      ),
    );
  }
}
