import 'package:go_router/go_router.dart';

import '../features/home/home_screen.dart';
import '../features/menu_scan/menu_scan_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/placeholder/placeholder_screen.dart';

/// 시연 경로 순서대로 정리한 화면 주소.
abstract final class AppRoutes {
  static const onboarding = '/';
  static const home = '/home';
  static const menuScan = '/menu-scan'; // 개발자1
  static const compose = '/compose'; // 개발자2
  static const practice = '/practice'; // 개발자2
  static const realOrder = '/real-order'; // 개발자3
  static const reward = '/reward'; // 개발자3
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.onboarding,
  routes: [
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
    // 아래 화면은 담당자가 각자 features/<기능>/ 폴더에 만들어 교체합니다.
    GoRoute(
      path: AppRoutes.compose,
      builder: (context, state) => const PlaceholderScreen(
        title: '문장 만들기',
        owner: '개발자2',
        nextLabel: '음성 연습으로',
        nextRoute: AppRoutes.practice,
      ),
    ),
    GoRoute(
      path: AppRoutes.practice,
      builder: (context, state) => const PlaceholderScreen(
        title: 'AI 사장님과 연습',
        owner: '개발자2',
        nextLabel: '실전으로 가기',
        nextRoute: AppRoutes.realOrder,
      ),
    ),
    GoRoute(
      path: AppRoutes.realOrder,
      builder: (context, state) => const PlaceholderScreen(
        title: '실전 주문',
        owner: '개발자3',
        nextLabel: '영수증 인증하기',
        nextRoute: AppRoutes.reward,
      ),
    ),
    GoRoute(
      path: AppRoutes.reward,
      builder: (context, state) => const PlaceholderScreen(
        title: '영수증 인증 · 보상',
        owner: '개발자3',
        nextLabel: '홈으로',
        nextRoute: AppRoutes.home,
      ),
    ),
  ],
);
