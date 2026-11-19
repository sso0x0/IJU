import 'package:flutter/foundation.dart' show ValueNotifier;

import '../real_order/order_api.dart';

/// 영수증을 인증한 가게 하나: 가게 이름·주소·좌표와 그 가게에서 한 문장. 담당: 개발자1
class OrderPlace {
  const OrderPlace({
    required this.id,
    required this.storeName,
    required this.sentence,
    required this.orderedAt,
    this.address,
    this.lat,
    this.lng,
    this.meaning,
  });

  final String id;
  final String storeName;

  /// 실전 주문에서 말한 문장
  final String sentence;
  final DateTime orderedAt;

  /// 서버(카카오 로컬 API)가 못 찾으면 null. 지도에서는 이름으로 다시 찾아 봅니다.
  final String? address;
  final double? lat;
  final double? lng;

  /// 모국어 뜻 (없으면 숨김)
  final String? meaning;

  bool get hasPosition => lat != null && lng != null;

  /// 카카오맵 길찾기 (좌표가 없으면 주소·이름 검색).
  String get directionsUrl {
    final name = Uri.encodeComponent(storeName);
    if (hasPosition) return 'https://map.kakao.com/link/to/$name,$lat,$lng';
    return 'https://map.kakao.com/link/search/'
        '${Uri.encodeComponent(address ?? storeName)}';
  }

  /// '오늘' 또는 '11.18'
  String dayLabel(DateTime now) {
    final sameDay =
        orderedAt.year == now.year &&
        orderedAt.month == now.month &&
        orderedAt.day == now.day;
    return sameDay ? '오늘' : '${orderedAt.month}.${orderedAt.day}';
  }

  /// '11월 19일 주문'
  String get orderedLabel => '${orderedAt.month}월 ${orderedAt.day}일 주문';

  Map<String, Object?> toMapJson() => {
    'id': id,
    'name': storeName,
    'address': address,
    'lat': lat,
    'lng': lng,
  };

  /// 주소로 바로 들어왔을 때 쓰는 시연 가게 (server/app/seed_data.py의 가게).
  static final demo = OrderPlace(
    id: 'demo-1',
    storeName: '홍천 한우정육점',
    sentence: '삼겹살 600그램 구이용으로 주세요.',
    meaning: 'Cho tôi 600g thịt ba chỉ để nướng.',
    orderedAt: DateTime.now().subtract(const Duration(days: 1)),
    lat: 37.6970,
    lng: 127.8888,
  );
}

/// 주문 지도에 쌓이는 가게 목록. 미션에서 영수증 인증에 성공하면 [addFromReceipt]로 들어옵니다.
/// TODO: 서버 저장으로 바꾸기. 지금은 복습 목록처럼 앱을 다시 켜면 시연 데이터로 돌아갑니다.
abstract final class OrderPlaceStore {
  static final items = ValueNotifier<List<OrderPlace>>([OrderPlace.demo]);

  static int _seq = 0;

  /// 맨 위에 넣습니다. 같은 가게·같은 문장이면 날짜만 새로 바꿔 맨 위로 올립니다.
  static void add(OrderPlace place) {
    items.value = [
      place,
      for (final p in items.value)
        if (!(p.storeName == place.storeName && p.sentence == place.sentence))
          p,
    ];
  }

  /// 영수증 인증 결과로 가게를 남깁니다. 가게 이름이 없으면 넣지 않습니다.
  static void addFromReceipt(
    ReceiptResult result, {
    required String sentence,
    String? meaning,
  }) {
    final name = result.storeName;
    if (!result.verified || name == null || name.isEmpty) return;
    add(
      OrderPlace(
        id: 'mine-${_seq++}',
        storeName: name,
        sentence: sentence,
        meaning: meaning,
        orderedAt: DateTime.now(),
        address: result.storeAddress,
        lat: result.lat,
        lng: result.lng,
      ),
    );
  }

  /// 테스트용: 시연 데이터로 되돌립니다.
  static void reset() => items.value = [OrderPlace.demo];
}
