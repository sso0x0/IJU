import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/colors.dart';
import '../../app/languages.dart';
import '../../app/theme.dart';
import '../../app/router.dart';
import '../../widgets/iju_button.dart';
import '../../widgets/iju_text_field.dart';
import '../../widgets/section_label.dart';
import 'auth_api.dart';
import 'auth_session.dart';
import 'google_button.dart';
import 'google_login.dart';
import '../../widgets/brand_mark.dart';

/// 로그인 (청온 LoginActivity). 아이디 + 비밀번호, 구글 로그인. 담당: 개발자1
/// 자동 로그인(저장된 토큰 확인)은 스플래시에서 합니다.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _id = TextEditingController();
  final _password = TextEditingController();
  String? _idError;
  String? _passwordError;
  bool _busy = false;

  @override
  void dispose() {
    _id.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final id = _id.text.trim();
    final password = _password.text;
    setState(() {
      _idError = id.isEmpty ? '아이디를 입력해 주세요.' : null;
      _passwordError = password.isEmpty ? '비밀번호를 입력해 주세요.' : null;
    });
    if (_idError != null || _passwordError != null || _busy) return;

    setState(() => _busy = true);
    try {
      final next = await AuthSession.save(await AuthApi.login(id, password));
      if (mounted) context.go(next);
    } on AuthException catch (e) {
      if (mounted) showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              sliver: SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const BrandMark(),
                    const SizedBox(height: 36),
                    const Text('다시 만나서 반가워요', style: AppText.title),
                    const SizedBox(height: 4),
                    Text(
                      nt('Rất vui được gặp lại bạn'),
                      style: AppText.native.copyWith(color: AppColors.textSub),
                    ),
                    const SizedBox(height: 28),
                    SectionLabel('아이디', sub: nt('Tên đăng nhập')),
                    const SizedBox(height: 8),
                    IjuTextField(
                      controller: _id,
                      hintText: 'nguyen01',
                      errorText: _idError,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 20),
                    SectionLabel('비밀번호', sub: nt('Mật khẩu')),
                    const SizedBox(height: 8),
                    IjuTextField(
                      controller: _password,
                      obscureText: true,
                      errorText: _passwordError,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _login(),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IjuTextLink(
                        label: '비밀번호를 잊었어요',
                        fontSize: 14,
                        onTap: () => context.push(AppRoutes.findPassword),
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: 28),
                    IjuButton(
                      label: _busy ? '로그인 중…' : '로그인 · ${nt('Đăng nhập')}',
                      onPressed: _busy ? null : _login,
                    ),
                    const SizedBox(height: 10),
                    GoogleButton(
                      label: 'Google로 계속하기',
                      onIdToken: (token) => handleGoogleIdToken(context, token),
                    ),
                    const SizedBox(height: 16),
                    // 처음 온 사람: 온보딩(언어·나는 누구·식단·종교) → 회원가입
                    Center(
                      child: IjuTextLink(
                        label: '처음이에요 · ${nt('Đăng ký')}',
                        fontSize: 17,
                        bold: true,
                        onTap: () => context.push(AppRoutes.onboarding),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 화면 아래에 짧은 안내 (청온 Snackbar).
void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
