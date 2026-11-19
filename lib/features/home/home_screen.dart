import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/colors.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/iju_tab_bar.dart';
import '../missions/missions_api.dart';
import '../scenario/scenarios.dart';

/// Figma '2 홈 · 미션'. 담당: 개발자1 (미션 목록 연결: 개발자3)
/// GET /missions에서 지금 할 미션 1개를 메뉴판 미션 카드로 보여 줍니다.
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
    final open = [
      for (final m in missions)
        if (m.status != 'completed') m,
    ];
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
    // 서버가 진행 중 → 새 미션 순으로 정렬해서 줌. 홈에는 지금 할 미션 하나만 보여 줍니다.
    final active = open.first;
    final started = active.status == 'in_progress';
    final progress = started
        ? (active.bestStep > 0 ? '실전 ${active.bestStep}/4단계 · ' : '연습 중 · ')
        : '';

    return [
      _MenuMissionCard(
        badge: started ? '진행 중 미션' : '오늘의 미션',
        store: active.storeLabel,
        level: active.level,
        rewardLabel: '$progress보상 쿠폰 + ${active.reward}P',
        buttonLabel: started ? '메뉴판 찍고 이어서 하기' : '메뉴판 찍고 시작',
        onScan: () => startMission(context, active),
        onExample: () => startMission(context, active, example: true),
      ),
    ];
  }

  /// 서버에 연결하지 못했을 때의 시연용 화면 (기존 고정 데이터).
  List<Widget> _demo(BuildContext context) {
    return [
      _MenuMissionCard(
        store: '정육점',
        level: 2,
        rewardLabel: '보상 쿠폰 + 50P',
        onScan: () => context.push(menuScanPath('butcher')),
        onExample: () => context.push(menuScanPath('butcher', example: true)),
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

/// 오늘의 미션 카드: 가게 메뉴판을 찍어 고른 메뉴를 주문하는 미션.
/// 4단계(메뉴판 찍기 → 메뉴 고르기 → 말하기 연습 → 주문·영수증)를 미리 보여 주고,
/// 가게에 가기 전이면 예시 메뉴판으로 연습할 수 있게 합니다.
class _MenuMissionCard extends StatelessWidget {
  const _MenuMissionCard({
    required this.store,
    required this.level,
    required this.rewardLabel,
    required this.onScan,
    required this.onExample,
    this.badge = '오늘의 미션',
    this.buttonLabel = '메뉴판 찍고 시작',
  });

  final String store;
  final int level;
  final String badge;
  final String rewardLabel;
  final String buttonLabel;
  final VoidCallback onScan;
  final VoidCallback onExample;

  static const _subtitle = {
    'vi': 'Xem thực đơn và gọi món',
    'en': 'Order from the menu board',
  };

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
              Text('$store · 레벨 $level', style: small),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '$store 메뉴판 보고 주문하기',
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tr(_subtitle),
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.onPrimaryMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(rewardLabel, style: small),
          const SizedBox(height: 18),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Step(Icons.photo_camera_outlined, '메뉴판\n찍기', current: true),
              _Step(Icons.touch_app_outlined, '메뉴\n고르기'),
              _Step(Icons.mic_none, '말하기\n연습'),
              _Step(Icons.receipt_long_outlined, '주문·\n영수증'),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onScan,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.photo_camera_outlined,
                      color: AppColors.primaryDark,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      buttonLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: onExample,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text(
              '아직 가게 전이에요 · 예시 메뉴판으로 연습',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.onPrimaryMuted,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.onPrimaryMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 미션 단계 하나: 동그란 아이콘 + 두 줄 이름. 지금 할 단계는 흰 바탕입니다.
class _Step extends StatelessWidget {
  const _Step(this.icon, this.label, {this.current = false});

  final IconData icon;
  final String label;
  final bool current;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: current ? Colors.white : AppColors.primaryDark,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 22,
              color: current ? AppColors.primaryDark : Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.3,
              fontWeight: current ? FontWeight.w700 : FontWeight.w400,
              color: current ? Colors.white : AppColors.onPrimaryMuted,
            ),
          ),
        ],
      ),
    );
  }
}
