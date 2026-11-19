import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/colors.dart';
import '../../app/theme.dart';
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
import 'recipe_api.dart';

/// 문장 조립. 키워드 카드를 골라 주문 문장을 직접 완성합니다. 담당: 개발자2
///
/// 소개서 ③ "키워드를 골라 문장을 직접 조립 → 어휘와 어순을 함께 익히기"에 맞춰
/// 문장을 '메뉴 → 얼마나 → 용도 … → 주세요' 순서의 자리(틀)로 보여 주고,
/// 카드마다 모국어 뜻을 항상 달아 둡니다. '구이용 → 구이용으로'처럼 조사·어미가
/// 붙는 부분은 색으로 표시하고, 아래 '문법 포인트'에서 이유를 모국어로 설명합니다.
///
/// 칩을 누르면 화면 안에서 바로 문장을 조립하고, 이어서 POST /ai/compose로
/// 번역·문법 조언을 받아 바꿔 끼웁니다. 서버가 없거나 느려도 화면은 그대로 동작합니다.
/// 시나리오(식당·반찬가게)는 scenario/scenarios.dart에 있습니다.
///
/// 메뉴판 인식에서 메뉴를 골라 들어오면 [menus]의 메뉴가 문장의 '메뉴' 자리에 들어갑니다.
/// 두 개 이상 골랐으면 맨 위 '1 메뉴'에서 어느 메뉴로 문장을 만들지 고릅니다.
/// 없으면 시나리오의 시연 메뉴를 씁니다.
class ComposeScreen extends StatefulWidget {
  const ComposeScreen({
    super.key,
    this.scenario = restaurant,
    this.menus = const [],
  });

  final Scenario scenario;

  /// 메뉴판 인식에서 고른 메뉴들 (고른 순서가 아니라 메뉴판 순서).
  final List<MenuCardData> menus;

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  /// 고른 메뉴를 넣은 시나리오. 메뉴판에서 고른 메뉴가 없으면 시연 메뉴 그대로.
  /// 두 개 이상 골랐으면 한 번에 주문하는 문장(‘김치찌개랑 콜라 주세요’)으로 만듭니다.
  late Scenario _scenario = _scenarioWith(const {});

  Scenario _scenarioWith(Map<String, RecipeMatch> recipes) {
    final menus = widget.menus;
    if (menus.isEmpty) return widget.scenario;
    if (menus.length == 1) {
      final m = menus.first;
      // 메뉴 이름으로 문장 틀(인분·개·병)과 재료(빼 주세요·들어가요?)를 고릅니다.
      final s = widget.scenario.forMenu(m.name, meaning: m.meaning);
      final r = recipes[m.name];
      return r == null ? s : s.withRecipe(r);
    }
    return widget.scenario.forOrder([
      for (final m in menus) (m.name, m.meaning),
    ], recipes: recipes);
  }

  /// 내 식단·종교. 맞지 않는 재료는 ‘빼 주세요’·‘들어가요?’ 칩에 점으로 표시합니다.
  final _diets = AppSession.diets.value;

  /// 레시피를 받으면 재료 그룹이 바뀌어 다시 만듭니다.
  late List<ScenarioGroup> _groups = _scenario.groupsFor(_diets);

  /// 그룹별 선택한 옵션 번호. 필수가 아닌 그룹은 비워 둘 수 있고,
  /// 여러 개를 고르는 그룹(multi)만 두 개 이상이 들어갑니다.
  late List<Set<int>> _selected = _initialSelection(_groups);

  static List<Set<int>> _initialSelection(List<ScenarioGroup> groups) => [
    for (final g in groups) {?g.initial, ...g.initialAll},
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
    _loadRecipe();
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

  /// 메뉴판에서 고른 메뉴면 서버(Supabase recipes 표)에서 레시피 재료를 찾아
  /// ‘빼 주세요’·‘들어가요?’ 칩을 보강합니다. 서버가 없으면 이름으로 짐작한 재료 그대로.
  Future<void> _loadRecipe() async {
    if (_scenario.ingredients.isEmpty) return;
    final names = [
      for (final m in widget.menus)
        if (!isExtra(m.name) && !isDrink(m.name)) m.name,
    ];
    final recipes = <String, RecipeMatch>{};
    for (final name in names) {
      final match = await RecipeApi.match(name);
      if (match != null && !match.isEmpty) recipes[name] = match;
    }
    if (!mounted || recipes.isEmpty) return;
    final next = _scenarioWith(recipes);
    if (next.ingredients.length == _scenario.ingredients.length &&
        next.recipes.isEmpty) {
      return;
    }
    setState(() {
      _scenario = next;
      final groups = _scenario.groupsFor(_diets);
      // 몇 인분·맵기처럼 첫 문장 그룹은 고른 그대로 두고, 재료 그룹만 새로 만듭니다.
      final keep = _scenario.groups.length;
      _selected = [
        for (var g = 0; g < groups.length; g++)
          g < keep && g < _selected.length
              ? _selected[g]
              : {?groups[g].initial, ...groups[g].initialAll},
      ];
      _groups = groups;
    });
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _request);
  }

  Future<void> _request() async {
    // 여러 메뉴 주문은 서버 문장 규칙(메뉴 하나 + 카드)과 달라 앱이 직접 만듭니다.
    if (_scenario.isOrder) return;
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

  /// 여러 메뉴 주문의 자리들 ([Scenario.sentenceFor]와 같은 순서).
  ///   김치찌개 1인분이랑 콜라 주세요. / 김치찌개는 덜 맵게 해 주세요. /
  ///   치즈 추가해 주세요. / 돼지고기는 빼 주세요. / 고기 육수 들어가요?
  List<_Slot> _orderSlots() {
    final lines = _scenario.lines;
    final dishes = [
      for (final l in lines)
        if (!l.extra) l,
    ];
    final extras = [
      for (final l in lines)
        if (l.extra) l,
    ];
    final out = <_Slot>[];
    for (final (k, l) in dishes.indexed) {
      final item = <_Slot>[
        _Slot(name: '메뉴', label: l.name, token: l.name, meaning: tr(l.meaning)),
        for (var g = 0; g < _groups.length; g++)
          if (_groups[g].item == l.name &&
              _groups[g].kind == SentenceKind.order)
            ..._groupSlots(g, empty: false),
      ];
      if (k < dishes.length - 1) {
        final last = item.removeLast();
        item.add(
          _Slot(
            name: last.name,
            label: last.label!,
            token: withAnd(last.token!),
            meaning: last.meaning!,
          ),
        );
      }
      out.addAll(item);
    }
    if (dishes.isNotEmpty) out.add(_endSlot());
    for (var g = 0; g < _groups.length; g++) {
      if (_groups[g].kind != SentenceKind.style || _selected[g].isEmpty) {
        continue;
      }
      final item = _groups[g].item!;
      final line = lines.firstWhere((l) => l.name == item);
      out
        ..add(
          _Slot(
            name: '메뉴',
            label: item,
            token: withTopic(item),
            meaning: tr(line.meaning),
          ),
        )
        ..addAll(_groupSlots(g, empty: false))
        ..add(_endSlot());
    }
    if (extras.isNotEmpty) {
      for (final (k, e) in extras.indexed) {
        out.add(
          _Slot(
            name: '추가',
            label: e.word,
            token: k < extras.length - 1 ? withAnd(e.word) : e.word,
            meaning: tr(e.meaning),
          ),
        );
      }
      out
        ..add(
          _Slot(name: '부탁', label: '추가해', token: '추가해', meaning: tr(_addMore)),
        )
        ..add(_endSlot());
    }
    for (var g = 0; g < _groups.length; g++) {
      final kind = _groups[g].kind;
      if ((kind == SentenceKind.without || kind == SentenceKind.ask) &&
          _selected[g].isNotEmpty) {
        // 김치찌개는 / 김치찌개에 + 돼지고기 빼 주세요 / 고기 육수 들어가요?
        if (Scenario.itemPrefix(_groups[g]) case final prefix?) {
          final item = _groups[g].item!;
          final line = lines.firstWhere((l) => l.name == item);
          out.add(
            _Slot(
              name: '메뉴',
              label: item,
              token: prefix.trim(),
              meaning: tr(line.meaning),
            ),
          );
        }
        out
          ..addAll(_groupSlots(g, empty: false))
          ..add(_endSlot(_groups[g].ending));
      }
    }
    return out;
  }

  /// 문장 틀의 자리들: 메뉴, 그룹마다 한 자리, '주세요.'
  /// 따로 붙는 문장(빼 주세요·들어가요?)은 고른 게 있을 때만 그 뒤에 이어 붙입니다.
  List<_Slot> _slots() => _scenario.isOrder
      ? _orderSlots()
      : [
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

  /// 그룹마다 고른 카드.
  List<List<ScenarioOption>> get _pickedAll => [
    for (var g = 0; g < _groups.length; g++) _pickedIn(g),
  ];

  /// 지금 고른 카드로 만든 문장 (서버 응답 전·서버가 없을 때).
  String _localSentence() => _scenario.sentenceFor(_groups, _pickedAll);

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
        : _scenario.meaningFor(_groups, _pickedAll);
    final dietNames = dietLabels(_diets);
    // 칩(빼 주세요·들어가요?)이 있는 재료가 있을 때만 식단 안내를 보여 줍니다.
    final hasIngredients = _scenario.ingredients.any((i) => !i.main);
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
                    _DietNote(names: dietNames, recipes: _scenario.recipes),
                  ],
                  if (_scenario.mainIngredients.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _ContainsNote(
                      menu: _scenario.menu,
                      ingredients: _scenario.mainIngredients,
                      diets: _diets,
                    ),
                  ],
                  for (var g = 0; g < _groups.length; g++) ...[
                    const SizedBox(height: 18),
                    SectionLabel(
                      _groups[g].item == null
                          ? '${g + 2} ${_groups[g].title}'
                          : '${g + 2} ${_groups[g].item} · ${_groups[g].title}',
                      sub: tr(_groups[g].sub),
                    ),
                    if (_groups[g].multi) ...[
                      const SizedBox(height: 4),
                      const Text(
                        '여러 개 고를 수 있어요',
                        style: TextStyle(
                          fontSize: 13,
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

const Tr _please = {
  'vi': 'cho tôi',
  'en': 'please',
  'fil': 'pakibigay po',
  'km': 'សូមឲ្យ',
};

/// ‘치즈 추가해 주세요’의 ‘추가해’
const Tr _addMore = {
  'vi': 'thêm',
  'en': 'add',
  'fil': 'dagdagan',
  'km': 'បន្ថែម',
};

const Tr _askEnd = {
  'vi': 'có … không?',
  'en': 'is there … in it?',
  'fil': 'may … po ba?',
  'km': 'មាន … ទេ?',
};

/// 문장 만들기 위에 붙는 한 줄: 어떤 식단 기준으로 재료에 표시했는지.
class _DietNote extends StatelessWidget {
  const _DietNote({required this.names, this.recipes = const []});

  final String names;

  /// 재료를 찾는 데 쓴 레시피 이름
  final List<String> recipes;

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
          style: const TextStyle(fontSize: 14, color: AppColors.primaryDark),
          children: [
            TextSpan(
              text: names,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const TextSpan(
              text: ' 기준으로 맞지 않을 수 있는 재료에 점을 찍어 뒀어요. 필요한 것만 눌러서 골라요.',
            ),
            if (recipes.isNotEmpty)
              TextSpan(
                text:
                    '\n레시피 참고: ${recipes.first}'
                    '${recipes.length > 1 ? ' 외 ${recipes.length - 1}개' : ''}',
                style: const TextStyle(fontSize: 13),
              ),
          ],
        ),
      ),
    );
  }
}

/// 메뉴 이름에 든 주재료 안내: ‘새우튀김에 들어가요: 새우’.
/// 빼 달라고 할 수 없는 재료라 칩이 아니라 안내로만 보여 주고,
/// 내 식단·종교와 맞지 않으면 빨갛게 표시합니다.
class _ContainsNote extends StatelessWidget {
  const _ContainsNote({
    required this.menu,
    required this.ingredients,
    required this.diets,
  });

  final String menu;
  final List<Ingredient> ingredients;
  final Set<Diet> diets;

  @override
  Widget build(BuildContext context) {
    // 메뉴별로 묶기 (메뉴 하나면 item이 null)
    final byItem = <String, List<Ingredient>>{};
    for (final i in ingredients) {
      byItem.putIfAbsent(i.item ?? menu, () => []).add(i);
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (n, e) in byItem.entries.indexed) ...[
            if (n > 0) const SizedBox(height: 10),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${e.key}에 들어가요',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: '  ${tr(_containsSub)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSub,
                    ),
                  ),
                ],
              ),
              style: const TextStyle(fontSize: 14, color: AppColors.text),
            ),
            const SizedBox(height: 6),
            for (final i in e.value) _containsRow(i),
          ],
        ],
      ),
    );
  }

  Widget _containsRow(Ingredient i) {
    final clash = i.conflictsWith(diets);
    final color = clash.isEmpty ? AppColors.textBody : AppColors.danger;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text.rich(
        TextSpan(
          style: TextStyle(fontSize: 14, color: color),
          children: [
            TextSpan(
              text: '· ${i.label}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: '  ${tr(i.meaning)}'),
            if (clash.isNotEmpty)
              TextSpan(
                text: '  (${clash.map((d) => d.label).join(', ')}에 맞지 않아요)',
                style: const TextStyle(fontSize: 13),
              ),
          ],
        ),
      ),
    );
  }
}

const Tr _containsSub = {
  'vi': 'Món này có',
  'en': 'Contains',
  'fil': 'May sangkap na',
  'km': 'មានផ្ទុក',
};

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
                    style: TextStyle(fontSize: 14, color: AppColors.textSub),
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
            Text(translation, style: AppText.native),
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
      // 빈칸 = 오렌지 점선
      card = DashedBorder(
        color: AppColors.accent,
        radius: 12,
        child: Container(
          height: 44,
          width: 64,
          decoration: BoxDecoration(
            color: AppColors.pointBg.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Text(
              '선택',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.pointText,
              ),
            ),
          ),
        ),
      );
    } else {
      card = Container(
        key: ValueKey(slot.token),
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: last ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          // 채워진 칸 = 초록 테두리
          border: last ? null : Border.all(color: AppColors.primary, width: 2),
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
            fontSize: 13,
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
              style: const TextStyle(fontSize: 13, color: AppColors.textSub),
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
              fontSize: 14,
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
                fontSize: 14,
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
