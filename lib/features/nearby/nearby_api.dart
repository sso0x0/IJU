import 'package:geolocator/geolocator.dart';
import 'package:material_ui/material_ui.dart';

import '../../api/api_client.dart';

/// 현재 위치 근처 가게 하나 (GET /places/nearby). 담당: 개발자1
class NearbyPlace {
  const NearbyPlace({
    required this.id,
    required this.name,
    required this.storeType,
    required this.lat,
    required this.lng,
    required this.distanceM,
    this.category,
    this.address,
    this.partner = false,
  });

  factory NearbyPlace.fromJson(Map<String, dynamic> j) => NearbyPlace(
    id: j['id'] as String,
    name: j['name'] as String,
    storeType: j['store_type'] as String,
    category: j['category'] as String?,
    address: j['address'] as String?,
    lat: (j['lat'] as num).toDouble(),
    lng: (j['lng'] as num).toDouble(),
    distanceM: (j['distance_m'] as num).toInt(),
    partner: j['partner'] as bool? ?? false,
  );

  /// places.id. 메뉴판 인식에 넘기면 업종 힌트가 들어가요.
  final String id;
  final String name;

  /// restaurant · side_dish · butcher · mart · produce · fish · cafe · bakery · pharmacy
  final String storeType;

  /// 상가정보 소분류 (예: 한식 백반, 정육점)
  final String? category;
  final String? address;
  final double lat;
  final double lng;
  final int distanceM;

  /// 이주 참여 가게 (미션·쿠폰)
  final bool partner;

  /// '120m' · '1.2km'
  String get distanceLabel => distanceM < 1000
      ? '${distanceM}m'
      : '${(distanceM / 1000).toStringAsFixed(1)}km';

  String get typeLabel => switch (storeType) {
    'restaurant' => '식당',
    'side_dish' => '반찬가게',
    'butcher' => '정육점',
    'mart' => '마트',
    'produce' => '채소·과일',
    'fish' => '수산물',
    'cafe' => '카페',
    'bakery' => '빵집',
    'pharmacy' => '약국',
    _ => '가게',
  };

  IconData get icon => switch (storeType) {
    'restaurant' => Icons.ramen_dining_outlined,
    'side_dish' => Icons.rice_bowl_outlined,
    'butcher' => Icons.kebab_dining_outlined,
    'mart' => Icons.shopping_basket_outlined,
    'produce' => Icons.eco_outlined,
    'fish' => Icons.set_meal_outlined,
    'cafe' => Icons.local_cafe_outlined,
    'bakery' => Icons.bakery_dining_outlined,
    'pharmacy' => Icons.local_pharmacy_outlined,
    _ => Icons.storefront_outlined,
  };

  /// 메뉴판 찍기로 이어 갈 시나리오 (반찬가게만 따로, 나머지는 식당 문장).
  String get scenarioId =>
      storeType == 'side_dish' ? 'side_dish' : 'restaurant';
}

/// 위치를 못 얻은 이유.
enum LocationProblem {
  /// 기기 위치 서비스(GPS)가 꺼져 있어요
  serviceOff,

  /// 이번에 허용하지 않았어요 (다시 물어볼 수 있음)
  denied,

  /// '다시 묻지 않음' · 설정에서 막혀 있어요
  deniedForever,

  /// 위치를 못 받았어요 (시간 초과·지원 안 함)
  failed,
}

class LocationException implements Exception {
  const LocationException(this.problem);
  final LocationProblem problem;
}

abstract final class NearbyApi {
  /// 현재 위치 (필요하면 권한을 물어봐요). 못 얻으면 [LocationException].
  /// 현재 위치를 얻는 함수. 위젯 테스트에서는 위치 플러그인이 없어서 바꿔 끼워요.
  static Future<(double, double)> Function() locate = _locate;

  static Future<(double, double)> _locate() async {
    final p = await currentPosition();
    return (p.latitude, p.longitude);
  }

  static Future<Position> currentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const LocationException(LocationProblem.serviceOff);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        throw const LocationException(LocationProblem.deniedForever);
      }
      if (permission == LocationPermission.denied) {
        throw const LocationException(LocationProblem.denied);
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
    } on LocationException {
      rethrow;
    } catch (_) {
      // 시간 초과, 플러그인 없음(테스트) 등
      throw const LocationException(LocationProblem.failed);
    }
  }

  /// 설정 화면 열기 ('다시 묻지 않음'을 고른 뒤 · 위치 서비스 꺼짐).
  static Future<void> openSettings(LocationProblem problem) async {
    try {
      if (problem == LocationProblem.serviceOff) {
        await Geolocator.openLocationSettings();
      } else {
        await Geolocator.openAppSettings();
      }
    } catch (_) {}
  }

  /// [lat], [lng]에서 [radius]m 안의 가게 (이주 참여 가게 먼저, 그다음 가까운 순).
  /// 서버에 못 붙으면 [ApiException].
  static Future<List<NearbyPlace>> places(
    double lat,
    double lng, {
    int radius = 1000,
  }) async {
    final json = await ApiClient.getJson('/places/nearby', {
      'lat': '$lat',
      'lng': '$lng',
      'radius': '$radius',
      'limit': '20',
      // 홈에서는 음식점만 보여 줘요 (반찬가게·마트·카페 등은 빼요).
      'type': 'restaurant',
    });
    return [
      for (final p in json['places'] as List)
        NearbyPlace.fromJson(p as Map<String, dynamic>),
    ];
  }
}
