import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/colors.dart';
import '../../app/router.dart';
import '../../widgets/consent_box.dart';
import '../../widgets/iju_button.dart';
import '../../widgets/iju_header.dart';
import '../../widgets/iju_text_field.dart';
import '../../widgets/section_label.dart';
import 'auth_api.dart';
import 'auth_session.dart';
import 'login_screen.dart';

/// 구글 가입 화면으로 넘기는 값 (구글 id_token과 이메일).
class GoogleSignupArgs {
  const GoogleSignupArgs({required this.idToken, required this.email});

  final String idToken;
  final String email;
}

/// 구글 계정으로 처음 왔을 때 닉네임·약관을 받습니다 (청온 GoogleSignupActivity). 담당: 개발자1
class GoogleSignupScreen extends StatefulWidget {
  const GoogleSignupScreen({super.key, required this.args});

  final GoogleSignupArgs? args;

  @override
  State<GoogleSignupScreen> createState() => _GoogleSignupScreenState();
}

class _GoogleSignupScreenState extends State<GoogleSignupScreen> {
  static final _nicknameRule = RegExp(r'^[가-힣a-zA-Z0-9_]{2,20}$');

  final _nickname = TextEditingController();
  final _consent = ConsentController();
  String? _nicknameError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _consent.addListener(_refresh);
    // 구글 토큰 없이 들어오면 (주소 직접 입력 등) 로그인 화면으로 돌려보냅니다.
    if (widget.args == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(AppRoutes.login);
      });
    }
  }

  @override
  void dispose() {
    _nickname.dispose();
    _consent.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _complete() async {
    final args = widget.args;
    if (args == null || !_consent.accepted || _busy) return;
    final name = _nickname.text.trim();
    if (!_nicknameRule.hasMatch(name)) {
      setState(() => _nicknameError = '한글, 영문, 숫자, 밑줄 2~20자로 입력해 주세요.');
      return;
    }

    setState(() {
      _busy = true;
      _nicknameError = null;
    });
    try {
      final json = await AuthApi.googleSignup({
        'id_token': args.idToken,
        'name': name,
        ..._consent.toJson(),
      });
      final next = await AuthSession.save(json);
      if (mounted) context.go(next);
    } on AuthException catch (e) {
      if (!mounted) return;
      switch (e.code) {
        case 'NICKNAME_TAKEN' || 'INVALID_NICKNAME':
          setState(() => _nicknameError = e.message);
        case 'TERMS_CHANGED':
          _consent.reload();
          showMessage(context, e.message);
        default:
          showMessage(context, e.message);
          // 구글 토큰이 만료됐으면 로그인부터 다시
          if (e.status == 401) context.go(AppRoutes.login);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _consent.accepted && !_busy;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const IjuHeader(title: '구글로 가입', subtitle: 'Đăng ký bằng Google'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                children: [
                  const SectionLabel('구글 계정', sub: 'Google'),
                  const SizedBox(height: 8),
                  Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      widget.args?.email ?? '',
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.textBody,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const SectionLabel('닉네임', sub: 'Biệt danh'),
                  const SizedBox(height: 8),
                  IjuTextField(
                    controller: _nickname,
                    hintText: '한글·영문·숫자 2~20자',
                    errorText: _nicknameError,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) {
                      if (_nicknameError != null) {
                        setState(() => _nicknameError = null);
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  ConsentBox(controller: _consent, enabled: !_busy),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: Opacity(
                opacity: canSubmit ? 1 : 0.45,
                child: IjuButton(
                  label: _busy ? '가입 중…' : '가입 완료',
                  onPressed: canSubmit ? _complete : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
