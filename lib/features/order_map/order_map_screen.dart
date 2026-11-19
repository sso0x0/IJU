import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/colors.dart';
import '../../app/router.dart';
import '../../widgets/iju_tab_bar.dart';
import '../../widgets/mission_card.dart';
import '../scenario/scenarios.dart';
import 'kakao_map.dart';
import 'order_place_store.dart';

/// 주문 지도: 미션에서 영수증을 인증한 가게를 카카오맵에 모아 보여 줍니다. 담당: 개발자1
/// 복습 탭의 '주문 지도' 버튼으로 들어옵니다. 가게는 [OrderPlaceStore]에서 옵니다.
class OrderMapScreen extends StatelessWidget {
  const OrderMapScreen({super.key});

  static const Tr _sub = {
    'vi': 'Những nơi tôi đã gọi món',
    'en': 'Places I ordered at',
  };

  static void _open(BuildContext context, OrderPlace place) =>
      context.push(AppRoutes.orderPlace, extra: place);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: OrderPlaceStore.items,
      builder: (context, places, _) {
        final now = DateTime.now();
        return IjuTabScaffold(
          tab: IjuTab.review,
          title: '주문 지도',
          sub: tr(_sub),
          trailing: _CountBadge(count: places.length),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: 300,
                child: KakaoMapView(
                  places: places,
                  onSelect: (id) {
                    final place = places.where((p) => p.id == id).firstOrNull;
                    if (place != null) _open(context, place);
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            const _Hint(),
            const IjuListTitle('최근 주문'),
            if (places.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    '아직 저장한 가게가 없어요',
                    style: TextStyle(fontSize: 15, color: AppColors.textSub),
                  ),
                ),
              ),
            for (final place in places) ...[
              _PlaceCard(
                place: place,
                day: place.dayLabel(now),
                onTap: () => _open(context, place),
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.pointBg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        '$count곳',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.pointText,
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 18,
            color: AppColors.textSub,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '미션에서 영수증을 인증하면 여기에 저장돼요',
              style: TextStyle(fontSize: 13, color: AppColors.textBody),
            ),
          ),
        ],
      ),
    );
  }
}

/// Figma 'MissionCard' 모양: 핀 아이콘 + 가게 이름 + 한 문장.
class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.place,
    required this.day,
    required this.onTap,
  });

  final OrderPlace place;
  final String day;
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
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.place_outlined,
                  size: 22,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.storeName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '“${place.sentence}”',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSub,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (day == '오늘')
                const SmallBadge('오늘')
              else
                Text(
                  day,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSub,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
