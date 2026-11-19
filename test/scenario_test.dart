import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:iju/app/session.dart';
import 'package:iju/features/compose/compose_screen.dart';
import 'package:iju/features/practice/practice_screen.dart';
import 'package:iju/features/scenario/scenarios.dart';

void main() {
  tearDown(() => AppSession.language = 'vi');

  testWidgets('식당 시나리오: 맵기 카드가 ‘-게 해’ 모양으로 들어간다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ComposeScreen(scenario: restaurant)),
    );
    await tester.pumpAndSettle();

    expect(find.text('제육볶음'), findsOneWidget);
    expect(find.text('덜 맵게 해'), findsOneWidget);
    expect(
      find.text('Cho tôi 1 phần thịt heo xào cay ít cay.'),
      findsOneWidget,
    );

    await tester.tap(find.text('아주 맵게'));
    await tester.pumpAndSettle();
    expect(find.text('아주 맵게 해'), findsOneWidget);
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

  testWidgets('필리핀어 사용자는 칩 보조 문구와 사장님 대사를 필리핀어로 본다', (tester) async {
    AppSession.language = 'fil';
    await tester.pumpWidget(
      const MaterialApp(home: ComposeScreen(scenario: restaurant)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Anghang'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: PracticeScreen(
          args: PracticeArgs(
            sentence: '제육볶음 1인분 덜 맵게 해 주세요.',
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
      for (final g in s.groups) {
        check(g.sub, '${s.id} ${g.title}');
        for (final o in g.options) {
          check(o.meaning, '${s.id} ${o.label}');
        }
      }
      for (final t in s.turns) {
        check(t.aiMeaning, '${s.id} ${t.ai}');
        if (t.targetMeaning case final m?) check(m, '${s.id} ${t.target}');
      }
    }
  });
}
