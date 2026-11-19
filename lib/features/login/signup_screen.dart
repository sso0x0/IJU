import 'package:go_router/go_router.dart';

import '../../app/languages.dart';

import 'package:material_ui/material_ui.dart';

import '../../app/colors.dart';
import '../../widgets/consent_box.dart';
import '../../widgets/iju_button.dart';
import '../../widgets/iju_header.dart';
import '../../widgets/iju_text_field.dart';
import '../../widgets/section_label.dart';
import 'auth_api.dart';
import 'auth_session.dart';
import 'google_button.dart';
import 'google_login.dart';
import '../onboarding/onboarding_screen.dart' show OnboardingResult;
import 'login_screen.dart';

/// 회원가입 (청온 SignupActivity). 담당: 개발자1
///
/// 아이디·이메일은 칸을 벗어나면 자동으로 중복 확인하고, 글자가 바뀌면 확인 결과를 지웁니다.
/// 약관 두 개에 모두 동의해야 [가입하기]가 켜집니다. 가입하면 바로 로그인돼 온보딩으로 갑니다.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key, this.onboarding});

  /// 온보딩에서 고른 값 (언어·나는 누구·닉네임·식단). 가입할 때 같이 보내요.
  final OnboardingResult? onboarding;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _id = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordCheck = TextEditingController();
  final _idFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _consent = ConsentController();

  bool _idChecked = false;
  bool _emailChecked = false;
  String? _idError;
  String? _emailError;
  String? _passwordError;
  String? _passwordCheckError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _idFocus.addListener(() {
      if (!_idFocus.hasFocus) _checkId();
    });
    _emailFocus.addListener(() {
      if (!_emailFocus.hasFocus) _checkEmail();
    });
    _consent.addListener(_refresh);
  }

  @override
  void dispose() {
    for (final c in [_id, _email, _password, _passwordCheck]) {
      c.dispose();
    }
    _idFocus.dispose();
    _emailFocus.dispose();
    _consent.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _checkId() async {
    final id = _id.text.trim();
    if (id.isEmpty) return;
    try {
      await AuthApi.checkId(id);
      if (!mounted || id != _id.text.trim()) return;
      setState(() {
        _idChecked = true;
        _idError = null;
      });
    } on AuthException catch (e) {
      if (!mounted || id != _id.text.trim()) return;
      setState(() {
        _idChecked = false;
        _idError = e.message;
      });
    }
  }

  Future<void> _checkEmail() async {
    final email = _email.text.trim();
    if (email.isEmpty) return;
    try {
      await AuthApi.checkEmail(email);
      if (!mounted || email != _email.text.trim()) return;
      setState(() {
        _emailChecked = true;
        _emailError = null;
      });
    } on AuthException catch (e) {
      if (!mounted || email != _email.text.trim()) return;
      setState(() {
        _emailChecked = false;
        _emailError = e.message;
      });
    }
  }

  Future<void> _signup() async {
    if (!_consent.accepted || _busy) return;
    final id = _id.text.trim();
    final email = _email.text.trim();
    final password = _password.text;

    // 칸을 벗어나지 않고 바로 누른 경우를 위해 한 번 더 확인합니다.
    if (!_idChecked) await _checkId();
    if (!_emailChecked) await _checkEmail();
    if (!mounted) return;
    setState(() {
      if (id.isEmpty) _idError = '아이디를 입력해 주세요.';
      if (email.isEmpty) _emailError = '이메일을 입력해 주세요.';
      _passwordError = password.length < 8 ? '비밀번호는 8자 이상으로 입력해 주세요.' : null;
      _passwordCheckError = _passwordCheck.text != password
          ? '비밀번호가 일치하지 않아요.'
          : null;
    });
    if (!_idChecked ||
        !_emailChecked ||
        _passwordError != null ||
        _passwordCheckError != null) {
      showMessage(context, '빨간 칸을 확인해 주세요.');
      return;
    }

    setState(() => _busy = true);
    try {
      final json = await AuthApi.signup({
        'login_id': id,
        'email': email,
        'password': password,
        ...?widget.onboarding?.toJson(),
        ..._consent.toJson(),
      });
      final next = await AuthSession.save(json);
      if (mounted) context.go(next);
    } on AuthException catch (e) {
      if (!mounted) return;
      switch (e.code) {
        case 'ID_TAKEN' || 'INVALID_ID':
          setState(() {
            _idChecked = false;
            _idError = e.message;
          });
        case 'EMAIL_TAKEN' || 'INVALID_EMAIL':
          setState(() {
            _emailChecked = false;
            _emailError = e.message;
          });
        case 'WEAK_PASSWORD':
          setState(() => _passwordError = e.message);
        case 'TERMS_CHANGED':
          _consent.reload();
          showMessage(context, e.message);
        default:
          showMessage(context, e.message);
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
            IjuHeader(title: '회원가입', subtitle: nt('Đăng ký')),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                children: [
                  SectionLabel('아이디', sub: nt('Tên đăng nhập')),
                  const SizedBox(height: 8),
                  IjuTextField(
                    controller: _id,
                    focusNode: _idFocus,
                    hintText: '영문·숫자 4~20자',
                    errorText: _idError,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {
                      _idChecked = false;
                      _idError = null;
                    }),
                  ),
                  if (_idChecked) const _Ok('사용할 수 있는 아이디예요.'),
                  const SizedBox(height: 20),
                  const SectionLabel('이메일', sub: 'Email'),
                  const SizedBox(height: 8),
                  IjuTextField(
                    controller: _email,
                    focusNode: _emailFocus,
                    hintText: 'nguyen@example.com',
                    errorText: _emailError,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {
                      _emailChecked = false;
                      _emailError = null;
                    }),
                  ),
                  if (_emailChecked) const _Ok('사용할 수 있는 이메일이에요.'),
                  const SizedBox(height: 20),
                  SectionLabel('비밀번호', sub: nt('Mật khẩu')),
                  const SizedBox(height: 8),
                  IjuTextField(
                    controller: _password,
                    hintText: '8자 이상',
                    obscureText: true,
                    errorText: _passwordError,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 20),
                  SectionLabel('비밀번호 확인', sub: nt('Nhập lại mật khẩu')),
                  const SizedBox(height: 8),
                  IjuTextField(
                    controller: _passwordCheck,
                    obscureText: true,
                    errorText: _passwordCheckError,
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 24),
                  ConsentBox(controller: _consent, enabled: !_busy),
                  const SizedBox(height: 8),
                  const PrivacyNote(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Opacity(
                    opacity: canSubmit ? 1 : 0.45,
                    child: IjuButton(
                      label: _busy ? '가입 중…' : '가입하기 · ${nt('Đăng ký')}',
                      onPressed: canSubmit ? _signup : null,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GoogleButton(
                    label: 'Google로 가입',
                    signup: true,
                    onIdToken: (token) => handleGoogleIdToken(
                      context,
                      token,
                      onboarding: widget.onboarding,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 칸 아래 초록 확인 문구.
class _Ok extends StatelessWidget {
  const _Ok(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, color: AppColors.primaryDark),
      ),
    );
  }
}
