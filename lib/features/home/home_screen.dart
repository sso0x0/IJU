import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/colors.dart';
import '../../app/router.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/iju_icon.dart';
import '../../widgets/iju_tab_bar.dart';
import '../../widgets/mission_card.dart';

/// Figma '2 홈 · 미션'. 담당: 개발자1
/// TODO(개발자1): GET /missions 결과로 교체. 지금은 시연용 고정 데이터입니다.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    void startMission() => context.push(AppRoutes.menuScan);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _HomeHeader(points: 320),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  _ActiveMissionCard(
                    title: '삼겹살 600g 구이용으로 주문하기',
                    translation: 'Mua 600g thịt ba chỉ để nướng',
                    meta: '정육점 · 레벨 2',
                    progressLabel: '연습 2/3 완료',
                    rewardLabel: '보상 쿠폰 + 50P',
                    progress: 2 / 3,
                    onContinue: startMission,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '추천 미션',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 10),
                  MissionCard(
                    icon: IjuIcons.missionRestaurant,
                    title: '김치찌개 돼지고기 빼고 주문하기',
                    meta: '식당 · 레벨 2 · 숙소에서 400m',
                    // 메뉴판 인식은 정육점만 있어서 바로 문장 만들기로 갑니다.
                    onTap: () => context.push(
                      '${AppRoutes.compose}?scenario=restaurant',
                    ),
                  ),
                  const SizedBox(height: 10),
                  MissionCard(
                    icon: IjuIcons.missionBasket,
                    title: '반찬 두 가지 골라 담기',
                    meta: '반찬가게 · 레벨 1 · 숙소에서 1.2km',
                    onTap: () =>
                        context.push('${AppRoutes.compose}?scenario=side_dish'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const IjuTabBar(current: IjuTab.home),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.points});

  final int points;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              AppLocalizations.of(context).appName,
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          PointsBadge(points: points),
        ],
      ),
    );
  }
}

class _ActiveMissionCard extends StatelessWidget {
  const _ActiveMissionCard({
    required this.title,
    required this.translation,
    required this.meta,
    required this.progressLabel,
    required this.rewardLabel,
    required this.progress,
    required this.onContinue,
  });

  final String title;
  final String translation;
  final String meta;
  final String progressLabel;
  final String rewardLabel;
  final double progress;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    const small = TextStyle(fontSize: 13, color: Colors.white);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '진행 중 미션',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(meta, style: small),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            translation,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.onPrimaryMuted,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(progressLabel, style: small),
              Text(rewardLabel, style: small),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.primaryDark,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 48,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onContinue,
                child: const Center(
                  child: Text(
                    '이어서 하기',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
