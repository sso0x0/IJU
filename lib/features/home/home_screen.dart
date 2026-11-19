import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/colors.dart';
import '../../app/router.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/iju_icon.dart';

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
                  _MissionCard(
                    icon: IjuIcons.missionRestaurant,
                    title: '제육볶음 덜 맵게 주문하기',
                    meta: '식당 · 레벨 2 · 숙소에서 400m',
                    // 메뉴판 인식은 정육점만 있어서 바로 문장 만들기로 갑니다.
                    onTap: () => context.push(
                      '${AppRoutes.compose}?scenario=restaurant',
                    ),
                  ),
                  const SizedBox(height: 10),
                  _MissionCard(
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
      bottomNavigationBar: const IjuTabBar(current: 0),
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
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.pointBg,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const IjuIcon(IjuIcons.points, size: 16),
                const SizedBox(width: 6),
                Text(
                  '$points P',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.pointText,
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

class _MissionCard extends StatelessWidget {
  const _MissionCard({
    required this.icon,
    required this.title,
    required this.meta,
    required this.onTap,
  });

  final String icon; // IjuIcons 이름
  final String title;
  final String meta;
  final VoidCallback onTap;

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
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: IjuIcon(icon, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
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
            ],
          ),
        ),
      ),
    );
  }
}

/// 하단 탭 (Figma 'TabBar'). 홈 외의 탭 화면은 아직 없습니다.
class IjuTabBar extends StatelessWidget {
  const IjuTabBar({super.key, required this.current});

  final int current;

  static const _tabs = [
    (IjuIcons.tabHome, '홈'),
    (IjuIcons.tabMission, '미션'),
    (IjuIcons.tabReview, '복습'),
    (IjuIcons.tabProfile, '내 정보'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < _tabs.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () {
                      // TODO: 미션·복습·내 정보 탭 화면 연결
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IjuIcon(
                          _tabs[i].$1,
                          size: 22,
                          color: i == current
                              ? AppColors.primary
                              : AppColors.textSub,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _tabs[i].$2,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: i == current
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: i == current
                                ? AppColors.primary
                                : AppColors.textSub,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
