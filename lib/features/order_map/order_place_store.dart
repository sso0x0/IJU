import 'package:flutter/foundation.dart' show ValueNotifier;

import '../../app/session.dart';
import '../login/auth_api.dart';
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

  /// '11월 19일 주문'
  String get orderedLabel => '${orderedAt.month}월 ${orderedAt.day}일 주문';

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
///
/// 로그인하면 서버(order_places, GET·POST /me/order-places)에 저장하고 [load]로 불러옵니다.
/// 로그인 없이 둘러볼 때는 시연 가게를 보여 주고 저장하지 않습니다.
abstract final class OrderPlaceStore {
  static final items = ValueNotifier<List<OrderPlace>>([OrderPlace.demo]);

  static int _seq = 0;

  /// 로그인했을 때: 서버에 저장된 내 가게 목록으로 바꿉니다.
  /// 불러오는 동안 새로 넣은 가게는 남기고 서버에도 올립니다.
  static Future<void> load() async {
    if (!AppSession.loggedIn) return;
    items.value = [];
    try {
      final json = await AuthApi.orderPlaces();
      final saved = [
        for (final p in json['places'] as List)
          _fromJson(p as Map<String, dynamic>),
      ];
      final added = [
        for (final p in items.value)
          if (!saved.any((s) => _same(s, p))) p,
      ];
      items.value = [...added, ...saved];
      added.forEach(_push);
    } on AuthException {
      // 서버에 못 붙으면 빈 목록. 새로 인증한 가게는 그대로 쌓이고 올리기를 시도합니다.
    }
  }

  static bool _same(OrderPlace a, OrderPlace b) =>
      a.storeName == b.storeName && a.sentence == b.sentence;

  static OrderPlace _fromJson(Map<String, dynamic> p) => OrderPlace(
    id: p['id'] as String,
    storeName: p['store_name'] as String,
    sentence: p['sentence'] as String,
    meaning: p['meaning'] as String?,
    address: p['address'] as String?,
    lat: (p['lat'] as num?)?.toDouble(),
    lng: (p['lng'] as num?)?.toDouble(),
    orderedAt:
        DateTime.tryParse(p['ordered_at'] as String)?.toLocal() ??
        DateTime.now(),
  );

  /// 서버에 저장합니다 (같은 가게·같은 문장이면 날짜만 바뀜). 실패해도 화면은 그대로.
  static Future<void> _push(OrderPlace p) async {
    if (!AppSession.loggedIn) return;
    try {
      await AuthApi.saveOrderPlace({
        'store_name': p.storeName,
        'sentence': p.sentence,
        'meaning': p.meaning,
        'address': p.address,
        'lat': p.lat,
        'lng': p.lng,
      });
    } on AuthException {
      // 다음 로그인 때 다시 불러오면 서버 값으로 맞춰집니다.
    }
  }

  /// 맨 위에 넣습니다. 같은 가게·같은 문장이면 날짜만 새로 바꿔 맨 위로 올립니다.
  static void add(OrderPlace place) {
    items.value = [
      place,
      for (final p in items.value)
        if (!_same(p, place)) p,
    ];
    _push(place);
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
