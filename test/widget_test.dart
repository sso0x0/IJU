import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:iju/app/app.dart';
import 'package:iju/app/router.dart';
import 'package:iju/features/menu_scan/menu_scan_api.dart';
import 'package:iju/features/review/review_store.dart';

Future<void> _pumpApp(WidgetTester tester, String locale) async {
  tester.platformDispatcher.localesTestValue = [Locale(locale)];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  // appRouter는 전역이라 앞 테스트에서 이동한 화면이 남아 있습니다.
  appRouter.go(AppRoutes.login);
  ReviewStore.reset();
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
    // 메뉴판 인식은 사진을 찍거나 골라야 해서 테스트에서는 버튼만 확인하고,
    // 메뉴를 고른 뒤처럼 문장 만들기 화면으로 바로 넘어갑니다.
    expect(find.text('메뉴판 찍기'), findsOneWidget);
    appRouter.push(AppRoutes.compose);
    await tester.pumpAndSettle();
    expect(find.text('Cho tôi 600g thịt ba chỉ để nướng.'), findsOneWidget);

    await _tap(tester, '찌개용');
    expect(find.text('찌개용으로'), findsOneWidget);
    expect(find.text('Cho tôi 600g thịt ba chỉ để nấu canh.'), findsOneWidget);

    await _tap(tester, '말하기 연습하기');
    expect(find.text('AI 사장님과 연습'), findsOneWidget);

    await _tap(tester, '실전으로 가기');
    // 힌트(무게·용도)는 Figma 시연 문장(구이용)에만 붙고, 찌개용 문장에는 없습니다.
    expect(find.text('실전 주문'), findsOneWidget);

    await _tap(tester, '막히면 전체 보기');
    expect(find.text('600그램'), findsOneWidget);

    // 영수증 인증은 사진을 찍거나 골라야 해서 고르는 창이 뜨는 것까지만 확인하고,
    // 인증이 끝난 뒤처럼 보상 화면으로 바로 넘어갑니다.
    await _tap(tester, '주문했어요 · 영수증 인증하기');
    expect(find.text('카메라로 찍기'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10)); // 바깥을 눌러 창 닫기
    await tester.pumpAndSettle();
    appRouter.go(AppRoutes.reward);
    await tester.pumpAndSettle();
    expect(find.text('미션 완료!'), findsOneWidget);

    await _tap(tester, '다음 미션 보기');
    expect(find.text('추천 미션'), findsOneWidget);
  });

  testWidgets('메뉴판에서 고른 메뉴가 문장 만들기와 말하기 연습에 이어진다', (tester) async {
    await _pumpApp(tester, 'ko');
    await _tap(tester, '로그인 · Đăng nhập');

    // 메뉴판 인식에서 두 메뉴를 고르고 '문장 만들기'를 누른 것과 같습니다.
    appRouter.push(
      AppRoutes.compose,
      extra: const [
        MenuCardData(name: '목살', confidence: 0.9, meaning: 'thịt nạc vai'),
        MenuCardData(name: '앞다리살', confidence: 0.9),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.text('1 메뉴'), findsOneWidget);
    expect(find.text('Cho tôi 600g thịt nạc vai để nướng.'), findsOneWidget);

    await _tap(tester, '앞다리살');
    await tester.pump(const Duration(seconds: 1)); // 서버 요청 대기 타이머
    await tester.pumpAndSettle();

    await _tap(tester, '말하기 연습하기');
    expect(find.text('앞다리살 600그램 구이용으로 주세요.'), findsOneWidget);
    expect(find.text('이렇게 말해 보세요'), findsOneWidget);
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

    await tester.tap(find.text('1단계 · 그대로 말하기').first);
    await tester.pumpAndSettle();
    expect(find.text('AI 사장님과 연습'), findsOneWidget);
  });
}
