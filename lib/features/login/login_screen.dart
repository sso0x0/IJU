import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/colors.dart';
import '../../app/router.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/iju_button.dart';
import '../../widgets/iju_text_field.dart';
import '../../widgets/section_label.dart';
import 'auth_api.dart';
import 'auth_session.dart';
import 'google_button.dart';
import 'google_login.dart';

/// 로그인 (청온 LoginActivity). 아이디 + 비밀번호, 구글 로그인. 담당: 개발자1
/// 저장된 토큰이 있으면 GET /auth/me로 확인하고 바로 들어갑니다 (자동 로그인).
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
  void initState() {
    super.initState();
    _autoLogin();
  }

  @override
  void dispose() {
    _id.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _autoLogin() async {
    final next = await AuthSession.restore();
    if (next != null && mounted) context.go(next);
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
    final l10n = AppLocalizations.of(context);

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
                    Text(
                      l10n.appName,
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.appTagline,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.textBody,
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      '다시 오셨네요!',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Chào mừng bạn quay lại',
                      style: TextStyle(fontSize: 14, color: AppColors.textSub),
                    ),
                    const SizedBox(height: 28),
                    const SectionLabel('아이디', sub: 'Tên đăng nhập'),
                    const SizedBox(height: 8),
                    IjuTextField(
                      controller: _id,
                      hintText: 'nguyen01',
                      errorText: _idError,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 20),
                    const SectionLabel('비밀번호', sub: 'Mật khẩu'),
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
                        fontSize: 13,
                        onTap: () => context.push(AppRoutes.findPassword),
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: 28),
                    IjuButton(
                      label: _busy ? '로그인 중…' : '로그인 · Đăng nhập',
                      onPressed: _busy ? null : _login,
                    ),
                    const SizedBox(height: 10),
                    GoogleButton(
                      label: 'Google로 계속하기',
                      onIdToken: (token) => handleGoogleIdToken(context, token),
                    ),
                    const SizedBox(height: 10),
                    IjuButton(
                      label: '처음이에요 · Đăng ký',
                      type: IjuButtonType.secondary,
                      onPressed: () => context.push(AppRoutes.signup),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: IjuTextLink(
                        label: '로그인 없이 둘러보기',
                        // 시연용: 로그인하지 않으면 시연 사용자로 기록됩니다.
                        onTap: () => context.go(AppRoutes.home),
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
