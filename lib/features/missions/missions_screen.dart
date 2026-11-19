import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/colors.dart';
import '../../app/router.dart';
import '../../widgets/iju_icon.dart';
import '../../widgets/iju_tab_bar.dart';
import '../../widgets/mission_card.dart';

/// 미션 탭: 진행 중 · 추천 · 완료 미션 전체 목록.
/// Figma에는 이 화면이 없어 '2 홈 · 미션'의 MissionCard 스타일로 만들었습니다.
/// TODO(개발자1): GET /missions 결과로 교체. 지금은 시연용 고정 데이터입니다.
class MissionsScreen extends StatelessWidget {
  const MissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return IjuTabScaffold(
      tab: IjuTab.missions,
      title: '미션',
      sub: 'Nhiệm vụ',
      trailing: const PointsBadge(points: 320),
      children: [
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
        const SizedBox(height: 16),
        const Text(
          '미션을 끝내면 영수증으로 인증하고 쿠폰과 포인트를 받아요.',
          style: TextStyle(fontSize: 13, color: AppColors.textSub),
        ),
      ],
    );
  }
}
