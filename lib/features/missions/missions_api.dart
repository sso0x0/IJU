import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../api/api_client.dart';
import '../../app/router.dart';
import '../../widgets/iju_icon.dart';
import '../real_order/order_api.dart';

/// GET /missions 한 건 (server/app/schemas.py Mission). 담당: 개발자3
class MissionInfo {
  const MissionInfo({
    required this.id,
    required this.title,
    required this.storeType,
    required this.targetPattern,
    required this.reward,
    required this.level,
    required this.status,
    required this.bestStep,
  });

  factory MissionInfo.fromJson(Map<String, dynamic> json) => MissionInfo(
    id: json['id'] as String,
    title: json['title'] as String,
    storeType: json['store_type'] as String,
    targetPattern: json['target_pattern'] as String? ?? '',
    reward: json['reward'] as int? ?? 0,
    level: json['level'] as int? ?? 1,
    status: json['status'] as String? ?? 'new',
    bestStep: json['best_step'] as int? ?? 0,
  );

  final String id;
  final String title;
  final String storeType;
  final String targetPattern;
  final int reward;
  final int level;

  /// new | in_progress | completed
  final String status;

  /// 실전 주문 4단계 중 도달한 최고 단계 (0이면 시작 전)
  final int bestStep;

  static const _labels = {'restaurant': '식당', 'side_dish': '반찬가게'};

  String get storeLabel => _labels[storeType] ?? '가게';

  String get icon => switch (storeType) {
    'restaurant' => IjuIcons.missionRestaurant,
    'side_dish' => IjuIcons.missionBasket,
    _ => IjuIcons.mic,
  };

  /// 카드 아래 줄: '식당 · 레벨 1 · 실전 2/4단계'
  String get meta {
    final progress = switch (status) {
      'completed' => '쿠폰 받음',
      'in_progress' when bestStep > 0 => '실전 $bestStep/4단계',
      'in_progress' => '연습 중',
      _ => '보상 쿠폰 + ${reward}P',
    };
    return '$storeLabel · 레벨 $level · $progress';
  }
}

/// 지금 하고 있는 미션. 미션 카드를 누르면 채워지고,
/// 음성 연습 → 실전 주문 → 영수증 인증까지 이 id로 기록합니다.
abstract final class CurrentMission {
  static String? id;
}

abstract final class MissionsApi {
  /// 서버가 꺼져 있으면 null. 화면은 시연용 고정 목록을 보여 줍니다.
  static Future<List<MissionInfo>?> list() async {
    try {
      final json = await ApiClient.getJson('/missions', {
        'user_id': currentUserId,
      });
      return [
        for (final m in (json['missions'] as List).cast<Map<String, dynamic>>())
          MissionInfo.fromJson(m),
      ];
    } on ApiException {
      return null;
    }
  }
}

/// 미션 시작: 모든 미션은 메뉴판 찍기부터 합니다.
/// [example]이면 가게에 가기 전 연습용으로 예시 메뉴판 결과를 바로 보여 줍니다.
void startMission(
  BuildContext context,
  MissionInfo mission, {
  bool example = false,
}) {
  CurrentMission.id = mission.id;
  context.push(menuScanPath(mission.storeType, example: example));
}

/// 메뉴판 찍기 화면 주소. 반찬가게 말고는 모두 식당 기준으로 문장을 만듭니다.
String menuScanPath(String storeType, {bool example = false}) {
  final scenario = storeType == 'side_dish' ? storeType : 'restaurant';
  return '${AppRoutes.menuScan}?scenario=$scenario${example ? '&example=1' : ''}';
}
