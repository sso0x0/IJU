import 'package:flutter_test/flutter_test.dart';
import 'package:iju/app/session.dart';
import 'package:iju/features/menu_scan/menu_card.dart';
import 'package:iju/features/menu_scan/menu_scan_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:iju/app/diet.dart';
import 'package:iju/widgets/verdict_badge.dart';

void main() {
  test('식단을 고르지 않으면 판정하지 않아요', () {
    expect(MenuVerdict.of('김치찌개', const {}), isNull);
  });

  test('할랄: 제육볶음은 주재료 돼지고기라 피하세요', () {
    final v = MenuVerdict.of('제육볶음', {Diet.islam})!;
    expect(v.verdict, Verdict.avoid);
    expect(v.hits, isNotEmpty);
  });

  test('할랄: 계란말이는 먹어도 돼요', () {
    final v = MenuVerdict.of('계란말이', {Diet.islam})!;
    expect(v.verdict, Verdict.safe);
  });

  test('비건: 김치찌개는 피하거나 물어봐야 해요', () {
    final v = MenuVerdict.of('김치찌개', {Diet.vegan})!;
    expect(v.verdict, isNot(Verdict.safe));
  });

  testWidgets('메뉴 카드에 판정 배지와 이유가 보여요', (tester) async {
    AppSession.diets.value = {Diet.islam};
    addTearDown(() => AppSession.diets.value = const {});
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MenuCard(
            menu: const MenuCardData(name: '삼겹살', confidence: 0.9),
            selected: false,
            onSelect: () {},
            onEdit: () {},
          ),
        ),
      ),
    );
    expect(find.text('피하세요'), findsOneWidget);
    expect(find.text('돼지고기가 들어가요'), findsOneWidget);
  });
}
