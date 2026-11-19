import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/colors.dart';
import '../../app/router.dart';
import '../../app/session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/iju_button.dart';
import '../../widgets/iju_chip.dart';
import '../../widgets/option_tile.dart';

/// Figma '1 온보딩'. 담당: 개발자1
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

  // 서버 residence_type 값 → 화면 라벨
  static const _residenceTypes = {
    'seasonal_worker': '계절근로자',
    'marriage': '결혼이민자',
    'worker': '기타 근로자',
  };

  String _language = 'vi';
  String _residenceType = 'seasonal_worker';
  final _nickname = TextEditingController();

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  void _start() {
    // TODO(개발자1): POST /users 호출 후 user_id 저장
    AppSession.language = _language;
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
                    // 로고
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

                    // 모국어
                    const _SectionLabel('모국어를 골라 주세요', sub: 'Chọn ngôn ngữ'),
                    const SizedBox(height: 12),
                    _languageGrid(),
                    const SizedBox(height: 28),

                    // 체류 유형
                    const _SectionLabel('어떻게 지내고 계세요?'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final e in _residenceTypes.entries)
                          IjuChip(
                            label: e.value,
                            selected: _residenceType == e.key,
                            onTap: () => setState(() => _residenceType = e.key),
                          ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // 닉네임
                    const _SectionLabel('닉네임'),
                    const SizedBox(height: 8),
                    _NicknameField(controller: _nickname),
                    const SizedBox(height: 8),
                    const Text(
                      '실명, 연락처, 체류 정보는 받지 않아요.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSub),
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
          onTap: () => setState(() => _language = lang.code),
          child: Center(
            child: Text(
              lang.label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? AppColors.primaryDark : AppColors.text,
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.sub});

  final String text;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
        children: [
          if (sub != null)
            TextSpan(
              text: ' · $sub',
              style: const TextStyle(
                fontWeight: FontWeight.w400,
                color: AppColors.textSub,
              ),
            ),
        ],
      ),
    );
  }
}

class _NicknameField extends StatelessWidget {
  const _NicknameField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.border),
    );
    return SizedBox(
      height: 52,
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 16, color: AppColors.text),
        decoration: InputDecoration(
          hintText: 'Nguyen',
          hintStyle: const TextStyle(color: AppColors.textSub),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
      ),
    );
  }
}
