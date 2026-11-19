import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:material_ui/material_ui.dart';
import 'package:web/web.dart' as web;

import '../../app/theme.dart';
import 'google_look_button.dart';
import 'google_login.dart';

@JS('ijuGoogle.renderButton')
external void _renderButton(
  web.HTMLElement element,
  String clientId,
  String text,
  JSFunction onToken,
  JSFunction onError,
);

/// 웹: 구글 공식 로그인 버튼(web/google_login.js)을 그립니다.
/// 누르면 구글 창이 뜨고, 로그인하면 id_token이 [onIdToken]으로 옵니다.
/// 스크립트를 못 불러오면 일반 버튼으로 바뀌어 안내만 합니다.
class GoogleButton extends StatefulWidget {
  const GoogleButton({
    super.key,
    required this.label,
    required this.onIdToken,
    this.signup = false,
  });

  /// 구글 버튼을 못 그릴 때 쓰는 글자
  final String label;
  final void Function(String idToken) onIdToken;

  /// true면 '…로 가입하기' 문구
  final bool signup;

  @override
  State<GoogleButton> createState() => _GoogleButtonState();
}

class _GoogleButtonState extends State<GoogleButton> {
  static int _seq = 0;

  late final String _viewType = 'iju-google-button-${_seq++}';
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (googleWebClientId.isEmpty) return;
    void onError() {
      if (mounted) setState(() => _failed = true);
    }

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      // 구글 공식 버튼(높이 40)은 크기를 못 바꿔서, 앱 버튼 모양 위에 거의 투명하게 올리고
      // 세로로 늘려 버튼 전체가 눌리게 합니다. 눌리는 건 구글 버튼이에요.
      final div = web.HTMLDivElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.display = 'flex'
        ..style.alignItems = 'center'
        ..style.justifyContent = 'center'
        ..style.opacity = '0.01'
        ..style.transform = 'scaleY(1.4)';
      _renderButton(
        div,
        googleWebClientId,
        widget.signup ? 'signup_with' : 'continue_with',
        ((JSString token) => widget.onIdToken(token.toDart)).toJS,
        onError.toJS,
      );
      return div;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (googleWebClientId.isEmpty || _failed) {
      return GoogleLookButton(
        label: widget.label,
        onTap: () => continueWithGoogle(context),
      );
    }
    return SizedBox(
      height: AppSpace.buttonHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(child: GoogleLookButton(label: widget.label)),
          HtmlElementView(viewType: _viewType),
        ],
      ),
    );
  }
}
