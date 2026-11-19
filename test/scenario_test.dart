import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:iju/app/diet.dart';
import 'package:iju/app/session.dart';
import 'package:iju/features/compose/compose_screen.dart';
import 'package:iju/features/practice/practice_screen.dart';
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

  testWidgets('이슬람: 돼지고기는 빼 달라고, 고기 육수는 들어가는지 묻는 문장이 미리 들어간다', (tester) async {
    AppSession.diets.value = {Diet.islam};
    tester.view.physicalSize = const Size(1200, 6000);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      const MaterialApp(home: ComposeScreen(scenario: restaurant)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('이슬람 (할랄)'), findsOneWidget);
    expect(find.text('돼지고기는 빼'), findsOneWidget);
    // 고기 육수는 칩 + 문장 카드
    expect(find.text('고기 육수'), findsNWidgets(2));
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
    expect(find.text('주세요.'), findsOneWidget);
    expect(find.text('돼지고기는 빼'), findsNothing);
  });

  testWidgets('비건 + 이슬람: 여러 종교·식단의 재료를 합쳐 ‘-랑’으로 묻는다', (tester) async {
    AppSession.diets.value = {Diet.vegan, Diet.islam};
    tester.view.physicalSize = const Size(1200, 6000);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      const MaterialApp(home: ComposeScreen(scenario: restaurant)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('비건 · 이슬람 (할랄)'), findsOneWidget);
    expect(find.text('고기 육수랑'), findsOneWidget);
    expect(find.text('멸치 육수랑'), findsOneWidget);
    expect(find.text('젓갈'), findsNWidgets(2)); // 칩 + 마지막 카드
  });

  testWidgets('재료 칩(빼 주세요·들어가요?)에는 ⓘ가 없다', (tester) async {
    AppSession.diets.value = {Diet.hindu};
    tester.view.physicalSize = const Size(1200, 6000);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      const MaterialApp(home: ComposeScreen(scenario: restaurant)),
    );
    await tester.pumpAndSettle();

    // 힌두교: 소고기가 들어갈 수 있는 고기 육수를 묻는 문장이 미리 들어간다
    expect(find.text('고기 육수'), findsNWidgets(2));
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

  testWidgets('정육점: 문장 틀에 자리 순서와 카드 뜻이 보이고, 문법 포인트가 붙는다', (tester) async {
    AppSession.language = 'en';
    // 문법 포인트까지 한 화면에 보이도록 세로로 긴 화면에서 확인합니다.
    tester.view.physicalSize = const Size(1200, 3000);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const MaterialApp(home: ComposeScreen()));
    await tester.pumpAndSettle();

    // 자리 순서: 메뉴 → 얼마나 → 용도 → 손질(빈자리) → 부탁
    for (final name in ['1 메뉴', '2 얼마나', '3 용도', '4 손질', '5 부탁']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('선택'), findsOneWidget);
    expect(find.text('pork belly'), findsOneWidget);
    expect(find.text('for grilling'), findsOneWidget);

    // 구이용 → 구이용으로 설명
    expect(find.text('구이용 → 구이용으로'), findsOneWidget);
    expect(find.textContaining('It means “for …”'), findsOneWidget);

    // 손질을 고르면 빈자리가 채워지고 ‘썰어’ 설명이 추가된다
    await tester.tap(find.text('얇게'));
    await tester.pumpAndSettle();
    expect(find.text('선택'), findsNothing);
    expect(find.text('얇게 썰어'), findsOneWidget);
    expect(find.text('얇게 → 얇게 썰어'), findsOneWidget);
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
    expect(find.text('식당 상황 · 1/2 턴'), findsOneWidget);
    expect(
      find.text('Magandang araw po. Oorder na po ba kayo?'),
      findsOneWidget,
    );
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
