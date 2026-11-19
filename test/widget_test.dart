import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:iju/app/app.dart';

void main() {
  testWidgets('한국어 환경에서 온보딩 화면을 보여준다', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('ko')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(const IjuApp());
    await tester.pumpAndSettle();

    expect(find.text('이주'), findsOneWidget);
    expect(find.text('동네 가게에서 배우는 생활 한국어'), findsOneWidget);
  });

  testWidgets('영어 환경에서 앱 이름을 영어로 보여준다', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('en')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(const IjuApp());
    await tester.pumpAndSettle();

    expect(find.text('IJU'), findsOneWidget);
  });

  testWidgets('시작하기 → 홈 → 메뉴판 인식으로 이동한다', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('ko')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(const IjuApp());
    await tester.pumpAndSettle();

    final start = find.text('시작하기 · Bắt đầu');
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pumpAndSettle();
    expect(find.text('오늘은 어디에 가 볼까요?'), findsOneWidget);

    await tester.tap(find.text('이어서 하기'));
    await tester.pumpAndSettle();
    expect(find.text('메뉴판 인식'), findsOneWidget);
  });
}
