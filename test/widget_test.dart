import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:iju/app/app.dart';
import 'package:iju/app/router.dart';
import 'package:iju/features/menu_scan/menu_card.dart';
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

/// 메뉴 이름은 예시 메뉴판 그림에도 있어서 메뉴 카드를 찾아 누릅니다.
Future<void> _tapMenu(WidgetTester tester, String name) async {
  final target = find.widgetWithText(MenuCard, name);
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  // 아래 고정 버튼에 가리지 않게 카드를 위로 올립니다.
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
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

  testWidgets('처음이에요 → 회원가입 화면을 보여준다', (tester) async {
    await _pumpApp(tester, 'ko');

    await _tap(tester, '처음이에요 · Đăng ký');
    expect(find.text('회원가입'), findsOneWidget);
    expect(find.text('[필수] 이용약관 동의'), findsOneWidget);
    expect(find.text('가입하기 · Đăng ký'), findsOneWidget);
  });

  testWidgets('로그인 칸을 비우고 누르면 안내를 보여준다', (tester) async {
    await _pumpApp(tester, 'ko');

    await _tap(tester, '로그인 · Đăng nhập');
    expect(find.text('아이디를 입력해 주세요.'), findsOneWidget);
    expect(find.text('비밀번호를 입력해 주세요.'), findsOneWidget);
  });

  testWidgets('온보딩 → 홈으로 이동한다', (tester) async {
    await _pumpApp(tester, 'ko');
    appRouter.push(AppRoutes.onboarding);
    await tester.pumpAndSettle();
    expect(find.text('모국어를 골라 주세요 · Chọn ngôn ngữ'), findsOneWidget);

    await _tap(tester, '시작하기 · Bắt đầu');
    expect(find.text('메뉴판 찍고 시작'), findsOneWidget);
  });

  testWidgets('시연 경로를 홈부터 보상까지 끝까지 누를 수 있다', (tester) async {
    await _pumpApp(tester, 'ko');

    await _tap(tester, '로그인 없이 둘러보기');
    await _tap(tester, '메뉴판 찍고 시작');
    // 사진을 찍는 대신 예시 메뉴판으로 메뉴를 골라 문장 만들기로 넘어갑니다.
    expect(find.text('식당 미션 · 1/4'), findsOneWidget);
    await _tap(tester, '예시 메뉴판');
    expect(find.text('식당 미션 · 2/4'), findsOneWidget);
    expect(find.text('무엇을 주문할까요?'), findsOneWidget);
    await _tapMenu(tester, '삼겹살');
    await _tap(tester, '삼겹살로 문장 만들기');
    // 식당 기준: 그램·용도 대신 인분
    expect(find.text('Cho tôi 1 phần thịt ba chỉ.'), findsOneWidget);

    await _tap(tester, '2인분');
    expect(find.text('Cho tôi 2 phần thịt ba chỉ.'), findsOneWidget);

    await _tap(tester, '말하기 연습하기');
    expect(find.text('AI 사장님과 연습'), findsOneWidget);

    await _tap(tester, '실전으로 가기');
    // 힌트(무게·용도)는 Figma 시연 문장(구이용)에만 붙고, 찌개용 문장에는 없습니다.
    expect(find.text('실전 주문'), findsOneWidget);

    await _tap(tester, '막히면 전체 보기');
    expect(find.text('2인분'), findsWidgets);

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
    expect(find.text('메뉴판 찍고 시작'), findsOneWidget);
  });

  testWidgets('홈에서 예시 메뉴판으로 바로 연습할 수 있다', (tester) async {
    await _pumpApp(tester, 'ko');
    await _tap(tester, '로그인 없이 둘러보기');

    await _tap(tester, '아직 가게 전이에요 · 예시 메뉴판으로 연습');
    expect(find.text('식당 미션 · 2/4'), findsOneWidget);
    expect(find.text('메뉴를 골라 주세요'), findsOneWidget);

    await _tapMenu(tester, '제육볶음');
    expect(find.text('제육볶음으로 문장 만들기'), findsOneWidget);

    await _tap(tester, '직접 찍기');
    expect(find.text('식당 미션 · 1/4'), findsOneWidget);
  });

  testWidgets('메뉴판에서 고른 메뉴가 문장 만들기와 말하기 연습에 이어진다', (tester) async {
    await _pumpApp(tester, 'ko');
    await _tap(tester, '로그인 없이 둘러보기');

    // 메뉴판 인식에서 두 메뉴를 고르고 '문장 만들기'를 누른 것과 같습니다.
    appRouter.push(
      AppRoutes.compose,
      extra: const [
        MenuCardData(name: '목살', confidence: 0.9, meaning: 'thịt nạc vai'),
        MenuCardData(name: '앞다리살', confidence: 0.9),
      ],
    );
    await tester.pumpAndSettle();
    // 두 메뉴를 한 번에 주문하는 문장
    expect(find.text('목살이랑'), findsOneWidget);
    expect(find.text('Cho tôi thịt nạc vai, 앞다리살.'), findsOneWidget);

    await _tap(tester, '말하기 연습하기');
    expect(find.text('목살이랑 앞다리살 주세요.'), findsOneWidget);
    expect(find.text('이렇게 말해 보세요'), findsOneWidget);
  });

  testWidgets('하단 탭으로 미션 · 복습 · 내 정보 화면을 오간다', (tester) async {
    await _pumpApp(tester, 'ko');
    await _tap(tester, '로그인 없이 둘러보기');

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
