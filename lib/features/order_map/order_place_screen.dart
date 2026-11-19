import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/colors.dart';
import '../../app/router.dart';
import '../../widgets/iju_button.dart';
import '../../widgets/iju_icon.dart';
import '../../widgets/small_badge.dart';
import '../../widgets/section_label.dart';
import '../practice/practice_screen.dart';
import '../practice/speech.dart';
import '../scenario/scenarios.dart';
import '../../widgets/place_map.dart';
import 'external_link.dart';
import 'order_place_store.dart';

/// 주문 지도의 가게 하나: 위치, 그 가게에서 한 문장, 다시 듣기·말하기 연습·길찾기. 담당: 개발자1
class OrderPlaceScreen extends StatefulWidget {
  const OrderPlaceScreen({super.key, required this.place});

  final OrderPlace place;

  @override
  State<OrderPlaceScreen> createState() => _OrderPlaceScreenState();
}

class _OrderPlaceScreenState extends State<OrderPlaceScreen> {
  final _speech = Speech();

  static const Tr _said = {'vi': 'Câu tôi đã nói', 'en': 'What I said'};

  @override
  void dispose() {
    _speech.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final place = widget.place;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 300,
            child: Stack(
              children: [
                Positioned.fill(
                  child: PlaceMap(
                    zoom: 17,
                    pins: [
                      if (place.hasPosition)
                        MapPin(
                          lat: place.lat!,
                          lng: place.lng!,
                          width: 44,
                          height: 52,
                          alignment: Alignment.topCenter,
                          child: const StorePin(),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  left: 16,
                  top: 16,
                  child: SafeArea(
                    child: _BackButton(onTap: () => _back(context)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            place.storeName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                          if (place.address != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              place.address!,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textBody,
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            place.orderedLabel,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSub,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const SmallBadge('미션 완료', strong: true),
                  ],
                ),
                const SizedBox(height: 20),
                SectionLabel('이 가게에서 한 말', sub: tr(_said)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.sentence,
                        style: const TextStyle(
                          fontSize: 20,
                          height: 1.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      if (place.meaning != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          place.meaning!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSub,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _ListenButton(onTap: () => _speech.speak(place.sentence)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              child: Row(
                children: [
                  Expanded(
                    child: IjuButton(
                      label: '말하기 연습',
                      type: IjuButtonType.secondary,
                      onPressed: () => context.push(
                        AppRoutes.practice,
                        extra: PracticeArgs(
                          sentence: place.sentence,
                          meaning: place.meaning ?? '',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: IjuButton(
                      label: '길찾기',
                      onPressed: () => openExternalUrl(place.directionsUrl),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _back(BuildContext context) =>
      context.canPop() ? context.pop() : context.go(AppRoutes.orderMap);
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: const SizedBox.square(
          dimension: 44,
          child: Center(child: IjuIcon(IjuIcons.back, size: 22)),
        ),
      ),
    );
  }
}

class _ListenButton extends StatelessWidget {
  const _ListenButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: const SizedBox(
          height: 44,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IjuIcon(
                  IjuIcons.speaker,
                  size: 18,
                  color: AppColors.primaryDark,
                ),
                SizedBox(width: 6),
                Text(
                  '다시 듣기',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
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
