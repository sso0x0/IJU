import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:iju/app/app.dart';
import 'package:iju/app/router.dart';

Future<void> _pumpApp(WidgetTester tester, String locale) async {
  tester.platformDispatcher.localesTestValue = [Locale(locale)];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  // appRouter는 전역이라 앞 테스트에서 이동한 화면이 남아 있습니다.
  appRouter.go(AppRoutes.login);
  await tester.pumpWidget(const IjuApp());
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String text) async {
  final target = find.text(text);
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('한국어 환경에서 로그인 화면을 보여준다', (tester) async {
    await _pumpApp(tester, 'ko');

    expect(find.text('이주'), findsOneWidget);
    expect(find.text('동네 가게에서 배우는 생활 한국어'), findsOneWidget);
    expect(find.text('다시 오셨네요!'), findsOneWidget);
  });

  testWidgets('영어 환경에서 앱 이름을 영어로 보여준다', (tester) async {
    await _pumpApp(tester, 'en');

    expect(find.text('IJU'), findsOneWidget);
  });

  testWidgets('처음이에요 → 온보딩 → 홈으로 이동한다', (tester) async {
    await _pumpApp(tester, 'ko');

    await _tap(tester, '처음이에요 · Bắt đầu mới');
    expect(find.text('모국어를 골라 주세요 · Chọn ngôn ngữ'), findsOneWidget);

    await _tap(tester, '시작하기 · Bắt đầu');
    expect(find.text('추천 미션'), findsOneWidget);
  });

  testWidgets('시연 경로를 홈부터 보상까지 끝까지 누를 수 있다', (tester) async {
    await _pumpApp(tester, 'ko');

    await _tap(tester, '로그인 · Đăng nhập');
    await _tap(tester, '이어서 하기');
    expect(find.text('메뉴판 인식'), findsOneWidget);

    await _tap(tester, '이 메뉴로 문장 만들기');
    expect(find.text('Cho tôi 600g thịt ba chỉ để nướng.'), findsOneWidget);

    await _tap(tester, '찌개용');
    expect(find.text('찌개용으로'), findsOneWidget);
    expect(find.text('Cho tôi 600g thịt ba chỉ để nấu canh.'), findsOneWidget);

    await _tap(tester, '말하기 연습하기');
    expect(find.text('AI 사장님과 연습'), findsOneWidget);

    await _tap(tester, '실전으로 가기');
    expect(find.text('힌트: 무게'), findsOneWidget);

    await _tap(tester, '막히면 전체 보기');
    expect(find.text('600그램'), findsOneWidget);

    await _tap(tester, '주문했어요 · 영수증 인증하기');
    expect(find.text('미션 완료!'), findsOneWidget);

    await _tap(tester, '다음 미션 보기');
    expect(find.text('추천 미션'), findsOneWidget);
  });

  testWidgets('하단 탭으로 미션 · 복습 · 내 정보 화면을 오간다', (tester) async {
    await _pumpApp(tester, 'ko');
    await _tap(tester, '로그인 · Đăng nhập');

    await _tap(tester, '미션');
    expect(find.text('완료한 미션 1'), findsOneWidget);
    expect(find.text('추천 미션 2'), findsOneWidget);

    await _tap(tester, '내 정보');
    expect(find.text('Nguyen'), findsWidgets);
    expect(find.text('내 쿠폰 1'), findsOneWidget);

    await _tap(tester, '복습');
    expect(find.text('오늘 복습할 문장 1개'), findsOneWidget);

    await tester.tap(find.text('다시 말해 보기').first);
    await tester.pumpAndSettle();
    expect(find.text('AI 사장님과 연습'), findsOneWidget);
  });
}
