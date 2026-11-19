import 'package:flutter_test/flutter_test.dart';
import 'package:iju/features/nearby/nearby_api.dart';
import 'package:iju/features/nearby/nearby_stores.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('서버 응답을 가게로 읽고 거리를 보기 좋게 써요', () {
    final p = NearbyPlace.fromJson({
      'id': 'p1',
      'name': '새벽반찬',
      'store_type': 'side_dish',
      'lat': 37.69,
      'lng': 127.88,
      'distance_m': 1240,
      'partner': true,
    });
    expect(p.distanceLabel, '1.2km');
    expect(p.typeLabel, '반찬가게');
    expect(p.scenarioId, 'side_dish');
    expect(p.partner, isTrue);
  });

  testWidgets('위치를 허용하지 않으면 허용 안내를 보여 줘요', (tester) async {
    NearbyApi.locate = () async =>
        throw const LocationException(LocationProblem.denied);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: NearbyStores())),
    );
    await tester.pumpAndSettle();
    expect(find.text('위치를 허용하면 가까운 음식점을 보여 줘요'), findsOneWidget);
    expect(find.text('위치 허용하기'), findsOneWidget);
  });
}
