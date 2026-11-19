import 'package:flutter_test/flutter_test.dart';

import 'package:iju/features/review/review_store.dart';
import 'package:iju/features/scenario/scenarios.dart';

void main() {
  setUp(ReviewStore.reset);

  test('식당: 1단계 그대로, 2단계 카드 하나, 3단계 더 길게', () {
    final order = ScenarioOrder.fromLabels(restaurant, ['1인분']);
    expect(order.sentence, '김치찌개 1인분 주세요.');
    expect(order.slightlyChanged().sentence, '김치찌개 2인분 주세요.');
    expect(order.harder().sentence, '김치찌개 3인분 보통으로 해 주세요.');
  });

  test('식당: 3단계는 ‘빼 주세요’ 문장이 더 붙는다', () {
    final order = ScenarioOrder.fromLabels(restaurant, ['1인분', '덜 맵게']);
    expect(order.slightlyChanged().sentence, '김치찌개 1인분 보통으로 해 주세요.');
    expect(order.harder().sentence, '김치찌개 2인분 아주 맵게 해 주세요. 두부는 빼 주세요.');
  });

  test('미션 문장을 넣고 단계를 끝내면 다음 단계로 넘어간다', () {
    final order = ScenarioOrder.fromLabels(restaurant, ['3인분', '아주 맵게']);
    ReviewStore.add(sentence: order.sentence, meaning: '뜻', order: order);
    final item = ReviewStore.items.value.first;
    expect(item.sentence, '김치찌개 3인분 아주 맵게 해 주세요.');
    expect(item.stage, ReviewStage.same);
    expect(item.dueLabel(DateTime.now()), '오늘');

    ReviewStore.complete(item.id, ReviewStage.same, score: 85);
    expect(item.stage, ReviewStage.changed);
    expect(item.score, 85);
    expect(item.dueLabel(DateTime.now()), '내일');

    // 같은 문장을 또 하면 새로 넣지 않습니다.
    final count = ReviewStore.items.value.length;
    ReviewStore.add(sentence: order.sentence, meaning: '뜻', order: order);
    expect(ReviewStore.items.value.length, count);
  });
}
