import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

/// Figma에서 내려받은 아이콘 (assets/icons/*.svg).
/// 원본 크기와 색을 그대로 쓰고, [color]를 주면 그 색으로 칠합니다.
abstract final class IjuIcons {
  static const back = 'back';
  static const bulb = 'bulb';
  static const checkLarge = 'check_large';
  static const checkSmall = 'check_small';
  static const edit = 'edit';
  static const mic = 'mic';
  static const missionBasket = 'mission_basket';
  static const missionRestaurant = 'mission_restaurant';
  static const pinDot = 'pin_dot';
  static const points = 'points';
  static const reviewCard = 'review_card';
  static const speaker = 'speaker';
  static const tabHome = 'tab_home';
  static const tabMission = 'tab_mission';
  static const tabProfile = 'tab_profile';
  static const tabReview = 'tab_review';
}

class IjuIcon extends StatelessWidget {
  const IjuIcon(this.name, {super.key, required this.size, this.color});

  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/$name.svg',
      width: size,
      height: size,
      colorFilter: color == null
          ? null
          : ColorFilter.mode(color!, BlendMode.srcIn),
    );
  }
}
