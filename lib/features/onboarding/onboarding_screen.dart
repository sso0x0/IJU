import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/colors.dart';
import '../../app/diet.dart';
import '../../app/router.dart';
import '../../app/session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/diet_picker.dart';
import '../../widgets/iju_button.dart';
import '../../widgets/iju_text_field.dart';
import '../../widgets/option_tile.dart';
import '../../widgets/section_label.dart';
import '../login/auth_api.dart';
import '../login/auth_session.dart';

/// Figma '1 온보딩'. 처음 온 사용자가 모국어와 닉네임을 정합니다. 담당: 개발자1
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _Language {
  const _Language(this.code, this.label);
  final String code; // 서버 POST /users의 language 값
  final String label;
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _languages = [
    _Language('vi', 'Tiếng Việt'),
    _Language('en', 'English'),
    _Language('fil', 'Filipino'),
    _Language('km', 'ភាសាខ្មែរ'),
  ];

  String _language = 'vi';
  Set<Diet> _diets = AppSession.diets.value;
  final _nickname = TextEditingController(text: AppSession.nickname);
  String? _nicknameError;
  bool _busy = false;

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_busy) return;
    // 로그인했으면 모국어·닉네임을 계정에 저장합니다 (PATCH /auth/me).
    if (AppSession.loggedIn) {
      final nickname = _nickname.text.trim();
      setState(() => _busy = true);
      try {
        final user = await AuthApi.updateMe({
          'language': _language,
          if (nickname.isNotEmpty && nickname != AppSession.nickname)
            'nickname': nickname,
        });
        await AuthSession.update(user);
      } on AuthException catch (e) {
        if (!mounted) return;
        setState(() => _busy = false);
        if (!e.offline) {
          setState(() => _nicknameError = e.message);
          return;
        }
        // 서버가 꺼져 있으면 저장 없이 진행 (시연이 끊기지 않게)
      }
      if (!mounted) return;
    }
    AppSession.language = _language; // 번역·서버 호출에 쓰는 학습자 언어
    AppSession.diets.value = _diets;
    context.go(AppRoutes.home);
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
                    const SizedBox(height: 28),
                    const SectionLabel('모국어를 골라 주세요', sub: 'Chọn ngôn ngữ'),
                    const SizedBox(height: 12),
                    _languageGrid(),
                    const SizedBox(height: 28),
                    const SectionLabel('닉네임'),
                    const SizedBox(height: 8),
                    IjuTextField(
                      controller: _nickname,
                      hintText: 'Nguyen',
                      errorText: _nicknameError,
                    ),
                    const SizedBox(height: 8),
                    const PrivacyNote(),
                    const SizedBox(height: 28),
                    const SectionLabel(
                      '못 먹는 음식이 있나요? (선택)',
                      sub: 'Ăn kiêng · tôn giáo',
                    ),
                    const SizedBox(height: 12),
                    DietPicker(
                      value: _diets,
                      onChanged: (v) => setState(() => _diets = v),
                    ),
                    const Spacer(),
                    const SizedBox(height: 28),
                    IjuButton(label: '시작하기 · Bắt đầu', onPressed: _start),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _languageGrid() {
    Widget tile(_Language lang) {
      final selected = _language == lang.code;
      return Expanded(
        child: OptionTile(
          selected: selected,
          onTap: () => setState(() {
            _language = lang.code;
            // 아래 식단 칩의 ⓘ 설명도 고른 언어로 보이게 합니다.
            AppSession.language = lang.code;
          }),
          child: Center(
            child: Text(
              lang.label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? Colors.white : AppColors.text,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            tile(_languages[0]),
            const SizedBox(width: 10),
            tile(_languages[1]),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            tile(_languages[2]),
            const SizedBox(width: 10),
            tile(_languages[3]),
          ],
        ),
      ],
    );
  }
}
