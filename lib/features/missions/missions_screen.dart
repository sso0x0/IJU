import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/colors.dart';
import '../../app/router.dart';
import '../../widgets/iju_icon.dart';
import '../../widgets/iju_tab_bar.dart';
import '../../widgets/mission_card.dart';
import 'missions_api.dart';

/// 미션 탭: 진행 중 · 추천 · 완료 미션 전체 목록. 담당: 개발자3
/// Figma에는 이 화면이 없어 '2 홈 · 미션'의 MissionCard 스타일로 만들었습니다.
/// GET /missions 결과를 보여 주고, 서버가 꺼져 있으면 시연용 고정 목록을 보여 줍니다.
class MissionsScreen extends StatefulWidget {
  const MissionsScreen({super.key});

  @override
  State<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends State<MissionsScreen> {
  late final Future<List<MissionInfo>?> _missions = MissionsApi.list();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MissionInfo>?>(
      future: _missions,
      builder: (context, snap) {
        final missions = snap.data;
        return IjuTabScaffold(
          tab: IjuTab.missions,
          title: '미션',
          sub: 'Nhiệm vụ',
          trailing: const PointsBadge(points: 320),
          children: [
            if (snap.connectionState != ConnectionState.done)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (missions == null)
              ..._demo(context)
            else
              ..._fromServer(context, missions),
            const SizedBox(height: 16),
            const Text(
              '미션을 끝내면 영수증으로 인증하고 쿠폰과 포인트를 받아요.',
              style: TextStyle(fontSize: 13, color: AppColors.textSub),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _fromServer(BuildContext context, List<MissionInfo> missions) {
    List<MissionInfo> by(String status) => [
      for (final m in missions)
        if (m.status == status) m,
    ];
    final sections = [
      ('진행 중', by('in_progress')),
      ('추천 미션', by('new')),
      ('완료한 미션', by('completed')),
    ];

    return [
      for (final (title, list) in sections)
        if (list.isNotEmpty) ...[
          IjuListTitle(title, count: list.length),
          for (var i = 0; i < list.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _card(context, list[i]),
          ],
        ],
      if (missions.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 20),
          child: Text(
            '아직 받을 수 있는 미션이 없어요.',
            style: TextStyle(fontSize: 15, color: AppColors.textBody),
          ),
        ),
    ];
  }

  Widget _card(BuildContext context, MissionInfo m) {
    final done = m.status == 'completed';
    return MissionCard(
      icon: done ? IjuIcons.checkSmall : m.icon,
      title: m.title,
      meta: m.meta,
      trailing: switch (m.status) {
        'in_progress' => const SmallBadge('이어서', strong: true),
        'completed' => const SmallBadge('완료'),
        _ => null,
      },
      muted: done,
      onTap: done ? null : () => startMission(context, m),
    );
  }

  /// 서버에 연결하지 못했을 때의 시연용 목록 (기존 고정 데이터).
  List<Widget> _demo(BuildContext context) => [
    const IjuListTitle('진행 중', count: 1),
    MissionCard(
      icon: IjuIcons.mic,
      title: '삼겹살 600g 구이용으로 주문하기',
      meta: '정육점 · 레벨 2 · 연습 2/3 완료',
      trailing: const SmallBadge('이어서', strong: true),
      onTap: () => context.push(AppRoutes.menuScan),
    ),
    const IjuListTitle('추천 미션', count: 2),
    MissionCard(
      icon: IjuIcons.missionRestaurant,
      title: '김치찌개 돼지고기 빼고 주문하기',
      meta: '식당 · 레벨 2 · 숙소에서 400m',
      onTap: () => context.push('${AppRoutes.compose}?scenario=restaurant'),
    ),
    const SizedBox(height: 10),
    MissionCard(
      icon: IjuIcons.missionBasket,
      title: '반찬 두 가지 골라 담기',
      meta: '반찬가게 · 레벨 1 · 숙소에서 1.2km',
      onTap: () => context.push('${AppRoutes.compose}?scenario=side_dish'),
    ),
    const IjuListTitle('완료한 미션', count: 1),
    const MissionCard(
      icon: IjuIcons.checkSmall,
      title: '목살 300g 찌개용으로 주문하기',
      meta: '정육점 · 레벨 1 · 쿠폰 받음',
      trailing: SmallBadge('완료'),
      muted: true,
      onTap: null,
    ),
  ];
}
