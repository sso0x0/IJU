import 'package:go_router/go_router.dart';

import '../features/compose/compose_screen.dart';
import '../features/home/home_screen.dart';
import '../features/login/login_screen.dart';
import '../features/menu_scan/menu_scan_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/practice/practice_screen.dart';
import '../features/real_order/order_api.dart';
import '../features/real_order/real_order_screen.dart';
import '../features/reward/reward_screen.dart';
import '../features/scenario/scenarios.dart';

/// 시연 경로 순서대로 정리한 화면 주소.
abstract final class AppRoutes {
  static const login = '/';
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const menuScan = '/menu-scan'; // 개발자1
  static const compose = '/compose'; // 개발자2
  static const practice = '/practice'; // 개발자2
  static const realOrder = '/real-order'; // 개발자3
  static const reward = '/reward'; // 개발자3
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.login,
  routes: [
    GoRoute(
      path: AppRoutes.login,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.onboarding,
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: AppRoutes.menuScan,
      builder: (context, state) => const MenuScanScreen(),
    ),
    GoRoute(
      path: AppRoutes.compose,
      // ?scenario=restaurant 처럼 시나리오를 고릅니다 (없으면 정육점).
      builder: (context, state) => ComposeScreen(
        scenario: Scenario.byId(state.uri.queryParameters['scenario']),
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
  ],
);
