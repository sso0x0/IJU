import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:material_ui/material_ui.dart';

import 'google_look_button.dart';
import 'google_login.dart';
import 'login_screen.dart' show showMessage;

/// 웹이 아닐 때의 구글 로그인 버튼 (웹은 google_button_web.dart).
///
/// Android: 기기의 구글 계정 선택 창(Credential Manager)을 띄워 id_token을 받습니다.
/// [googleWebClientId]를 serverClientId로 넘겨서, 서버(GOOGLE_CLIENT_IDS)가 웹과 같은 ID로
/// 확인할 수 있는 토큰이 와요. 구글 콘솔에 Android 클라이언트(패키지 이름 + SHA-1)도 있어야 합니다.
/// iOS·테스트 등 그 밖의 환경은 안내만 합니다.
class GoogleButton extends StatefulWidget {
  const GoogleButton({
    super.key,
    required this.label,
    required this.onIdToken,
    this.signup = false,
  });

  final String label;
  final void Function(String idToken) onIdToken;
  final bool signup;

  @override
  State<GoogleButton> createState() => _GoogleButtonState();
}

class _GoogleButtonState extends State<GoogleButton> {
  static Future<void>? _init;
  bool _busy = false;

  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _signIn() async {
    if (!_supported || googleWebClientId.isEmpty) {
      await continueWithGoogle(context);
      return;
    }
    setState(() => _busy = true);
    try {
      final google = GoogleSignIn.instance;
      try {
        await (_init ??= google.initialize(serverClientId: googleWebClientId));
      } catch (_) {
        _init = null; // 실패한 초기화는 버리고 다음에 누를 때 다시 해요.
        rethrow;
      }
      final account = await google.authenticate();
      final token = account.authentication.idToken;
      if (token == null) throw StateError('no id_token');
      widget.onIdToken(token);
    } on GoogleSignInException catch (e) {
      if (e.code != GoogleSignInExceptionCode.canceled && mounted) {
        showMessage(context, '구글 로그인에 실패했어요. 잠시 후 다시 시도해 주세요.');
      }
    } catch (_) {
      if (mounted) {
        showMessage(context, '구글 로그인에 실패했어요. 잠시 후 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GoogleLookButton(label: widget.label, onTap: _busy ? null : _signIn);
  }
}
