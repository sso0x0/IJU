import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/colors.dart';
import '../../app/router.dart';
import '../../widgets/iju_button.dart';
import '../../widgets/iju_icon.dart';
import '../real_order/order_api.dart';

/// Figma '7 영수증 인증 · 보상'. 담당: 개발자3
/// 실전 주문 화면에서 영수증 인증 결과([RewardArgs])를 받아 보여 줍니다. 없으면 시연용 고정 데이터.
class RewardScreen extends StatelessWidget {
  const RewardScreen({super.key, this.args});

  final RewardArgs? args;

  static const _stepNames = ['보여주기', '따라 말하기', '빈칸 말하기', '혼자 말하기'];

  static String _won(int v) =>
      '${v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')}원';

  @override
  Widget build(BuildContext context) {
    final a = args;
    final result = a?.result;
    final step = (a?.step ?? 3).clamp(1, 4);
    final amount = result?.amount;
    final coupon = result?.coupon;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
                children: [
                  const _Done(),
                  const SizedBox(height: 20),
                  _ReceiptSummary(
                    rows: [
                      ('가게', result?.storeName ?? '[가게 이름] 정육점', false),
                      if (a == null)
                        ('구매', '삼겹살 600g', false)
                      else
                        (
                          '결제 금액',
                          amount == null ? '사장님 확인' : _won(amount),
                          false,
                        ),
                      ('도달 단계', '$step단계 · ${_stepNames[step - 1]}', true),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _Coupon(
                    amount: coupon == null
                        ? '[쿠폰 금액] 할인'
                        : '${_won(coupon.value)} 할인',
                    points: a == null ? 50 : null,
                  ),
                  const SizedBox(height: 20),
                  _ReviewCard(
                    sentence: a?.sentence ?? '삼겹살 600그램 구이용으로 주세요.',
                    next: a == null
                        ? '내일 복습: 목살 300그램 찌개용으로 주세요.'
                        : '복습 카드에서 품목만 바꿔 다시 연습해요.',
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
                  if (step < 4) ...[
                    const SizedBox(height: 20),
                    Center(
                      child: IjuTextLink(
                        label: '다음엔 ${step + 1}단계 ${_stepNames[step]} 도전',
                        fontSize: 15,
                        onTap: () => context.go(AppRoutes.home),
                      ),
                    ),
                  ],
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
  const _Coupon({required this.amount, this.points});

  final String amount;

  /// null이면 포인트 표시를 숨김
  final int? points;

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
          if (points != null)
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
