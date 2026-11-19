import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/colors.dart';
import '../../app/router.dart';
import '../../app/session.dart';
import '../login/auth_api.dart';
import '../../app/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../nearby/nearby_stores.dart';
import '../../widgets/iju_tab_bar.dart';
import '../../widgets/progress.dart';
import '../review/review_store.dart';
import '../missions/missions_api.dart';
import '../scenario/scenarios.dart';

/// B1 홈. 담당: 개발자1 (미션 목록 연결: 개발자3)
/// GET /missions에서 지금 할 미션 1개를 메뉴판 미션 카드로 보여 줍니다.
/// 서버가 꺼져 있으면 시연용 고정 데이터를 보여 줍니다.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<List<MissionInfo>?> _missions = MissionsApi.list();

  /// 로그인했으면 내 포인트(GET /me/stats), 둘러보기면 시연 값 320.
  /// 서버에 못 붙으면 null이라 포인트 배지를 숨깁니다.
  late final Future<int?> _points = _loadPoints();

  static Future<int?> _loadPoints() async {
    if (!AppSession.loggedIn) return 320;
    try {
      return (await AuthApi.stats())['points'] as int?;
    } on AuthException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FutureBuilder<int?>(
              future: _points,
              builder: (context, snap) => _HomeHeader(points: snap.data),
            ),
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
        ? (active.bestStep > 0
              ? '실전 ${active.bestStep.clamp(1, 3)}/3단계 · '
              : '연습 중 · ')
        : '';

    return [
      _MenuMissionCard(
        badge: started ? '진행 중 미션' : '오늘의 미션',
        store: active.storeLabel,
        rewardLabel: '$progress쿠폰 + ${active.reward}P',
        buttonLabel: started ? '메뉴판 찍고 이어서 하기' : '메뉴판 찍고 시작',
        onScan: () => startMission(context, active),
        onExample: () => startMission(context, active, example: true),
      ),
      const _TodayReview(),
      ..._nearby,
    ];
  }

  /// 서버에 연결하지 못했을 때의 시연용 화면 (기존 고정 데이터).
  List<Widget> _demo(BuildContext context) {
    return [
      _MenuMissionCard(
        store: '식당',
        rewardLabel: '쿠폰 + 50P',
        onScan: () => context.push(menuScanPath('restaurant')),
        onExample: () =>
            context.push(menuScanPath('restaurant', example: true)),
      ),
      const _TodayReview(),
      ..._nearby,
    ];
  }

  /// 가까운 가게 (현재 위치 기준).
  static const _nearby = [SizedBox(height: 24), NearbyStores()];
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.points});

  /// null이면 (불러오는 중·서버 오류) 배지를 숨겨요.
  final int? points;

  static const _hello = {
    'vi': 'Xin chào',
    'en': 'Hello',
    'fil': 'Kumusta',
    'km': 'សួស្តី',
    'lo': 'ສະບາຍດີ',
    'th': 'สวัสดี',
    'id': 'Halo',
    'uz': 'Salom',
    'mn': 'Сайн байна уу',
    'ne': 'नमस्ते',
    'zh': '你好',
  };

  @override
  Widget build(BuildContext context) {
    final name = AppSession.nickname;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      child: Row(
        children: [
          Semantics(
            label: AppLocalizations.of(context).appName,
            child: Image.asset('assets/brand/logo.png', width: 36),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name == null ? '안녕하세요' : '$name 님, 안녕하세요',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                Text(
                  name == null ? tr(_hello) : '${tr(_hello)} $name',
                  style: AppText.native.copyWith(
                    fontSize: 13,
                    color: AppColors.textSub,
                  ),
                ),
              ],
            ),
          ),
          if (points != null) PointsBadge(points: points!),
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
    required this.rewardLabel,
    required this.onScan,
    required this.onExample,
    this.badge = '오늘의 미션',
    this.buttonLabel = '메뉴판 찍고 시작',
  });

  final String store;
  final String badge;
  final String rewardLabel;
  final String buttonLabel;
  final VoidCallback onScan;
  final VoidCallback onExample;

  static const _subtitle = {
    'vi': 'Xem thực đơn và gọi món',
    'en': 'Order from the menu board',
    'fil': 'Umorder mula sa menu',
    'km': 'មើលម៉ឺនុយ ហើយកុម្ម៉ង់',
  };

  static const _today = {
    'vi': 'Nhiệm vụ hôm nay',
    'en': 'Mission of the day',
    'fil': 'Misyon ngayon',
    'km': 'បេសកកម្មថ្ងៃនេះ',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.section),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$badge · ${tr(_today)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primarySoft,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '$store 메뉴판 보고\n주문하기',
            style: const TextStyle(
              fontSize: 24,
              height: 1.3,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tr(_subtitle),
            style: AppText.native.copyWith(color: AppColors.primarySoft),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.confirmation_number_outlined,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  rewardLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(4, 14, 4, 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const MissionStepper(current: 0, onPrimary: true),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: AppSpace.buttonHeight,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.button),
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
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: onExample,
            borderRadius: BorderRadius.circular(12),
            child: const SizedBox(
              height: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      '가게 가기 전이에요 · 예시 메뉴판으로 연습',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 20, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 오늘 복습할 문장 (복습 1·2·3단계 점 + 문장).
class _TodayReview extends StatelessWidget {
  const _TodayReview();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<ReviewItem>>(
      valueListenable: ReviewStore.items,
      builder: (context, items, _) {
        final now = DateTime.now();
        final today = [
          for (final i in items)
            if (i.dueLabel(now) == '오늘') i,
        ];
        if (today.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.card),
              side: const BorderSide(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.go(AppRoutes.review),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '오늘 복습할 문장 ${today.length}개',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: AppColors.textSub,
                        ),
                      ],
                    ),
                    for (final i in today.take(3)) ...[
                      const SizedBox(height: 10),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          StageDots(cleared: i.cleared.clamp(0, 3)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              i.sentence,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
