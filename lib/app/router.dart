import 'package:go_router/go_router.dart';

import '../features/community/community_screen.dart';
import '../features/compose/compose_screen.dart';
import '../features/home/home_screen.dart';
import '../features/login/find_password_screen.dart';
import '../features/login/google_signup_screen.dart';
import '../features/login/login_screen.dart';
import '../features/login/signup_screen.dart';
import '../features/menu_scan/menu_scan_api.dart';
import '../features/menu_scan/menu_scan_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/onboarding/splash_screen.dart';
import '../features/order_map/order_map_screen.dart';
import '../features/order_map/order_place_screen.dart';
import '../features/order_map/order_place_store.dart';
import '../features/practice/practice_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/real_order/order_api.dart';
import '../features/real_order/real_order_screen.dart';
import '../features/review/review_screen.dart';
import '../features/review/review_steps_screen.dart';
import '../features/reward/reward_screen.dart';
import '../features/scenario/scenarios.dart';

/// 시연 경로 순서대로 정리한 화면 주소.
abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/';
  static const signup = '/signup'; // 개발자1
  static const googleSignup = '/signup/google'; // 개발자1
  static const findPassword = '/find-password'; // 개발자1
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const community = '/community'; // 하단 탭
  static const review = '/review'; // 하단 탭
  static const reviewSteps = '/review/steps'; // 복습 단계 (보여주기 → 혼자 말하기)
  static const profile = '/profile'; // 하단 탭
  static const menuScan = '/menu-scan'; // 개발자1
  static const compose = '/compose'; // 개발자2
  static const practice = '/practice'; // 개발자2
  static const realOrder = '/real-order'; // 개발자3
  static const reward = '/reward'; // 개발자3
  static const orderMap = '/order-map'; // 개발자1 (복습 탭에서 들어감)
  static const orderPlace = '/order-map/place'; // 개발자1
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  routes: [
    GoRoute(
      path: AppRoutes.login,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.signup,
      // 온보딩에서 고른 값(OnboardingResult)을 extra로 받아 가입할 때 같이 저장해요.
      builder: (context, state) =>
          SignupScreen(onboarding: state.extra as OnboardingResult?),
    ),
    GoRoute(
      path: AppRoutes.googleSignup,
      // 구글 id_token과 이메일을 extra로 받습니다. 없으면 로그인 화면으로 돌아갑니다.
      builder: (context, state) =>
          GoogleSignupScreen(args: state.extra as GoogleSignupArgs?),
    ),
    GoRoute(
      path: AppRoutes.findPassword,
      builder: (context, state) => const FindPasswordScreen(),
    ),
    GoRoute(
      path: AppRoutes.onboarding,
      // 처음 온 구글 계정이면 extra로 구글 가입 정보를 받아요.
      builder: (context, state) =>
          OnboardingScreen(googleArgs: state.extra as GoogleSignupArgs?),
    ),
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    // 하단 탭 4개는 탭끼리 오갈 때 넘김 애니메이션 없이 바꿉니다.
    GoRoute(
      path: AppRoutes.home,
      pageBuilder: (context, state) =>
          const NoTransitionPage(child: HomeScreen()),
    ),
    GoRoute(
      path: AppRoutes.reviewSteps,
      builder: (context, state) =>
          ReviewStepsScreen(args: state.extra! as ReviewStepsArgs),
    ),
    GoRoute(
      path: AppRoutes.community,
      pageBuilder: (context, state) =>
          const NoTransitionPage(child: CommunityScreen()),
    ),
    GoRoute(
      path: AppRoutes.review,
      pageBuilder: (context, state) =>
          const NoTransitionPage(child: ReviewScreen()),
    ),
    GoRoute(
      path: AppRoutes.profile,
      pageBuilder: (context, state) =>
          const NoTransitionPage(child: ProfileScreen()),
    ),
    GoRoute(
      path: AppRoutes.menuScan,
      // ?scenario=restaurant 처럼 고른 메뉴로 어떤 가게 문장을 만들지 고릅니다 (없으면 식당).
      // &example=1이면 예시 메뉴판 결과부터 보여 줍니다 (가게에 가기 전 연습).
      builder: (context, state) => MenuScanScreen(
        scenario: Scenario.byId(state.uri.queryParameters['scenario']),
        example: state.uri.queryParameters['example'] == '1',
      ),
    ),
    GoRoute(
      path: AppRoutes.compose,
      // ?scenario=restaurant 처럼 시나리오를 고릅니다 (없으면 식당).
      // 메뉴판 인식에서 고른 메뉴는 extra(List<MenuCardData>)로 받습니다.
      builder: (context, state) => ComposeScreen(
        scenario: Scenario.byId(state.uri.queryParameters['scenario']),
        menus: state.extra as List<MenuCardData>? ?? const [],
      ),
    ),
    GoRoute(
      path: AppRoutes.practice,
      // 문장 조립 화면에서 만든 문장을 extra로 받습니다. 없으면 시연 문장.
      builder: (context, state) => PracticeScreen(
        args: state.extra as PracticeArgs? ?? PracticeArgs.demo,
      ),
    ),
    GoRoute(
      path: AppRoutes.realOrder,
      // 음성 연습 화면에서 문장·미션 id를 extra로 받습니다. 없으면 시연 문장.
      builder: (context, state) => RealOrderScreen(
        args: state.extra as RealOrderArgs? ?? RealOrderArgs.demo,
      ),
    ),
    GoRoute(
      path: AppRoutes.reward,
      // 영수증 인증 결과를 extra로 받습니다. 없으면 시연용 고정 데이터.
      builder: (context, state) =>
          RewardScreen(args: state.extra as RewardArgs?),
    ),
    GoRoute(
      path: AppRoutes.orderMap,
      builder: (context, state) => const OrderMapScreen(),
    ),
    GoRoute(
      path: AppRoutes.orderPlace,
      // 지도·목록에서 고른 가게를 extra로 받습니다. 없으면 시연 가게.
      builder: (context, state) => OrderPlaceScreen(
        place: state.extra as OrderPlace? ?? OrderPlace.demo,
      ),
    ),
  ],
);
