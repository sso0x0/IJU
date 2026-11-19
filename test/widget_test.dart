import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:iju/app/app.dart';

void main() {
  testWidgets('한국어 환경에서 홈 화면을 보여준다', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('ko')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(const IjuApp());
    await tester.pumpAndSettle();

    expect(find.text('이주'), findsOneWidget);
    expect(find.text('동네 가게를 교실 삼아 배우는 생활 한국어'), findsOneWidget);
  });

  testWidgets('영어 환경에서 홈 화면을 영어로 보여준다', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('en')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(const IjuApp());
    await tester.pumpAndSettle();

    expect(find.text('IJU'), findsOneWidget);
  });
}
