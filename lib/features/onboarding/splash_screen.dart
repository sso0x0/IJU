import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/colors.dart';
import '../../app/languages.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../login/auth_session.dart';

/// A1 스플래시. 로고를 잠깐 보여 주는 동안 저장된 로그인을 확인하고(자동 로그인),
/// 로그인돼 있으면 홈, 아니면 로그인 화면으로 갑니다. 담당: 개발자1
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  /// 로고를 보여 주는 최소 시간.
  static const minimum = Duration(milliseconds: 1200);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final (next, _) = await (
      AuthSession.restore(),
      Future<void>.delayed(SplashScreen.minimum),
    ).wait;
    if (mounted) context.go(next ?? AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 3),
            Image.asset('assets/brand/logo.png', width: 132),
            const SizedBox(height: 28),
            const Text(
              '이거 주세요',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '“${nt('Cho tôi cái này')}”',
              style: AppText.native.copyWith(
                fontSize: 16,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              '동네 가게에서 배우는 생활 한국어',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textBody,
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                nt('Học tiếng Hàn đời sống ở cửa hàng khu phố'),
                textAlign: TextAlign.center,
                style: AppText.native.copyWith(
                  fontSize: 14,
                  color: AppColors.textSub,
                ),
              ),
            ),
            const Spacer(flex: 4),
            const _Dots(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

/// 아래 점 세 개 (차례로 진해져요).
class _Dots extends StatefulWidget {
  const _Dots();

  @override
  State<_Dots> createState() => _DotsState();
}

class _DotsState extends State<_Dots> {
  int _on = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(milliseconds: 400),
      (_) => setState(() => _on = (_on + 1) % 3),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 3; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == _on ? AppColors.primary : AppColors.primary200,
            ),
          ),
      ],
    );
  }
}
