import 'package:material_ui/material_ui.dart';

import '../../app/colors.dart';
import 'order_place_store.dart';

/// 웹이 아닐 때(테스트·Android·iOS): 지도 자리만 보여 줍니다. 카카오맵은 웹 PWA에서 그립니다.
class KakaoMapView extends StatelessWidget {
  const KakaoMapView({
    super.key,
    required this.places,
    this.focusId,
    this.onSelect,
  });

  final List<OrderPlace> places;
  final String? focusId;
  final void Function(String id)? onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF2EFE9),
      alignment: Alignment.center,
      child: const Text(
        '지도는 웹에서 볼 수 있어요',
        style: TextStyle(fontSize: 14, color: AppColors.textSub),
      ),
    );
  }
}

/// 웹이 아니면 아무것도 하지 않습니다.
void openExternalUrl(String url) {}
