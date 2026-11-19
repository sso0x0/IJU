import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/colors.dart';
import '../../app/router.dart';
import '../../widgets/iju_button.dart';
import '../../widgets/iju_chip.dart';
import '../../widgets/iju_header.dart';
import '../../widgets/iju_icon.dart';
import '../../widgets/section_label.dart';

/// Figma '4 문장 조립'. 키워드 카드를 골라 주문 문장을 직접 완성합니다. 담당: 개발자2
/// TODO(개발자2): POST /ai/compose 결과(cards, sentence, meaning)로 교체. 지금은 시연용 고정 데이터입니다.
class ComposeScreen extends StatefulWidget {
  const ComposeScreen({super.key});

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

/// 고를 수 있는 키워드 하나. [token]은 문장에 들어갈 모양, [vi]는 번역 조각.
class _Option {
  const _Option(this.label, this.token, this.vi);
  final String label;
  final String token;
  final String vi;
}

class _OptionGroup {
  const _OptionGroup(
    this.title,
    this.sub,
    this.options, {
    this.required = true,
  });
  final String title;
  final String sub;
  final List<_Option> options;
  final bool required;
}

class _ComposeScreenState extends State<ComposeScreen> {
  static const _menu = '삼겹살';
  static const _menuVi = 'thịt ba chỉ';

  static const _groups = [
    _OptionGroup('얼마나', 'Bao nhiêu', [
      _Option('300그램', '300그램', '300g'),
      _Option('600그램', '600그램', '600g'),
      _Option('한 근', '한 근', '1 geun (600g)'),
    ]),
    _OptionGroup('어떻게 먹어요?', 'Dùng để làm gì', [
      _Option('구이용', '구이용으로', 'để nướng'),
      _Option('찌개용', '찌개용으로', 'để nấu canh'),
      _Option('수육용', '수육용으로', 'để luộc'),
    ]),
    _OptionGroup('손질', 'Cách cắt', [
      _Option('그대로', '그대로', 'để nguyên'),
      _Option('두껍게', '두껍게 썰어', 'cắt dày'),
      _Option('얇게', '얇게 썰어', 'cắt mỏng'),
    ], required: false),
  ];

  /// 그룹별 선택한 옵션 번호. 손질은 고르지 않아도 됩니다.
  final List<int?> _selected = [1, 0, null];

  List<_Option> get _picked => [
    for (var g = 0; g < _groups.length; g++)
      if (_selected[g] case final i?) _groups[g].options[i],
  ];

  void _toggle(int group, int option) {
    setState(() {
      final same = _selected[group] == option;
      _selected[group] = same && !_groups[group].required ? null : option;
    });
  }

  @override
  Widget build(BuildContext context) {
    final picked = _picked;
    final tokens = [_menu, for (final o in picked) o.token];
    final vi =
        'Cho tôi ${picked.first.vi} $_menuVi '
        '${picked.skip(1).map((o) => o.vi).join(', ')}.';

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const IjuHeader(title: '문장 만들기'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _SentenceBuilder(tokens: tokens, translation: vi),
                  for (var g = 0; g < _groups.length; g++) ...[
                    const SizedBox(height: 18),
                    SectionLabel(_groups[g].title, sub: _groups[g].sub),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < _groups[g].options.length; i++)
                          IjuChip(
                            label: _groups[g].options[i].label,
                            selected: _selected[g] == i,
                            onTap: () => _toggle(g, i),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  const _Feedback(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: IjuButton(
                label: '말하기 연습하기',
                onPressed: () => context.push(AppRoutes.practice),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Figma 'SentenceBuilder'. 마지막 '주세요.' 카드만 초록으로 채웁니다.
class _SentenceBuilder extends StatelessWidget {
  const _SentenceBuilder({required this.tokens, required this.translation});

  final List<String> tokens;
  final String translation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '카드를 골라 직접 문장을 완성해요',
            style: TextStyle(fontSize: 13, color: AppColors.textSub),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in tokens) _Token(t),
              const _Token('주세요.', filled: true),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            translation,
            style: const TextStyle(fontSize: 14, color: AppColors.textBody),
          ),
        ],
      ),
    );
  }
}

class _Token extends StatelessWidget {
  const _Token(this.text, {this.filled = false});

  final String text;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: filled ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: filled ? null : Border.all(color: AppColors.primary),
      ),
      // widthFactor: 1 → 글자 너비만큼만 차지 (Wrap 안에서 한 줄로 늘어나지 않게)
      child: Center(
        widthFactor: 1,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: filled ? Colors.white : AppColors.text,
          ),
        ),
      ),
    );
  }
}

/// Figma 'Feedback'. 문법 한 가지를 짧게 알려줍니다.
class _Feedback extends StatelessWidget {
  const _Feedback();

  @override
  Widget build(BuildContext context) {
    const normal = TextStyle(
      fontSize: 14,
      height: 1.5,
      color: AppColors.primaryDark,
    );
    const bold = TextStyle(fontWeight: FontWeight.w700);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IjuIcon(IjuIcons.bulb, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              const TextSpan(
                style: normal,
                children: [
                  TextSpan(text: '잘했어요! 용도 뒤에는 '),
                  TextSpan(text: '‘-으로’', style: bold),
                  TextSpan(text: '를 붙여요. 구이용'),
                  TextSpan(text: '으로', style: bold),
                  TextSpan(text: ', 찌개용'),
                  TextSpan(text: '으로', style: bold),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
