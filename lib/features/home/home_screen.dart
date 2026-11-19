import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/colors.dart';
import '../../app/router.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/iju_icon.dart';
import '../../widgets/iju_tab_bar.dart';
import '../../widgets/mission_card.dart';
import '../missions/missions_api.dart';

/// Figma '2 홈 · 미션'. 담당: 개발자1 (미션 목록 연결: 개발자3)
/// GET /missions에서 진행 중 미션 1개와 추천 미션 2개를 보여 줍니다.
/// 서버가 꺼져 있으면 시연용 고정 데이터를 보여 줍니다.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<List<MissionInfo>?> _missions = MissionsApi.list();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _HomeHeader(points: 320),
            Expanded(
              child: FutureBuilder<List<MissionInfo>?>(
                future: _missions,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final missions = snap.data;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    children: missions == null
                        ? _demo(context)
                        : _fromServer(context, missions),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const IjuTabBar(current: IjuTab.home),
    );
  }

  List<Widget> _fromServer(BuildContext context, List<MissionInfo> missions) {
    final open = [for (final m in missions) if (m.status != 'completed') m];
    if (open.isEmpty) {
      return const [
        SizedBox(height: 40),
        Center(
          child: Text(
            '받은 미션을 모두 끝냈어요!',
            style: TextStyle(fontSize: 16, color: AppColors.textBody),
          ),
        ),
      ];
    }
    // 서버가 진행 중 → 새 미션 순으로 정렬해서 줌
    final active = open.first;
    final next = open.skip(1).take(2).toList();
    final started = active.status == 'in_progress';

    return [
      _ActiveMissionCard(
        badge: started ? '진행 중 미션' : '오늘의 미션',
        title: active.title,
        meta: '${active.storeLabel} · 레벨 ${active.level}',
        progressLabel: started
            ? (active.bestStep > 0 ? '실전 ${active.bestStep}/4단계' : '연습 중')
            : '시작 전',
        rewardLabel: '보상 쿠폰 + ${active.reward}P',
        progress: active.bestStep / 4,
        buttonLabel: started ? '이어서 하기' : '시작하기',
        onContinue: () => startMission(context, active),
      ),
      if (next.isNotEmpty) ...[
        const SizedBox(height: 20),
        const Text(
          '추천 미션',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        for (final m in next) ...[
          const SizedBox(height: 10),
          MissionCard(
            icon: m.icon,
            title: m.title,
            meta: m.meta,
            onTap: () => startMission(context, m),
          ),
        ],
      ],
    ];
  }

  /// 서버에 연결하지 못했을 때의 시연용 화면 (기존 고정 데이터).
  List<Widget> _demo(BuildContext context) {
    void startDemo() => context.push(AppRoutes.menuScan);
    return [
      _ActiveMissionCard(
        title: '삼겹살 600g 구이용으로 주문하기',
        translation: 'Mua 600g thịt ba chỉ để nướng',
        meta: '정육점 · 레벨 2',
        progressLabel: '연습 2/3 완료',
        rewardLabel: '보상 쿠폰 + 50P',
        progress: 2 / 3,
        onContinue: startDemo,
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
        onTap: () => context.push('${AppRoutes.compose}?scenario=restaurant'),
      ),
      const SizedBox(height: 10),
      MissionCard(
        icon: IjuIcons.missionBasket,
        title: '반찬 두 가지 골라 담기',
        meta: '반찬가게 · 레벨 1 · 숙소에서 1.2km',
        onTap: () => context.push('${AppRoutes.compose}?scenario=side_dish'),
      ),
    ];
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
    this.translation,
    required this.meta,
    required this.progressLabel,
    required this.rewardLabel,
    required this.progress,
    required this.onContinue,
    this.badge = '진행 중 미션',
    this.buttonLabel = '이어서 하기',
  });

  final String title;

  /// 학습자 모국어 번역. 없으면 줄을 숨깁니다.
  final String? translation;
  final String badge;
  final String buttonLabel;
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
                child: Text(
                  badge,
                  style: const TextStyle(
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
          if (translation != null) ...[
            const SizedBox(height: 4),
            Text(
              translation!,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.onPrimaryMuted,
              ),
            ),
          ],
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
                child: Center(
                  child: Text(
                    buttonLabel,
                    style: const TextStyle(
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
