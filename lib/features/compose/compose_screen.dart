import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/colors.dart';
import '../../app/router.dart';
import '../../widgets/bold_quoted.dart';
import '../../widgets/dashed_border.dart';
import '../../widgets/iju_button.dart';
import '../../widgets/iju_chip.dart';
import '../../widgets/iju_header.dart';
import '../../widgets/iju_icon.dart';
import '../../widgets/section_label.dart';
import '../practice/practice_screen.dart';
import '../scenario/scenarios.dart';
import 'compose_api.dart';

/// 문장 조립. 키워드 카드를 골라 주문 문장을 직접 완성합니다. 담당: 개발자2
///
/// 소개서 ③ "키워드를 골라 문장을 직접 조립 → 어휘와 어순을 함께 익히기"에 맞춰
/// 문장을 '메뉴 → 얼마나 → 용도 … → 주세요' 순서의 자리(틀)로 보여 주고,
/// 카드마다 모국어 뜻을 항상 달아 둡니다. '구이용 → 구이용으로'처럼 조사·어미가
/// 붙는 부분은 색으로 표시하고, 아래 '문법 포인트'에서 이유를 모국어로 설명합니다.
///
/// 칩을 누르면 화면 안에서 바로 문장을 조립하고, 이어서 POST /ai/compose로
/// 번역·문법 조언을 받아 바꿔 끼웁니다. 서버가 없거나 느려도 화면은 그대로 동작합니다.
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

  /// 문장 틀의 자리들: 메뉴, 그룹마다 한 자리, 마지막 '주세요.'
  List<_Slot> _slots() => [
    _Slot(
      name: '메뉴',
      label: _scenario.menu,
      token: _scenario.menu,
      meaning: tr(_scenario.menuMeaning),
    ),
    for (var g = 0; g < _groups.length; g++)
      if (_selected[g] case final i?)
        _Slot(
          name: _groups[g].slot,
          label: _groups[g].options[i].label,
          token: _groups[g].options[i].token,
          meaning: tr(_groups[g].options[i].meaning),
        )
      else
        _Slot.empty(_groups[g].slot),
    _Slot(name: '부탁', label: '주세요.', token: '주세요.', meaning: tr(_please)),
  ];

  /// 고른 카드 중 조사·어미가 붙어 모양이 바뀐 것과 그 이유.
  List<_Rule> _rules() => [
    for (var g = 0; g < _groups.length; g++)
      if ((_selected[g], _groups[g].rule) case (final i?, final rule?))
        if (_groups[g].options[i] case final o when o.token != o.label)
          _Rule(label: o.label, token: o.token, text: tr(rule)),
  ];

  @override
  Widget build(BuildContext context) {
    final picked = _picked;
    final localTokens = [_scenario.menu, for (final o in picked) o.token];

    final remote = listEquals(_remote?.options, _pickedLabels) ? _remote : null;
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
            // 칩을 고르는 동안 카드가 자리에 들어가는 모습을 계속 보도록 위에 고정합니다.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _SentenceFrame(
                slots: _slots(),
                translation: translation,
                loading: _loading,
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  for (var g = 0; g < _groups.length; g++) ...[
                    const SizedBox(height: 18),
                    SectionLabel(
                      '${g + 2} ${_groups[g].title}',
                      sub: tr(_groups[g].sub),
                    ),
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
                  if (_rules() case final rules when rules.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _GrammarPoints(rules: rules),
                  ],
                  const SizedBox(height: 12),
                  _Feedback(text: remote?.feedback ?? _scenario.tip),
                  const SizedBox(height: 8),
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

const Tr _please = {
  'vi': 'cho tôi',
  'en': 'please',
  'fil': 'pakibigay po',
  'km': 'សូមឲ្យ',
};

/// 문장 틀의 한 자리. [label]이 null이면 고르지 않은 빈자리입니다.
class _Slot {
  const _Slot({
    required this.name,
    required String this.label,
    required String this.token,
    required String this.meaning,
  });

  const _Slot.empty(this.name) : label = null, token = null, meaning = null;

  final String name;
  final String? label;
  final String? token;
  final String? meaning;
}

class _Rule {
  const _Rule({required this.label, required this.token, required this.text});

  final String label;
  final String token;
  final String text;
}

/// 카드 글자. [token]이 [label]로 시작하면 덧붙은 조사·어미 부분을 강조합니다.
TextSpan _tokenSpan(String label, String token, TextStyle base) {
  if (token == label || !token.startsWith(label)) {
    return TextSpan(text: token, style: base);
  }
  return TextSpan(
    style: base,
    children: [
      TextSpan(text: label),
      TextSpan(
        text: token.substring(label.length),
        style: const TextStyle(
          color: AppColors.pointText,
          backgroundColor: AppColors.pointBg,
        ),
      ),
    ],
  );
}

/// 순서대로 놓인 자리에 카드가 들어가는 문장 틀.
class _SentenceFrame extends StatelessWidget {
  const _SentenceFrame({
    required this.slots,
    required this.translation,
    required this.loading,
  });

  final List<_Slot> slots;
  final String translation;
  final bool loading;

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
                  '카드가 한국어 순서대로 들어가요',
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
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [
              for (var i = 0; i < slots.length; i++)
                _SlotView(
                  index: i + 1,
                  slot: slots[i],
                  last: i == slots.length - 1,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            translation,
            style: const TextStyle(fontSize: 14, color: AppColors.textBody),
          ),
        ],
      ),
    );
  }
}

class _SlotView extends StatelessWidget {
  const _SlotView({
    required this.index,
    required this.slot,
    required this.last,
  });

  final int index;
  final _Slot slot;

  /// 마지막 '주세요.' 자리는 초록으로 채웁니다.
  final bool last;

  @override
  Widget build(BuildContext context) {
    final label = slot.label;
    final Widget card;
    if (label == null) {
      card = DashedBorder(
        color: AppColors.borderStrong,
        radius: 10,
        child: const SizedBox(
          height: 40,
          width: 56,
          child: Center(
            child: Text(
              '선택',
              style: TextStyle(fontSize: 13, color: AppColors.textSub),
            ),
          ),
        ),
      );
    } else {
      card = Container(
        key: ValueKey(slot.token),
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: last ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: last ? null : Border.all(color: AppColors.primary),
        ),
        // widthFactor: 1 → 글자 너비만큼만 차지 (Wrap 안에서 한 줄로 늘어나지 않게)
        child: Center(
          widthFactor: 1,
          child: Text.rich(
            _tokenSpan(
              label,
              slot.token!,
              TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: last ? Colors.white : AppColors.text,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$index ${slot.name}',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: 4),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: card,
        ),
        if (slot.meaning case final meaning? when meaning.isNotEmpty) ...[
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              meaning,
              style: const TextStyle(fontSize: 12, color: AppColors.textSub),
            ),
          ),
        ],
      ],
    );
  }
}

/// 고른 카드에 붙은 조사·어미를 모국어로 설명합니다 (예: 구이용 → 구이용으로).
class _GrammarPoints extends StatelessWidget {
  const _GrammarPoints({required this.rules});

  final List<_Rule> rules;

  @override
  Widget build(BuildContext context) {
    const strong = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: AppColors.text,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '문법 포인트',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSub,
            ),
          ),
          for (final r in rules) ...[
            const SizedBox(height: 10),
            Text.rich(
              TextSpan(
                style: strong,
                children: [
                  TextSpan(text: '${r.label} → '),
                  _tokenSpan(r.label, r.token, strong),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              r.text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textBody,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 서버(또는 시나리오)의 문법 조언 한 가지. ‘ ’로 감싼 부분은 굵게 보여 줍니다.
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
