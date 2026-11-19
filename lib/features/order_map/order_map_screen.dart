import 'package:go_router/go_router.dart';

import '../../app/languages.dart';

import 'package:material_ui/material_ui.dart';

import '../../app/colors.dart';
import '../../app/router.dart';
import '../../app/session.dart';
import '../login/auth_api.dart';
import '../login/auth_session.dart';
import '../../app/theme.dart';
import '../../widgets/iju_header.dart';
import '../../widgets/place_map.dart';
import '../review/practice_link.dart';
import '../review/review_store.dart';
import 'order_place_store.dart';

/// G8 내 지도: 내가 가 본 가게와 그 가게에서 말한 문장. 담당: 개발자1
///
/// 가게마다 번호 핀을 찍고 최근 순서대로 점선으로 잇습니다. 아래 목록에서
/// '복습하기'를 누르면 그 문장을 다시 말해 볼 수 있어요.
/// 마이페이지의 '내 지도'와 복습 탭의 지도 버튼으로 들어옵니다.
class OrderMapScreen extends StatelessWidget {
  const OrderMapScreen({super.key});

  static void _open(BuildContext context, OrderPlace place) =>
      context.push(AppRoutes.orderPlace, extra: place);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IjuHeader(title: '내 지도', subtitle: nt('Bản đồ của tôi')),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: OrderPlaceStore.items,
                builder: (context, places, _) => ValueListenableBuilder(
                  // 복습 단계가 바뀌면 목록의 단계 표시도 바뀌어요.
                  valueListenable: ReviewStore.items,
                  builder: (context, _, _) =>
                      _Body(places: places, onOpen: (p) => _open(context, p)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.places, required this.onOpen});

  final List<OrderPlace> places;
  final ValueChanged<OrderPlace> onOpen;

  @override
  Widget build(BuildContext context) {
    final stores = places.map((p) => p.storeName).toSet().length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        Text(
          '가 본 가게 $stores곳 · 말한 문장 ${places.length}개',
          style: AppText.subtitle,
        ),
        Text(
          nt('Đã đến {a} quán · đã nói {b} câu', {
            'a': stores,
            'b': places.length,
          }),
          style: AppText.native.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.textSub,
          ),
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: SizedBox(height: 300, child: MyPlacesMap(places: places)),
        ),
        const SizedBox(height: 12),
        const _ShareToggle(),
        const SizedBox(height: 8),
        if (places.isEmpty)
          const _Empty()
        else
          for (var i = 0; i < places.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.divider),
            _PlaceRow(
              number: i + 1,
              place: places[i],
              onTap: () => onOpen(places[i]),
            ),
          ],
      ],
    );
  }
}

/// '커뮤니티 지도에 공유' 체크 (users.share_map).
/// 켜면 내 지도의 가게와 문장이 커뮤니티 탭 지도에 내 닉네임으로 보여요.
class _ShareToggle extends StatelessWidget {
  const _ShareToggle();

  Future<void> _set(BuildContext context, bool on) async {
    final messenger = ScaffoldMessenger.of(context);
    void toast(String text) => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
    if (!AppSession.loggedIn) {
      toast('로그인하면 커뮤니티 지도에 공유할 수 있어요');
      return;
    }
    try {
      await AuthSession.saveShareMap(on);
      toast(on ? '커뮤니티 지도에 내 지도를 공유해요' : '공유를 껐어요');
    } on AuthException catch (e) {
      toast(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: AppSession.shareMap,
      builder: (context, on, _) => Material(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _set(context, !on),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '커뮤니티 지도에 공유',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                      Text(
                        nt('Chia sẻ lên bản đồ cộng đồng'),
                        style: AppText.native.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSub,
                        ),
                      ),
                    ],
                  ),
                ),
                Checkbox(
                  value: on,
                  onChanged: (v) => _set(context, v ?? false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 내 가게들을 번호 핀으로 보여 주는 지도 (내 지도 · 마이페이지 미리보기).
class MyPlacesMap extends StatelessWidget {
  const MyPlacesMap({
    super.key,
    required this.places,
    this.interactive = true,
    this.onSelect,
  });

  final List<OrderPlace> places;
  final bool interactive;
  final ValueChanged<OrderPlace>? onSelect;

  @override
  Widget build(BuildContext context) {
    return PlaceMap(
      route: true,
      interactive: interactive,
      pins: [
        for (var i = 0; i < places.length; i++)
          if (places[i].hasPosition)
            MapPin(
              lat: places[i].lat!,
              lng: places[i].lng!,
              width: 36,
              height: 36,
              onTap: onSelect == null ? null : () => onSelect!(places[i]),
              child: NumberPin(i + 1),
            ),
      ],
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({
    required this.number,
    required this.place,
    required this.onTap,
  });

  final int number;
  final OrderPlace place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final review = reviewFor(place.sentence);
    final d = place.orderedAt;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NumberPin(number, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${d.month}월 ${d.day}일 · ${d.day}/${d.month} · '
                    '${place.storeName}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSub,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '“${place.sentence}”',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                      color: AppColors.text,
                    ),
                  ),
                  if (place.meaning != null)
                    Text(
                      place.meaning!,
                      style: AppText.native.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSub,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (review != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            review.done
                                ? '3단계 끝 · ${nt('Xong')}'
                                : '${review.cleared}단계까지 · '
                                      '${nt('Bước {n}', {'n': review.cleared})}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                      const Spacer(),
                      _ReviewButton(
                        onTap: () => practiceSentence(
                          context,
                          sentence: place.sentence,
                          meaning: place.meaning,
                        ),
                      ),
                    ],
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

/// '복습하기 · ${nt('Ôn tập')}' 작은 버튼.
class _ReviewButton extends StatelessWidget {
  const _ReviewButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary50,
      shape: const StadiumBorder(
        side: BorderSide(color: AppColors.primarySoft, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: const SizedBox(
          height: 40,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mic_none, size: 18, color: AppColors.primaryDark),
                SizedBox(width: 4),
                Text(
                  '복습하기',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.receipt_long_outlined, size: 18, color: AppColors.textSub),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '가게에서 주문하고 영수증을 인증하면 여기에 쌓여요',
              style: TextStyle(fontSize: 14, color: AppColors.textBody),
            ),
          ),
        ],
      ),
    );
  }
}
