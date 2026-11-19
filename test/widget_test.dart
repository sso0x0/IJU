import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:iju/app/app.dart';
import 'package:iju/app/router.dart';
import 'package:iju/app/session.dart';
import 'package:iju/widgets/iju_text_field.dart';
import 'package:iju/features/nearby/nearby_api.dart';
import 'package:iju/widgets/place_map.dart';
import 'package:iju/features/menu_scan/menu_card.dart';
import 'package:iju/features/menu_scan/menu_scan_api.dart';
import 'package:iju/features/review/review_store.dart';

Future<void> _pumpApp(WidgetTester tester, String locale) async {
  tester.platformDispatcher.localesTestValue = [Locale(locale)];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  // appRouter는 전역이라 앞 테스트에서 이동한 화면이 남아 있습니다.
  appRouter.go(AppRoutes.login);
  AppSession.language = 'vi';
  ReviewStore.reset();
  AppSession.diets.value = const {};
  await tester.pumpWidget(const IjuApp());
  await tester.pumpAndSettle();
}

/// 로그인한 뒤처럼 홈으로 갑니다 (로그인 없이 둘러보기는 없어졌어요).
Future<void> _goHome(WidgetTester tester) async {
  appRouter.go(AppRoutes.home);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String text) async {
  final target = find.text(text);
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// 메뉴 카드의 선택 체크를 눌러 메뉴를 고릅니다 (카드를 누르면 상세 시트가 열려요).
Future<void> _tapMenu(WidgetTester tester, String name) async {
  // 카드 안에서 InkWell이 아닌 InkResponse는 선택 체크뿐이에요.
  final target = find.descendant(
    of: find.widgetWithText(MenuCard, name),
    matching: find.byWidgetPredicate((w) => w is InkResponse && w is! InkWell),
  );
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  PlaceMap.showTiles = false;
  // 테스트에는 위치 플러그인이 없어요: 위치를 허용하지 않은 것처럼.
  NearbyApi.locate = () async =>
      throw const LocationException(LocationProblem.denied);

  testWidgets('한국어 환경에서 로그인 화면을 보여준다', (tester) async {
    await _pumpApp(tester, 'ko');

    expect(find.text('이주'), findsOneWidget);
    expect(find.text('동네 가게에서 배우는 생활 한국어'), findsOneWidget);
    expect(find.text('다시 만나서 반가워요'), findsOneWidget);
  });

  testWidgets('영어 환경에서 앱 이름을 영어로 보여준다', (tester) async {
    await _pumpApp(tester, 'en');

    expect(find.text('IJU'), findsOneWidget);
  });

  testWidgets('처음이에요 → 온보딩 4단계 → 회원가입 화면을 보여준다', (tester) async {
    await _pumpApp(tester, 'ko');
    expect(find.text('로그인 없이 둘러보기'), findsNothing);

    await _tap(tester, '처음이에요 · Đăng ký');
    expect(find.text('어떤 말이 편해요?'), findsOneWidget);
    await _tap(tester, 'Filipino');
    await _tap(tester, '다음');

    expect(find.text('나는 누구예요?'), findsOneWidget);
    await _tap(tester, '근로자');
    await tester.scrollUntilVisible(
      find.byType(IjuTextField),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.descendant(
        of: find.byType(IjuTextField),
        matching: find.byType(EditableText),
      ),
      'Lan',
    );
    await tester.pump();
    await _tap(tester, '다음');

    expect(find.text('어떤 식단을 지켜요?'), findsOneWidget);
    await _tap(tester, '다음');

    expect(find.text('종교가 있어요?'), findsOneWidget);
    await _tap(tester, '이슬람');
    expect(find.text('할랄 음식만 먹어요'), findsOneWidget);
    await _tap(tester, '다 됐어요');

    expect(find.text('회원가입'), findsOneWidget);
    // 온보딩에서 고른 언어(필리핀어)로 보조 문구가 바뀌어요.
    expect(AppSession.language, 'fil');
    // 약관 동의는 입력 칸 아래에 있어서 테스트 화면(800x600)에서는 내려야 보입니다.
    await tester.scrollUntilVisible(
      find.text('[필수] 이용약관 동의'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('[필수] 이용약관 동의'), findsOneWidget);
  });

  testWidgets('로그인 칸을 비우고 누르면 안내를 보여준다', (tester) async {
    await _pumpApp(tester, 'ko');

    await _tap(tester, '로그인 · Đăng nhập');
    expect(find.text('아이디를 입력해 주세요.'), findsOneWidget);
    expect(find.text('비밀번호를 입력해 주세요.'), findsOneWidget);
  });

  testWidgets('시연 경로를 홈부터 보상까지 끝까지 누를 수 있다', (tester) async {
    await _pumpApp(tester, 'ko');

    await _goHome(tester);
    await _tap(tester, '메뉴판 찍고 시작');
    // 사진을 찍는 대신 예시 메뉴판으로 메뉴를 골라 문장 만들기로 넘어갑니다.
    expect(find.text('메뉴판이 화면에 꽉 차게 찍어 주세요'), findsOneWidget);
    await _tap(tester, '예시 메뉴판');
    expect(find.text('메뉴 결과'), findsOneWidget);
    await _tap(tester, '목록에서 메뉴 고르기');
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
    await _goHome(tester);

    await _tap(tester, '가게 가기 전이에요 · 예시 메뉴판으로 연습');
    expect(find.text('메뉴 결과'), findsOneWidget);
    await _tap(tester, '목록에서 메뉴 고르기');
    expect(find.text('메뉴를 골라 주세요'), findsOneWidget);

    await _tapMenu(tester, '제육볶음');
    expect(find.text('제육볶음으로 문장 만들기'), findsOneWidget);

    // 카드를 한 번 더 누르면 선택이 빠져요 (상세 시트는 없어요).
    await tester.tap(find.widgetWithText(MenuCard, '제육볶음'));
    await tester.pumpAndSettle();
    expect(find.text('메뉴를 골라 주세요'), findsOneWidget);
    expect(find.textContaining('사장님께 물어볼 말'), findsNothing);

    await tester.tap(find.byTooltip('다시 찍기 · Chụp lại'));
    await tester.pumpAndSettle();
    expect(find.text('메뉴판이 화면에 꽉 차게 찍어 주세요'), findsOneWidget);
  });

  testWidgets('메뉴판에서 고른 메뉴가 문장 만들기와 말하기 연습에 이어진다', (tester) async {
    await _pumpApp(tester, 'ko');
    await _goHome(tester);

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

  testWidgets('하단 탭으로 커뮤니티 · 복습 · 마이페이지 화면을 오간다', (tester) async {
    await _pumpApp(tester, 'ko');
    await _goHome(tester);

    await _tap(tester, '커뮤니티');
    // 테스트에는 서버가 없어서 예시 글을 보여 줘요 (서버 요청이 실패할 때까지 기다려요).
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    expect(find.text('팔로우한 사람만 보기'), findsOneWidget);
    // 목록 위쪽은 지도라 끌면 지도가 움직여요. 목록을 끝까지 내려 봅니다.
    final list = tester.state<ScrollableState>(find.byType(Scrollable).first);
    list.position.jumpTo(list.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(find.text("반찬가게에서는 '한 팩'이라고 하면 돼요."), findsOneWidget);
    expect(find.text('Sokha'), findsOneWidget);

    // 로그인 없이 글쓰기를 누르면 로그인 안내
    await tester.tap(find.text('글쓰기'));
    await tester.pump();
    expect(find.text('로그인하면 글을 쓸 수 있어요'), findsOneWidget);
    // 안내(스낵바)를 닫아요. 다음 화면의 아래 버튼을 가리지 않게.
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
        .clearSnackBars();
    await tester.pumpAndSettle();

    await _tap(tester, '마이페이지');
    expect(find.text('내 기록'), findsNothing); // 제목은 '내 기록 · …' 한 줄
    expect(find.text('내 지도'), findsOneWidget);
    expect(find.text('내 쿠폰'), findsOneWidget);
    expect(find.text('커뮤니티에 쓴 글'), findsOneWidget);

    // 내 지도: 가게에서 말한 문장을 단계별로 복습할 수 있어요.
    await _tap(tester, '내 지도');
    expect(find.text('가 본 가게 1곳 · 말한 문장 1개'), findsOneWidget);
    await _tap(tester, '복습하기');
    expect(find.text('1단계 · 보여주기'), findsOneWidget);
    await _tap(tester, '다음 단계');
    expect(find.text('2단계 · 따라 말하기'), findsOneWidget);
    appRouter.go(AppRoutes.profile);
    await tester.pumpAndSettle();

    await _tap(tester, '복습');
    expect(find.text('오늘 복습할 문장 1개'), findsOneWidget);

    await tester.tap(find.text('1단계 · 그대로 말하기').first);
    await tester.pumpAndSettle();
    // 복습은 보여주기 → 따라 말하기 → 빈칸 말하기 → 혼자 말하기 순서로 열려요.
    expect(find.text('1단계 · 보여주기'), findsOneWidget);
  });
}
