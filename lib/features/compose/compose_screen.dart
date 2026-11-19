import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/colors.dart';
import '../../app/router.dart';
import '../../widgets/bold_quoted.dart';
import '../../widgets/iju_button.dart';
import '../../widgets/iju_chip.dart';
import '../../widgets/iju_header.dart';
import '../../widgets/iju_icon.dart';
import '../../widgets/section_label.dart';
import '../practice/practice_screen.dart';
import '../scenario/scenarios.dart';
import 'compose_api.dart';

/// Figma '4 문장 조립'. 키워드 카드를 골라 주문 문장을 직접 완성합니다. 담당: 개발자2
///
/// 칩을 누르면 화면 안에서 바로 문장을 조립해 보여 주고, 이어서 POST /ai/compose로
/// 번역·카드 뜻·문법 조언을 받아 바꿔 끼웁니다. 서버가 없거나 느려도 화면은 그대로 동작합니다.
/// 시나리오(정육점·식당·반찬가게)는 scenario/scenarios.dart에 있습니다.
/// TODO(개발자1): 메뉴판 인식에서 고른 메뉴·옵션 넘겨받기. 지금은 시나리오의 시연 메뉴입니다.
class ComposeScreen extends StatefulWidget {
  const ComposeScreen({super.key, this.scenario = butcher});

  final Scenario scenario;

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  Scenario get _scenario => widget.scenario;
  List<ScenarioGroup> get _groups => _scenario.groups;

  /// 그룹별 선택한 옵션 번호. 필수가 아닌 그룹은 비워 둘 수 있습니다.
  late final List<int?> _selected = [for (final g in _groups) g.initial];

  /// 서버 응답. 응답에 담긴 조합이 지금 고른 조합과 같을 때만 화면에 씁니다.
  ComposeResult? _remote;
  bool _loading = false;
  Timer? _debounce;

  List<ScenarioOption> get _picked => [
    for (var g = 0; g < _groups.length; g++)
      if (_selected[g] case final i?) _groups[g].options[i],
  ];

  List<String> get _pickedLabels => [for (final o in _picked) o.label];

  @override
  void initState() {
    super.initState();
    _request();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _toggle(int group, int option) {
    setState(() {
      final same = _selected[group] == option;
      _selected[group] = same && !_groups[group].required ? null : option;
    });
    // 칩을 연달아 누를 때 마지막 조합만 서버에 묻습니다.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _request);
  }

  Future<void> _request() async {
    final labels = _pickedLabels;
    setState(() => _loading = true);
    final result = await ComposeApi.compose(
      menu: _scenario.menu,
      options: labels,
    );
    if (!mounted) return;
    final current = listEquals(labels, _pickedLabels);
    setState(() {
      if (current) _loading = false;
      if (result != null) _remote = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final picked = _picked;
    final localTokens = [_scenario.menu, for (final o in picked) o.token];

    final remote = listEquals(_remote?.options, _pickedLabels) ? _remote : null;
    // 서버 문장도 같은 규칙으로 만들어지므로 카드 모양은 화면에서 조립한 것을 씁니다
    // ('한 근'처럼 띄어 쓴 카드가 둘로 쪼개지지 않게).
    final tokens = localTokens;
    final translation = (remote?.meaning.isNotEmpty ?? false)
        ? remote!.meaning
        : _scenario.localMeaning(picked);
    final sentence = remote?.sentence ?? '${localTokens.join(' ')} 주세요.';

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
                  _SentenceBuilder(
                    tokens: tokens,
                    translation: translation,
                    meanings: remote?.meanings ?? const {},
                    loading: _loading,
                  ),
                  for (var g = 0; g < _groups.length; g++) ...[
                    const SizedBox(height: 18),
                    SectionLabel(_groups[g].title, sub: tr(_groups[g].sub)),
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
                  _Feedback(text: remote?.feedback ?? _scenario.tip),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: IjuButton(
                label: '말하기 연습하기',
                onPressed: () => context.push(
                  AppRoutes.practice,
                  extra: PracticeArgs(
                    sentence: sentence,
                    meaning: translation,
                    scenario: _scenario,
                  ),
                ),
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
  const _SentenceBuilder({
    required this.tokens,
    required this.translation,
    required this.meanings,
    required this.loading,
  });

  final List<String> tokens;
  final String translation;

  /// 카드 단어 → 학습자 언어 뜻. 문장 카드를 누르면 뜻을 보여 줍니다.
  final Map<String, String> meanings;
  final bool loading;

  String? _meaningOf(String token) {
    for (final e in meanings.entries) {
      if (e.value.isNotEmpty && token.startsWith(e.key)) return e.value;
    }
    return null;
  }

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
          Row(
            children: [
              const Expanded(
                child: Text(
                  '카드를 골라 직접 문장을 완성해요',
                  style: TextStyle(fontSize: 13, color: AppColors.textSub),
                ),
              ),
              if (loading)
                const SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in tokens) _Token(t, meaning: _meaningOf(t)),
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
  const _Token(this.text, {this.filled = false, this.meaning});

  final String text;
  final bool filled;
  final String? meaning;

  @override
  Widget build(BuildContext context) {
    final card = Container(
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
    if (meaning == null) return card;
    return Tooltip(
      message: meaning,
      triggerMode: TooltipTriggerMode.tap,
      child: card,
    );
  }
}

/// Figma 'Feedback'. 문법 한 가지를 짧게 알려줍니다. ‘ ’로 감싼 부분은 굵게 보여 줍니다.
class _Feedback extends StatelessWidget {
  const _Feedback({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    const normal = TextStyle(
      fontSize: 14,
      height: 1.5,
      color: AppColors.primaryDark,
    );

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
              TextSpan(style: normal, children: boldQuoted(text)),
            ),
          ),
        ],
      ),
    );
  }
}
