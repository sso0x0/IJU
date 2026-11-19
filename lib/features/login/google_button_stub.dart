import 'package:material_ui/material_ui.dart';

import 'google_look_button.dart';
import 'google_login.dart';

/// 웹이 아닐 때(테스트·Android·iOS): 일반 버튼. 누르면 안내만 합니다.
/// 구글 로그인은 웹(google_button_web.dart)에서 동작합니다.
class GoogleButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return GoogleLookButton(
      label: label,
      onTap: () => continueWithGoogle(context),
    );
  }
}
