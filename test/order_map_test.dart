import 'package:flutter_test/flutter_test.dart';

import 'package:iju/features/order_map/order_place_store.dart';
import 'package:iju/features/real_order/order_api.dart';

void main() {
  setUp(OrderPlaceStore.reset);

  test('영수증 인증에 성공하면 가게와 문장이 주문 지도 맨 위에 들어간다', () {
    const result = ReceiptResult(
      verified: true,
      reason: 'ok',
      storeName: '춘천원조닭갈비',
      storeAddress: '강원 춘천시 명동길 12',
      lat: 37.88,
      lng: 127.73,
    );
    OrderPlaceStore.addFromReceipt(result, sentence: '닭갈비 2인분 주세요.');

    final first = OrderPlaceStore.items.value.first;
    expect(first.storeName, '춘천원조닭갈비');
    expect(first.sentence, '닭갈비 2인분 주세요.');
    expect(first.address, '강원 춘천시 명동길 12');
    expect(first.hasPosition, isTrue);
    expect(first.dayLabel(DateTime.now()), '오늘');
    expect(
      first.directionsUrl,
      'https://map.kakao.com/link/to/'
      '${Uri.encodeComponent('춘천원조닭갈비')},37.88,127.73',
    );
  });

  test('같은 가게·같은 문장은 한 번만 남는다', () {
    const result = ReceiptResult(
      verified: true,
      reason: 'ok',
      storeName: '홍천 한우정육점',
    );
    final before = OrderPlaceStore.items.value.length;
    OrderPlaceStore.addFromReceipt(result, sentence: '삼겹살 600그램 구이용으로 주세요.');
    expect(OrderPlaceStore.items.value.length, before);
  });

  test('인증 실패나 가게 이름이 없으면 넣지 않는다', () {
    const failed = ReceiptResult(verified: false, reason: 'unknown_store');
    final before = OrderPlaceStore.items.value.length;
    OrderPlaceStore.addFromReceipt(failed, sentence: '아무 문장');
    expect(OrderPlaceStore.items.value.length, before);
  });
}
