import 'package:go_router/go_router.dart';

import '../features/compose/compose_screen.dart';
import '../features/home/home_screen.dart';
import '../features/login/login_screen.dart';
import '../features/menu_scan/menu_scan_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/practice/practice_screen.dart';
import '../features/real_order/real_order_screen.dart';
import '../features/reward/reward_screen.dart';

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
      builder: (context, state) => const ComposeScreen(),
    ),
    GoRoute(
      path: AppRoutes.practice,
      builder: (context, state) => const PracticeScreen(),
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
