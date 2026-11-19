import 'package:go_router/go_router.dart';

import '../features/compose/compose_screen.dart';
import '../features/home/home_screen.dart';
import '../features/login/login_screen.dart';
import '../features/menu_scan/menu_scan_screen.dart';
import '../features/missions/missions_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/practice/practice_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/real_order/real_order_screen.dart';
import '../features/review/review_screen.dart';
import '../features/reward/reward_screen.dart';
import '../features/scenario/scenarios.dart';

/// 시연 경로 순서대로 정리한 화면 주소.
abstract final class AppRoutes {
  static const login = '/';
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const missions = '/missions'; // 하단 탭
  static const review = '/review'; // 하단 탭
  static const profile = '/profile'; // 하단 탭
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
    // 하단 탭 4개는 탭끼리 오갈 때 넘김 애니메이션 없이 바꿉니다.
    GoRoute(
      path: AppRoutes.home,
      pageBuilder: (context, state) =>
          const NoTransitionPage(child: HomeScreen()),
    ),
    GoRoute(
      path: AppRoutes.missions,
      pageBuilder: (context, state) =>
          const NoTransitionPage(child: MissionsScreen()),
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
      builder: (context, state) => const RealOrderScreen(),
    ),
    GoRoute(
      path: AppRoutes.reward,
      builder: (context, state) => const RewardScreen(),
    ),
  ],
);
