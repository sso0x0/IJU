import 'package:go_router/go_router.dart';

import '../features/home/home_screen.dart';

abstract final class AppRoutes {
  static const home = '/';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const HomeScreen(),
    ),
  ],
);
