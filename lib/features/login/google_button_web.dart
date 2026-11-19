import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:material_ui/material_ui.dart';
import 'package:web/web.dart' as web;

import '../../widgets/iju_button.dart';
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
      final div = web.HTMLDivElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.display = 'flex'
        ..style.alignItems = 'center'
        ..style.justifyContent = 'center';
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
      return IjuButton(
        label: widget.label,
        type: IjuButtonType.secondary,
        onPressed: () => continueWithGoogle(context),
      );
    }
    return SizedBox(height: 56, child: HtmlElementView(viewType: _viewType));
  }
}
