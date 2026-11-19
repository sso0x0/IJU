import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:iju/app/diet.dart';
import 'package:iju/app/session.dart';
import 'package:iju/features/compose/compose_screen.dart';
import 'package:iju/features/menu_scan/menu_scan_api.dart';
import 'package:iju/features/practice/practice_screen.dart';
import 'package:iju/features/scenario/menu_ingredients.dart' show pieceGroup;
import 'package:iju/features/scenario/scenarios.dart';

void main() {
  tearDown(() {
    AppSession.language = 'vi';
    AppSession.diets.value = const {};
  });

  testWidgets('식당 시나리오: 맵기 카드가 ‘-게 해’ 모양으로 들어간다', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      const MaterialApp(home: ComposeScreen(scenario: restaurant)),
    );
    await tester.pumpAndSettle();

    expect(find.text('김치찌개'), findsOneWidget);
    // 맵기는 처음에 고르지 않음
    expect(find.text('덜 맵게 해'), findsNothing);
    expect(find.text('김치찌개 1인분 주세요.'), findsNothing); // 카드로 나뉘어 보임

    await tester.tap(find.text('덜 맵게'));
    await tester.pumpAndSettle();
    expect(find.text('덜 맵게 해'), findsOneWidget);

    await tester.tap(find.text('아주 맵게'));
    await tester.pumpAndSettle();
    expect(find.text('아주 맵게 해'), findsOneWidget);
  });

  testWidgets('식단을 안 고르면 빼기·질문은 비어 있고 첫 문장만 있다', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      const MaterialApp(home: ComposeScreen(scenario: restaurant)),
    );
    await tester.pumpAndSettle();

    expect(find.text('주세요.'), findsOneWidget);
    expect(find.text('고기 육수랑'), findsNothing);
    expect(find.text('돼지고기는 빼'), findsNothing);
    expect(find.textContaining('기준으로'), findsNothing);
  });

  testWidgets('이슬람: 빼기·질문 칩은 미리 고르지 않고, 눌러야 문장이 붙는다', (tester) async {
    AppSession.diets.value = {Diet.islam};
    tester.view.physicalSize = const Size(1200, 6000);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      const MaterialApp(home: ComposeScreen(scenario: restaurant)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('이슬람 (할랄)'), findsOneWidget);
    // 처음에는 첫 문장만
    expect(find.text('주세요.'), findsOneWidget);
    expect(find.text('돼지고기는 빼'), findsNothing);
    expect(find.text('고기 육수'), findsOneWidget); // 칩만

    // 돼지고기·고기 육수를 누르면 빼기·질문 문장이 붙는다
    await tester.tap(find.text('덜 맵게'));
    await tester.tap(find.text('돼지고기'));
    await tester.tap(find.text('고기 육수'));
    await tester.pumpAndSettle();
    expect(find.text('돼지고기는 빼'), findsOneWidget);
    expect(find.text('주세요.'), findsNWidgets(2));
    expect(
      find.text(
        'Cho tôi 1 phần canh kim chi ít cay. Đừng cho thịt heo nhé. '
        'Có nước hầm thịt không?',
      ),
      findsOneWidget,
    );

    // 두부를 더 빼면 돼지고기랑 / 두부는 빼
    await tester.tap(find.text('두부'));
    await tester.pumpAndSettle();
    expect(find.text('돼지고기랑'), findsOneWidget);
    expect(find.text('두부는 빼'), findsOneWidget);

    // 빼기를 모두 풀면 빼 주세요 문장이 사라진다
    await tester.tap(find.text('돼지고기'));
    await tester.tap(find.text('두부'));
    await tester.pumpAndSettle();
    expect(find.text('돼지고기는 빼'), findsNothing);
  });

  test('식단에 맞지 않는 재료는 표시만 하고 고르지 않는다', () {
    final groups = restaurant.groupsFor({Diet.vegan, Diet.islam});
    final without = groups.firstWhere((g) => g.title == '빼 주세요');
    final ask = groups.firstWhere((g) => g.title == '들어가요?');
    expect(without.initialAll, isEmpty);
    expect(ask.initialAll, isEmpty);
    Set<String> marked(ScenarioGroup g) => {
      for (final o in g.options)
        if (o.caution != null) o.label,
    };
    expect(marked(without), contains('돼지고기'));
    expect(marked(ask), containsAll(['고기 육수', '멸치 육수', '젓갈']));
  });

  testWidgets('재료 칩(빼 주세요·들어가요?)에는 ⓘ가 없다', (tester) async {
    AppSession.diets.value = {Diet.hindu};
    tester.view.physicalSize = const Size(1200, 6000);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      const MaterialApp(home: ComposeScreen(scenario: restaurant)),
    );
    await tester.pumpAndSettle();
    expect(find.text('고기 육수'), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsNothing);
  });

  test('식단·종교마다 피하는 재료', () {
    List<Diet> c(Set<FoodTag> tags) => Diet.conflicts(tags, Diet.values);
    expect(c({FoodTag.pork}), isNot(contains(Diet.hindu)));
    expect(
      c({FoodTag.pork}),
      containsAll([Diet.islam, Diet.judaism, Diet.pollo]),
    );
    expect(c({FoodTag.beef}), contains(Diet.hindu));
    expect(c({FoodTag.poultry}), isNot(contains(Diet.pollo)));
    expect(c({FoodTag.fish}), isNot(contains(Diet.pesco)));
    expect(c({FoodTag.dairy}), containsAll([Diet.vegan, Diet.ovo]));
    expect(c({FoodTag.dairy}), isNot(contains(Diet.lacto)));
    expect(c({FoodTag.shellfish}), contains(Diet.judaism));
    expect(c({FoodTag.alcohol}), [Diet.islam]);
    expect(c({FoodTag.plant}), [Diet.fruitarian]);
    expect(Diet.vegetarian, hasLength(7));
    expect(Diet.religions, hasLength(3));
  });

  test('‘-랑/이랑’, ‘-는/은’은 받침에 따라 바뀐다', () {
    expect(withAnd('돼지고기'), '돼지고기랑');
    expect(withAnd('버섯'), '버섯이랑');
    expect(withTopic('두부'), '두부는');
    expect(withTopic('버섯'), '버섯은');
  });

  testWidgets('반찬가게 시나리오: 하나 더 고른 반찬에 ‘-도’가 붙고, 다시 누르면 빠진다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ComposeScreen(scenario: sideDish)),
    );
    await tester.pumpAndSettle();
    expect(find.text('콩자반도'), findsOneWidget);

    await tester.tap(find.text('콩자반'));
    await tester.pumpAndSettle();
    expect(find.text('콩자반도'), findsNothing);
  });

  testWidgets('식당: 문장 틀에 자리 순서와 카드 뜻이 보이고, 문법 포인트가 붙는다', (tester) async {
    AppSession.language = 'en';
    tester.view.physicalSize = const Size(1200, 3000);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      const MaterialApp(home: ComposeScreen(scenario: restaurant)),
    );
    await tester.pumpAndSettle();

    // 자리 순서: 메뉴 → 몇 인분 → 맵기(빈자리) → 부탁
    for (final name in ['1 메뉴', '2 몇 인분', '3 맵기', '4 부탁']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('선택'), findsOneWidget);
    expect(find.text('kimchi stew'), findsOneWidget);

    // 맵기를 고르면 빈자리가 채워지고 ‘-게 해’ 설명이 붙는다
    await tester.tap(find.text('덜 맵게'));
    await tester.pumpAndSettle();
    expect(find.text('선택'), findsNothing);
    expect(find.text('덜 맵게 → 덜 맵게 해'), findsOneWidget);
    expect(find.textContaining('make it …, please'), findsOneWidget);
  });

  testWidgets('필리핀어 사용자는 칩 보조 문구와 사장님 대사를 필리핀어로 본다', (tester) async {
    AppSession.language = 'fil';
    tester.view.physicalSize = const Size(1200, 3000);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      const MaterialApp(home: ComposeScreen(scenario: restaurant)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Anghang'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: PracticeScreen(
          args: PracticeArgs(
            sentence: '김치찌개 1인분 덜 맵게 해 주세요. 돼지고기는 빼 주세요.',
            meaning: '',
            scenario: restaurant,
          ),
        ),
      ),
    );
    expect(find.text('식당 상황'), findsOneWidget);
    expect(find.text('김치찌개 1인분 덜 맵게 해 주세요. 돼지고기는 빼 주세요.'), findsOneWidget);
  });

  group('메뉴판에서 고른 요리', () {
    const spam = [MenuCardData(name: '스팸두부찌개', confidence: 1)];

    Future<void> pumpSpam(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 6000);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        const MaterialApp(
          home: ComposeScreen(scenario: restaurant, menus: spam),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('메뉴판에서 고른 찌개: 이름 속 재료는 ‘들어가요’ 안내, 육수는 질문 칩', (tester) async {
      await pumpSpam(tester);
      expect(find.text('1인분'), findsWidgets);
      // 스팸·두부는 메뉴 이름에 든 주재료라 빼기 칩 없이 안내만
      expect(find.textContaining('스팸두부찌개에 들어가요'), findsOneWidget);
      expect(find.text('스팸'), findsNothing);
      expect(find.text('빼 주세요'), findsNothing);
      expect(find.text('고기 육수'), findsOneWidget); // 들어가요? 칩
    });

    testWidgets('비건: 스팸은 맞지 않는다고 안내하고, 육수는 눌러서 묻는다', (tester) async {
      AppSession.diets.value = {Diet.vegan};
      await pumpSpam(tester);
      // 스팸은 비건에 맞지 않는다고 안내만 (빼 달라는 문장은 없음)
      expect(find.textContaining('비건에 맞지 않아요'), findsOneWidget);
      expect(find.text('스팸은 빼'), findsNothing);
      await tester.tap(find.text('고기 육수'));
      await tester.tap(find.text('멸치 육수'));
      await tester.pumpAndSettle();
      expect(find.text('고기 육수랑'), findsOneWidget);
      expect(find.text('멸치 육수'), findsNWidgets(2)); // 칩 + 문장 카드
    });

    test('유대교: 주재료 스팸은 맞지 않는다고, 두부는 괜찮다고 안내한다', () {
      final s = restaurant.forMenu('스팸두부찌개');
      final clash = {
        for (final i in s.mainIngredients)
          if (i.conflictsWith({Diet.judaism}).isNotEmpty) i.label,
      };
      expect([for (final i in s.mainIngredients) i.label], ['스팸', '두부']);
      expect(clash, {'스팸'});
      final marked = {
        for (final g in s.groupsFor({Diet.judaism}))
          for (final o in g.options)
            if (o.caution != null) o.label,
      };
      expect(marked, {'고기 육수'});
    });
  });

  test('메뉴 이름으로 요리·재료를 짐작한다', () {
    expect(isCookedDish('스팸두부찌개'), isTrue);
    expect(isCookedDish('제육볶음'), isTrue);
    expect(isCookedDish('삼겹살'), isFalse);
    expect(isCookedDish('소고기 국거리'), isFalse);
    List<String> labels(String m) => [
      for (final i in ingredientsFor(m)) i.label,
    ];
    expect(labels('스팸두부찌개'), containsAll(['스팸', '두부', '고기 육수', '멸치 육수']));
    expect(labels('스팸두부찌개'), isNot(contains('돼지고기')));
    expect(labels('비빔밥'), containsAll(['계란', '고기']));
    expect(labels('제육볶음'), contains('돼지고기'));
    // 조미료·맛술처럼 어느 집이나 넣는 양념은 묻지 않음
    expect(labels('제육볶음'), isNot(contains('맛술')));
    expect(labels('스팸두부찌개'), isNot(contains('조미료')));
    expect(labels('김치찌개'), containsAll(['돼지고기', '젓갈']));
    // 목살도 식당에서 ‘목살 1인분’
    expect(restaurant.forMenu('목살').id, 'restaurant');
    expect(restaurant.forMenu('스팸두부찌개').id, 'restaurant');
  });

  testWidgets('소주를 고르면 인분·맵기 대신 ‘한 병’으로 센다', (tester) async {
    AppSession.diets.value = {Diet.vegan};
    tester.view.physicalSize = const Size(1200, 6000);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      const MaterialApp(
        home: ComposeScreen(
          scenario: restaurant,
          menus: [MenuCardData(name: '소주', confidence: 1)],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('300그램'), findsNothing);
    expect(find.text('구이용'), findsNothing);
    expect(find.text('1인분'), findsNothing);
    expect(find.text('덜 맵게'), findsNothing);
    expect(find.text('한 병'), findsWidgets);
    expect(find.text('고기 육수'), findsNothing);
  });

  test('메뉴 이름으로 문장 틀을 고른다', () {
    List<String> titles(Scenario s) => [for (final g in s.groups) g.title];
    expect(titles(restaurant.forMenu('소주')), ['몇 병']);
    expect(titles(restaurant.forMenu('맥주')), ['몇 병']);
    expect(titles(restaurant.forMenu('생맥주')), ['몇 잔']);
    expect(titles(sideDish.forMenu('콜라')), ['몇 병']);
    expect(restaurant.forMenu('소주').ingredients, isEmpty);
    // 맵지 않은 요리는 맵기 없이, 매운 요리는 맵기 그대로
    expect(titles(restaurant.forMenu('계란말이')), ['몇 인분']);
    expect(titles(restaurant.forMenu('돈까스')), ['몇 인분']);
    expect(titles(restaurant.forMenu('된장찌개')), ['몇 인분', '맵기']);
    expect(titles(restaurant), ['몇 인분', '맵기']);
    // 구워 먹는 고기는 인분만 (빼기·질문 없음)
    for (final m in ['삼겹살', '목살', '항정살', '앞다리살', '등심', '소고기 국거리']) {
      final s = restaurant.forMenu(m);
      expect(s.id, 'restaurant', reason: m);
      expect([for (final g in s.groups) g.title], ['몇 인분'], reason: m);
      // 고기 자체가 메뉴라 빼기·질문 칩 없이 주재료 안내만
      expect(s.ingredients.every((i) => i.main), isTrue, reason: m);
      expect(s.groupsFor({Diet.islam}), hasLength(1), reason: m);
    }
    expect(restaurant.forMenu('파전').id, 'restaurant');
    expect(isDrink('물냉면'), isFalse);
  });

  group('메뉴 이름·레시피로 재료 짐작', () {
    List<String> labels(Scenario s) => [
      for (final i in s.ingredients) (i.hidden ? '?' : '') + i.label,
    ];

    test('김치고기짜글이: 무슨 고기인지 모르면 고기를 빼거나, 돼지고기·소고기를 묻는다', () {
      final s = restaurant.forMenu('김치고기짜글이');
      expect(s.id, 'restaurant');
      expect(
        labels(s),
        containsAll(['고기', '?돼지고기', '?소고기', '?고기 육수', '?멸치 육수', '?젓갈']),
      );
    });

    test('닭갈비·두루치기는 요리, LA갈비는 고기라 인분만', () {
      expect(restaurant.forMenu('닭갈비').id, 'restaurant');
      expect(restaurant.forMenu('돼지고기두루치기').id, 'restaurant');
      final galbi = restaurant.forMenu('LA갈비');
      expect(galbi.id, 'restaurant');
      expect(
        galbi.sentenceFor(galbi.groups, [
          [galbi.groups.first.options[1]],
        ]),
        'LA갈비 2인분 주세요.',
      );
    });

    test('비슷한 레시피가 여럿이면 절반 이상에 든 재료만 더한다', () {
      const match = RecipeMatch(
        mode: 'similar',
        recipes: [
          Recipe(
            name: '완자김치찌개',
            category: '국&찌개',
            main: ['김치', '다진 돼지고기', '새우젓'],
          ),
          Recipe(
            name: '오징어김치찌개',
            category: '국&찌개',
            main: ['오징어', '김치'],
            sauce: ['멸치', '다시마'],
          ),
          Recipe(
            name: '해물김치찌개',
            category: '국&찌개',
            main: ['주꾸미', '김치'],
            sauce: ['멸치'],
          ),
        ],
      );
      final s = restaurant.withMenu('두부김치찌개').withRecipe(match);
      expect(labels(s), contains('오징어')); // 3개 중 2개 (오징어·주꾸미)
      expect(labels(s), contains('?멸치 육수'));
      expect(s.recipes, hasLength(3));
    });

    test('레시피 양념·육수 쪽 재료는 ‘들어가요?’로 묻는다', () {
      const match = RecipeMatch(
        mode: 'exact',
        recipes: [
          Recipe(
            name: '토마토돼지고기해장국',
            category: '국&찌개',
            main: ['토마토', '돼지고기'],
            sauce: ['쇠고기', '청주', '굴소스'],
          ),
        ],
      );
      final s = restaurant.withMenu('토마토돼지고기해장국').withRecipe(match);
      expect(labels(s), containsAll(['돼지고기', '?고기 육수', '?굴소스']));
      expect(labels(s), isNot(contains('?맛술')));
    });

    test('손으로 쓴 시연 메뉴(김치찌개) 재료는 레시피로 바꾸지 않는다', () {
      const match = RecipeMatch(
        mode: 'exact',
        recipes: [
          Recipe(name: '김치찌개', main: ['참치']),
        ],
      );
      expect(identical(restaurant.withRecipe(match), restaurant), isTrue);
    });

    Set<String> marked(String menu, Set<Diet> diets) => {
      for (final g in restaurant.forMenu(menu).groupsFor(diets))
        for (final o in g.options)
          if (o.caution != null) (g.title == '들어가요?' ? '?' : '') + o.label,
    };

    test('유대교 + 김치고기짜글이: 고기 전체가 아니라 돼지고기 질문에 표시한다', () {
      final m = marked('김치고기짜글이', {Diet.judaism});
      expect(m, isNot(contains('고기')));
      expect(m, containsAll(['?돼지고기', '?고기 육수']));
    });

    test('비건 + 김치고기짜글이: 고기는 주재료 안내, 육수 질문에 표시한다', () {
      final m = marked('김치고기짜글이', {Diet.vegan});
      expect([
        for (final i in restaurant.forMenu('김치고기짜글이').mainIngredients) i.label,
      ], contains('고기'));
      expect(m, isNot(contains('고기')));
      expect(m, isNot(contains('?돼지고기')));
      expect(m, containsAll(['?고기 육수', '?멸치 육수']));
    });
  });

  test('공기밥은 ‘하나’로 세고, ○○ 추가·사리는 ‘추가해 주세요’로 시킨다', () {
    for (final m in ['공기밥', '밥', '계란후라이']) {
      final s = restaurant.forMenu(m);
      expect([for (final g in s.groups) g.title], ['몇 개'], reason: m);
      expect(s.ingredients, isEmpty, reason: m);
    }
    expect(pieceGroup.options.first.label, '하나');
    final rice = restaurant.forMenu('공기밥');
    expect(
      rice.sentenceFor(rice.groups, [
        [pieceGroup.options.first],
      ]),
      '공기밥 하나 주세요.',
    );
    for (final m in ['치즈 추가', '라면사리']) {
      final s = restaurant.forMenu(m);
      expect(s.isOrder, isTrue, reason: m);
      expect(s.ingredients, isEmpty, reason: m);
    }
    final cheese = restaurant.forMenu('치즈 추가');
    expect(cheese.sentenceFor(const [], const []), '치즈 추가해 주세요.');
    // 비빔밥은 요리
    expect(restaurant.forMenu('비빔밥').ingredients, isNotEmpty);
  });

  group('여러 메뉴를 한 번에 주문', () {
    final order = restaurant.forOrder([
      ('김치찌개', 'canh kim chi'),
      ('공기밥', 'cơm'),
      ('치즈 추가', 'phô mai'),
      ('콜라', 'Coca'),
      ('라면사리', 'mì'),
    ]);
    List<List<ScenarioOption>> none() => [for (final _ in order.groups) []];

    test('처음에는 개수·맵기 없이 ‘김치찌개랑 공기밥이랑 콜라 주세요’', () {
      expect(
        order.sentenceFor(order.groups, none()),
        '김치찌개랑 공기밥이랑 콜라 주세요. 치즈랑 라면사리 추가해 주세요.',
      );
      expect(
        order.meaningFor(order.groups, none()),
        'Cho tôi canh kim chi, cơm, thêm phô mai, Coca, thêm mì.',
      );
    });

    test('개수는 메뉴 뒤에 ‘-랑’으로, 맵기는 메뉴마다 따로 한 문장', () {
      final picked = none();
      int at(String item, String title) =>
          order.groups.indexWhere((g) => g.item == item && g.title == title);
      final serving = at('김치찌개', '몇 인분');
      final spicy = at('김치찌개', '맵기');
      final rice = at('공기밥', '몇 개');
      final cola = at('콜라', '몇 병');
      picked[serving] = [order.groups[serving].options[1]]; // 2인분
      picked[spicy] = [order.groups[spicy].options[0]]; // 덜 맵게
      picked[rice] = [order.groups[rice].options[0]]; // 하나
      picked[cola] = [order.groups[cola].options[0]]; // 한 병
      expect(
        order.sentenceFor(order.groups, picked),
        '김치찌개 2인분이랑 공기밥 하나랑 콜라 한 병 주세요. '
        '김치찌개는 덜 맵게 해 주세요. 치즈랑 라면사리 추가해 주세요.',
      );
    });

    test('재료(빼 주세요·들어가요?)는 요리 메뉴 것만 합친다', () {
      final labels = [for (final i in order.ingredients) i.label];
      expect(labels, contains('돼지고기')); // 김치찌개
      expect(labels, isNot(contains('치즈'))); // 치즈 추가는 재료 문장 없음
    });

    testWidgets('문장 만들기: 메뉴 칩 없이 한 문장, 칩을 누르면 바로 붙는다', (tester) async {
      tester.view.physicalSize = const Size(1200, 8000);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        const MaterialApp(
          home: ComposeScreen(
            scenario: restaurant,
            menus: [
              MenuCardData(name: '콜라', confidence: 1, meaning: 'Coca'),
              MenuCardData(name: '사이다', confidence: 1, meaning: 'Sprite'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('콜라 · 사이다'), findsNothing); // 메뉴 고르기 칩 없음
      expect(find.text('콜라랑'), findsOneWidget);
      expect(find.text('Cho tôi Coca, Sprite.'), findsOneWidget);
      // 콜라 · 몇 병 → 한 병
      await tester.tap(find.text('한 병').first);
      await tester.pumpAndSettle();
      expect(find.text('한 병이랑'), findsOneWidget);
    });
  });

  group('디저트·음료·세는 말', () {
    test('케이크는 ‘한 개’로 세고, 빼기 없이 계란·우유만 묻는다 (고기 X)', () {
      final cake = restaurant.forMenu('초코케이크');
      expect([for (final g in cake.groups) g.title], ['몇 개']);
      expect(cake.groups.first.options.first.label, '한 개');
      final groups = cake.groupsFor({Diet.vegan});
      expect(groups.where((g) => g.title == '빼 주세요'), isEmpty);
      final ask = groups.firstWhere((g) => g.title == '들어가요?');
      final labels = [for (final o in ask.options) o.label];
      expect(labels, containsAll(['계란', '우유']));
      expect(labels, isNot(contains('고기')));
      expect(
        cake.sentenceFor(cake.groups, [
          [cake.groups.first.options.first],
        ]),
        '초코케이크 한 개 주세요.',
      );
      // 젤라틴(돼지·소)은 젤리·무스류에만
      expect([
        for (final i in restaurant.forMenu('티라미수').ingredients) i.label,
      ], containsAll(['젤라틴', '술']));
    });

    test('음료는 재료를 묻지 않는다', () {
      for (final m in ['아이스티', '딸기우유', '유자차', '밀크티', '카페라떼']) {
        final s = restaurant.forMenu(m);
        expect(isDrink(m), isTrue, reason: m);
        expect(s.ingredients, isEmpty, reason: m);
      }
      expect(isDrink('카스텔라'), isFalse);
      expect(isDrink('물냉면'), isFalse);
    });

    test('치킨은 마리, 피자는 판, 김밥은 줄로 센다', () {
      String first(String m) =>
          restaurant.forMenu(m).groups.first.options.first.label;
      expect(first('양념치킨'), '한 마리');
      expect(first('불고기피자'), '한 판');
      expect(first('참치김밥'), '한 줄');
      expect(first('김치찌개'), '1인분');
    });
  });

  test('여러 메뉴: 빼기·질문은 메뉴마다 따로 묻는다', () {
    final order = restaurant.forOrder([
      ('김치찌개', null),
      ('떡볶이', null),
      ('콜라', null),
    ]);
    final groups = order.groupsFor(const {});
    final picked = [for (final _ in groups) <ScenarioOption>[]];
    int at(String item, String title) =>
        groups.indexWhere((g) => g.item == item && g.title == title);
    final without = at('김치찌개', '빼 주세요');
    final ask = at('떡볶이', '들어가요?');
    expect(at('콜라', '들어가요?'), -1); // 음료는 재료 질문 없음
    picked[without] = [
      groups[without].options.firstWhere((o) => o.label == '돼지고기'),
      groups[without].options.firstWhere((o) => o.label == '두부'),
    ];
    picked[ask] = [groups[ask].options.firstWhere((o) => o.label == '고기')];
    expect(
      order.sentenceFor(groups, picked),
      '김치찌개랑 떡볶이랑 콜라 주세요. '
      '김치찌개는 돼지고기랑 두부 빼 주세요. 떡볶이에 고기 들어가요?',
    );
  });

  test('새우튀김·삼겹살: 이름 속 재료는 빼 달라고 하지 않고 ‘들어가요’로 안내한다', () {
    final shrimp = restaurant.forMenu('새우튀김');
    expect([for (final i in shrimp.mainIngredients) i.label], ['새우']);
    final groups = shrimp.groupsFor({Diet.judaism});
    expect(groups.where((g) => g.title == '빼 주세요'), isEmpty);
    final pork = restaurant.forMenu('삼겹살');
    expect([for (final i in pork.mainIngredients) i.label], ['돼지고기']);
    expect(pork.mainIngredients.first.conflictsWith({Diet.islam}), [
      Diet.islam,
    ]);
    // 김치찌개의 돼지고기처럼 이름이 직접 말하지 않는 재료는 빼 달라고 할 수 있음
    final kimchi = restaurant.forMenu('두부김치찌개');
    final without = kimchi
        .groupsFor(const {})
        .firstWhere((g) => g.title == '빼 주세요');
    expect([for (final o in without.options) o.label], contains('돼지고기'));
    expect([for (final o in without.options) o.label], isNot(contains('두부')));
  });

  test('모든 시나리오 문구에 네 가지 언어 번역이 있다', () {
    const langs = ['vi', 'en', 'fil', 'km'];
    void check(Tr m, String where) {
      for (final l in langs) {
        expect(m[l], isNotNull, reason: '$where: $l 없음');
        expect(m[l], isNotEmpty, reason: '$where: $l 비어 있음');
      }
    }

    for (final s in Scenario.all) {
      check(s.menuMeaning, '${s.id} 메뉴');
      // 재료로 만든 빼기·질문 그룹까지 모두 확인합니다.
      for (final g in s.groupsFor(Diet.values.toSet())) {
        check(g.sub, '${s.id} ${g.title}');
        if (g.rule case final r?) check(r, '${s.id} ${g.title} 문법');
        for (final o in g.options) {
          check(o.meaning, '${s.id} ${o.label}');
          if (o.info case final i?) check(i, '${s.id} ${o.label} 안내');
        }
      }
      for (final t in s.turns) {
        check(t.aiMeaning, '${s.id} ${t.ai}');
        if (t.targetMeaning case final m?) check(m, '${s.id} ${t.target}');
      }
    }
    for (final d in Diet.values) {
      check(d.about, '식단 ${d.label}');
    }
  });
}
