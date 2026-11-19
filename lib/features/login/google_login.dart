import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import 'auth_api.dart';
import 'auth_session.dart';
import 'google_signup_screen.dart';
import '../onboarding/onboarding_screen.dart' show OnboardingResult;
import 'login_screen.dart';

/// 구글 OAuth 웹 클라이언트 ID (공개 값). `--dart-define=GOOGLE_WEB_CLIENT_ID=...`로 바꿀 수 있습니다.
/// 서버 .env의 GOOGLE_CLIENT_IDS에도 같은 값이 있어야 합니다.
const googleWebClientId = String.fromEnvironment(
  'GOOGLE_WEB_CLIENT_ID',
  defaultValue: '641098940061-behinoodbsfkd8rgjffao110mfnu0a7k.apps.googleusercontent.com',
);

/// 구글 버튼을 못 그릴 때(웹이 아님, 스크립트 로드 실패)의 안내.
/// 웹에서는 GoogleButton(google_button.dart)이 구글 공식 버튼을 그려 [handleGoogleIdToken]을 부릅니다.
Future<void> continueWithGoogle(BuildContext context) async {
  showMessage(context, '구글 로그인은 웹(Chrome)에서 할 수 있어요. 아이디로 로그인해 주세요.');
}

/// 구글에서 받은 id_token으로 서버에 로그인합니다.
/// 가입한 적이 있으면 바로 들어가고, 처음이면 닉네임·약관을 받는 구글 가입 화면으로 갑니다.
///
/// 처음 온 구글 계정은 온보딩(언어·나는 누구·식단·종교)부터 하고 구글 가입으로 가요.
/// 회원가입 화면에서 눌렀으면 이미 고른 [onboarding]을 그대로 써요.
Future<void> handleGoogleIdToken(
  BuildContext context,
  String idToken, {
  OnboardingResult? onboarding,
}) async {
  try {
    final json = await AuthApi.google(idToken);
    if (!context.mounted) return;
    if (json['signup_required'] == true) {
      final args = GoogleSignupArgs(
        idToken: idToken,
        email: json['email'] as String? ?? '',
        onboarding: onboarding,
      );
      context.push(
        onboarding == null ? AppRoutes.onboarding : AppRoutes.googleSignup,
        extra: args,
      );
      return;
    }
    final next = await AuthSession.save(json);
    if (context.mounted) context.go(next);
  } on AuthException catch (e) {
    if (context.mounted) showMessage(context, e.message);
  }
}
