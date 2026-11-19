import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/colors.dart';
import '../../app/diet.dart';
import '../../app/router.dart';
import '../../app/session.dart';
import '../../widgets/bold_quoted.dart';
import '../../widgets/dashed_border.dart';
import '../../widgets/iju_button.dart';
import '../../widgets/iju_chip.dart';
import '../../widgets/iju_header.dart';
import '../../widgets/iju_icon.dart';
import '../../widgets/section_label.dart';
import '../menu_scan/menu_scan_api.dart';
import '../practice/practice_screen.dart';
import '../review/review_store.dart';
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
///
/// 메뉴판 인식에서 메뉴를 골라 들어오면 [menus]의 메뉴가 문장의 '메뉴' 자리에 들어갑니다.
/// 두 개 이상 골랐으면 맨 위 '1 메뉴'에서 어느 메뉴로 문장을 만들지 고릅니다.
/// 없으면 시나리오의 시연 메뉴를 씁니다.
class ComposeScreen extends StatefulWidget {
  const ComposeScreen({
    super.key,
    this.scenario = butcher,
    this.menus = const [],
  });

  final Scenario scenario;

  /// 메뉴판 인식에서 고른 메뉴들 (고른 순서가 아니라 메뉴판 순서).
  final List<MenuCardData> menus;

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  /// 지금 문장을 만드는 메뉴 번호 ([ComposeScreen.menus] 안).
  int _menu = 0;

  /// 고른 메뉴를 넣은 시나리오. 메뉴판에서 고른 메뉴가 없으면 시연 메뉴 그대로.
  late Scenario _scenario = _scenarioFor(0);

  Scenario _scenarioFor(int i) {
    if (widget.menus.isEmpty) return widget.scenario;
    final m = widget.menus[i];
    return widget.scenario.withMenu(m.name, meaning: m.meaning);
  }

  /// 내 식단·종교. 맞지 않는 재료를 ‘빼 주세요’·‘들어가요?’에 미리 골라 둡니다.
  final _diets = AppSession.diets.value;

  late final List<ScenarioGroup> _groups = _scenario.groupsFor(_diets);

  /// 그룹별 선택한 옵션 번호. 필수가 아닌 그룹은 비워 둘 수 있고,
  /// 여러 개를 고르는 그룹(multi)만 두 개 이상이 들어갑니다.
  late final List<Set<int>> _selected = [
    for (final g in _groups) {?g.initial, ...g.initialAll},
  ];

  /// 서버 응답. 응답에 담긴 조합이 지금 고른 조합과 같을 때만 화면에 씁니다.
  ComposeResult? _remote;

  /// [_remote]가 어느 메뉴에 대한 응답인지. 메뉴를 바꾸면 이전 응답은 쓰지 않습니다.
  String? _remoteMenu;
  bool _loading = false;
  Timer? _debounce;

  /// 그룹 하나에서 고른 옵션 (옵션 순서대로).
  List<ScenarioOption> _pickedIn(int g) => [
    for (var i = 0; i < _groups[g].options.length; i++)
      if (_selected[g].contains(i)) _groups[g].options[i],
  ];

  /// 문장 종류별 고른 카드: 첫 문장(… 주세요.) / 빼 주세요 / 들어가요?
  List<ScenarioOption> _pickedOf(SentenceKind kind) => [
    for (var g = 0; g < _groups.length; g++)
      if (_groups[g].kind == kind) ..._pickedIn(g),
  ];

  List<String> _labelsOf(SentenceKind kind) => [
    for (final o in _pickedOf(kind)) o.label,
  ];

  /// 지금 조합. 서버 응답이 이 조합에 대한 것인지 비교하는 데 씁니다.
  List<String> get _requestKey => ComposeApi.keyOf(
    _labelsOf(SentenceKind.order),
    _labelsOf(SentenceKind.without),
    _labelsOf(SentenceKind.ask),
  );

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
      final g = _groups[group];
      final sel = _selected[group];
      if (g.multi) {
        // 필수 그룹은 마지막 하나를 풀 수 없습니다.
        if (!sel.remove(option) || (g.required && sel.isEmpty)) sel.add(option);
      } else {
        final same = sel.contains(option);
        sel.clear();
        if (!same || g.required) sel.add(option);
      }
    });
    // 칩을 연달아 누를 때 마지막 조합만 서버에 묻습니다.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _request);
  }

  void _pickMenu(int i) {
    if (i == _menu) return;
    setState(() {
      _menu = i;
      _scenario = _scenarioFor(i);
    });
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _request);
  }

  Future<void> _request() async {
    final key = _requestKey;
    final menu = _scenario.menu;
    setState(() => _loading = true);
    final result = await ComposeApi.compose(
      menu: menu,
      options: _labelsOf(SentenceKind.order),
      without: _labelsOf(SentenceKind.without),
      ask: _labelsOf(SentenceKind.ask),
    );
    if (!mounted) return;
    final current = listEquals(key, _requestKey) && menu == _scenario.menu;
    setState(() {
      if (current) _loading = false;
      if (result != null) {
        _remote = result;
        _remoteMenu = menu;
      }
    });
  }

  /// 그룹 하나의 카드 자리들. 비었으면 [empty]일 때만 빈자리 하나.
  Iterable<_Slot> _groupSlots(int g, {required bool empty}) sync* {
    final group = _groups[g];
    final picked = _pickedIn(g);
    if (picked.isEmpty) {
      if (empty) yield _Slot.empty(group.slot);
      return;
    }
    final tokens = group.tokensFor(picked);
    for (var i = 0; i < picked.length; i++) {
      yield _Slot(
        name: group.slot,
        label: picked[i].label,
        token: tokens[i],
        meaning: tr(picked[i].meaning),
      );
    }
  }

  /// 문장을 끝내는 자리: '주세요.' 또는 '들어가요?'
  _Slot _endSlot([String ending = '주세요.']) => _Slot(
    name: ending == '주세요.' ? '부탁' : '질문',
    label: ending,
    token: ending,
    meaning: tr(ending == '주세요.' ? _please : _askEnd),
    please: true,
  );

  /// 문장 틀의 자리들: 메뉴, 그룹마다 한 자리, '주세요.'
  /// 따로 붙는 문장(빼 주세요·들어가요?)은 고른 게 있을 때만 그 뒤에 이어 붙입니다.
  List<_Slot> _slots() => [
    _Slot(
      name: '메뉴',
      label: _scenario.menu,
      token: _scenario.menu,
      meaning: tr(_scenario.menuMeaning),
    ),
    for (var g = 0; g < _groups.length; g++)
      if (!_groups[g].separate) ..._groupSlots(g, empty: true),
    _endSlot(),
    for (var g = 0; g < _groups.length; g++)
      if (_groups[g].separate && _selected[g].isNotEmpty) ...[
        ..._groupSlots(g, empty: false),
        _endSlot(_groups[g].ending),
      ],
  ];

  /// 지금 고른 카드로 만든 문장 (서버 응답 전·서버가 없을 때).
  String _localSentence() {
    final main = [
      _scenario.menu,
      for (var g = 0; g < _groups.length; g++)
        if (!_groups[g].separate) ..._groups[g].tokensFor(_pickedIn(g)),
    ];
    return [
      '${main.join(' ')} 주세요.',
      for (var g = 0; g < _groups.length; g++)
        if (_groups[g].separate && _selected[g].isNotEmpty)
          '${_groups[g].tokensFor(_pickedIn(g)).join(' ')} ${_groups[g].ending}',
    ].join(' ');
  }

  /// 고른 카드 중 조사·어미가 붙어 모양이 바뀐 것과 그 이유 (그룹마다 하나).
  List<_Rule> _rules() => [
    for (var g = 0; g < _groups.length; g++)
      if (_groups[g].rule case final rule?)
        if (_changedCard(g) case (final label, final token))
          _Rule(label: label, token: token, text: tr(rule)),
  ];

  /// 그룹에서 모양이 바뀐 마지막 카드 (돼지고기 → 돼지고기는 빼).
  (String, String)? _changedCard(int g) {
    final picked = _pickedIn(g);
    final tokens = _groups[g].tokensFor(picked);
    for (var i = picked.length - 1; i >= 0; i--) {
      if (tokens[i] != picked[i].label) return (picked[i].label, tokens[i]);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final remote =
        listEquals(_remote?.options, _requestKey) &&
            _remoteMenu == _scenario.menu
        ? _remote
        : null;
    final translation = (remote?.meaning.isNotEmpty ?? false)
        ? remote!.meaning
        : _scenario.localMeaning(
            _pickedOf(SentenceKind.order),
            without: _pickedOf(SentenceKind.without),
            ask: _pickedOf(SentenceKind.ask),
          );
    final dietNames = dietLabels(_diets);
    final hasIngredients = _scenario.ingredients.isNotEmpty;
    final sentence = remote?.sentence ?? _localSentence();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const IjuHeader(title: '문장 만들기'),
            // 칩을 고르는 동안 카드가 자리에 들어가는 모습을 계속 보도록 위에 고정합니다.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              // 빼기·질문 문장까지 붙으면 길어지므로 화면의 40%까지만 쓰고 안에서 스크롤합니다.
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.4,
                ),
                child: _SentenceFrame(
                  slots: _slots(),
                  translation: translation,
                  loading: _loading,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  if (hasIngredients && dietNames != null) ...[
                    const SizedBox(height: 14),
                    _DietNote(names: dietNames),
                  ],
                  if (widget.menus.length > 1) ...[
                    const SizedBox(height: 18),
                    SectionLabel('1 메뉴', sub: tr(_menuSub)),
                    const SizedBox(height: 4),
                    const Text(
                      '메뉴판에서 고른 메뉴예요. 하나씩 골라 연습해요',
                      style: TextStyle(fontSize: 12, color: AppColors.textSub),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final (i, m) in widget.menus.indexed)
                          IjuChip(
                            label: m.name,
                            selected: i == _menu,
                            onTap: () => _pickMenu(i),
                          ),
                      ],
                    ),
                  ],
                  for (var g = 0; g < _groups.length; g++) ...[
                    const SizedBox(height: 18),
                    SectionLabel(
                      '${g + 2} ${_groups[g].title}',
                      sub: tr(_groups[g].sub),
                    ),
                    if (_groups[g].multi) ...[
                      const SizedBox(height: 4),
                      const Text(
                        '여러 개 고를 수 있어요',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSub,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final (i, o) in _groups[g].options.indexed)
                          IjuChip(
                            label: o.label,
                            selected: _selected[g].contains(i),
                            onTap: () => _toggle(g, i),
                            dot: _cautionColor(o.caution),
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
                    order: ScenarioOrder(
                      scenario: _scenario,
                      groups: _groups,
                      selected: _selected,
                    ),
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

const Tr _menuSub = {
  'vi': 'Món',
  'en': 'Menu',
  'fil': 'Menu',
  'km': 'មុខម្ហូប',
};

const Tr _please = {
  'vi': 'cho tôi',
  'en': 'please',
  'fil': 'pakibigay po',
  'km': 'សូមឲ្យ',
};

const Tr _askEnd = {
  'vi': 'có … không?',
  'en': 'is there … in it?',
  'fil': 'may … po ba?',
  'km': 'មាន … ទេ?',
};

/// 문장 만들기 위에 붙는 한 줄: 어떤 식단 기준으로 미리 골라 뒀는지.
class _DietNote extends StatelessWidget {
  const _DietNote({required this.names});

  final String names;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(fontSize: 13, color: AppColors.primaryDark),
          children: [
            TextSpan(
              text: names,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const TextSpan(text: ' 기준으로 빼 달라는 말과 물어볼 말을 골라 뒀어요.'),
          ],
        ),
      ),
    );
  }
}

Color? _cautionColor(Caution? c) => switch (c) {
  Caution.contains => AppColors.danger,
  Caution.hidden => AppColors.caution,
  null => null,
};

/// 문장 틀의 한 자리. [label]이 null이면 고르지 않은 빈자리입니다.
class _Slot {
  const _Slot({
    required this.name,
    required String this.label,
    required String this.token,
    required String this.meaning,
    this.please = false,
  });

  const _Slot.empty(this.name)
    : label = null,
      token = null,
      meaning = null,
      please = false;

  final String name;
  final String? label;
  final String? token;
  final String? meaning;

  /// 문장을 끝내는 '주세요.' 자리. 초록으로 채웁니다.
  final bool please;
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
      child: SingleChildScrollView(
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
                  _SlotView(index: i + 1, slot: slots[i]),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              translation,
              style: const TextStyle(fontSize: 14, color: AppColors.textBody),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotView extends StatelessWidget {
  const _SlotView({required this.index, required this.slot});

  final int index;
  final _Slot slot;

  @override
  Widget build(BuildContext context) {
    final label = slot.label;
    final last = slot.please;
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
