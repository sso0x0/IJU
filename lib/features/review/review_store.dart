import 'package:flutter/foundation.dart' show ValueNotifier;

import '../../app/session.dart';
import '../scenario/scenarios.dart';

/// 문장 만들기에서 고른 카드 조합. 복습 2·3단계에서 카드 몇 개를 바꿔 새 문장을 만드는 데 씁니다.
class ScenarioOrder {
  ScenarioOrder({
    required this.scenario,
    required this.groups,
    required List<Set<int>> selected,
  }) : selected = [for (final s in selected) Set.unmodifiable(s)];

  /// 시나리오 옵션 이름으로 만듭니다 (시연 데이터용). 없는 이름은 무시합니다.
  factory ScenarioOrder.fromLabels(Scenario scenario, List<String> labels) {
    final groups = scenario.groupsFor(const {});
    return ScenarioOrder(
      scenario: scenario,
      groups: groups,
      selected: [
        for (final g in groups)
          {
            for (final (i, o) in g.options.indexed)
              if (labels.contains(o.label)) i,
          },
      ],
    );
  }

  /// 메뉴가 들어간 시나리오 (메뉴판에서 고른 메뉴면 [Scenario.withMenu]).
  final Scenario scenario;

  /// 문장을 만들 때의 그룹 (식단에 따라 ‘빼 주세요’·‘들어가요?’가 붙음).
  final List<ScenarioGroup> groups;

  /// 그룹별 고른 옵션 번호.
  final List<Set<int>> selected;

  List<ScenarioOption> _picked(int g) => [
    for (var i = 0; i < groups[g].options.length; i++)
      if (selected[g].contains(i)) groups[g].options[i],
  ];

  List<ScenarioOption> _pickedOf(SentenceKind kind) => [
    for (var g = 0; g < groups.length; g++)
      if (groups[g].kind == kind) ..._picked(g),
  ];

  /// 고른 카드로 만든 문장 (문장 만들기 화면의 자체 조립과 같은 규칙).
  String get sentence {
    final main = [
      scenario.menu,
      for (var g = 0; g < groups.length; g++)
        if (!groups[g].separate) ...groups[g].tokensFor(_picked(g)),
    ];
    return [
      '${main.join(' ')} 주세요.',
      for (var g = 0; g < groups.length; g++)
        if (groups[g].separate && selected[g].isNotEmpty)
          '${groups[g].tokensFor(_picked(g)).join(' ')} ${groups[g].ending}',
    ].join(' ');
  }

  /// 서버 없이 만드는 모국어 뜻.
  String get meaning => scenario.localMeaning(
    _pickedOf(SentenceKind.order),
    without: _pickedOf(SentenceKind.without),
    ask: _pickedOf(SentenceKind.ask),
  );

  /// 하나만 고르는 첫 문장 그룹 중 고른 게 있고 다른 옵션이 있는 그룹 (얼마나·용도·맵기).
  List<int> get _swappable => [
    for (var g = 0; g < groups.length; g++)
      if (groups[g].kind == SentenceKind.order &&
          !groups[g].multi &&
          groups[g].options.length > 1 &&
          selected[g].length == 1)
        g,
  ];

  ScenarioOrder _with(Map<int, Set<int>> changes) => ScenarioOrder(
    scenario: scenario,
    groups: groups,
    selected: [
      for (var g = 0; g < groups.length; g++) changes[g] ?? selected[g],
    ],
  );

  Set<int> _next(int g, [int step = 1]) => {
    (selected[g].first + step) % groups[g].options.length,
  };

  /// 2단계: 카드 하나만 바꿉니다 (마지막으로 바꿀 수 있는 자리, 예: 구이용 → 찌개용).
  ScenarioOrder slightlyChanged() {
    final s = _swappable;
    if (s.isEmpty) return this;
    return _with({s.last: _next(s.last)});
  }

  /// 3단계: 바꿀 수 있는 카드를 모두 바꾸고, 비어 있던 자리 하나를 더 채웁니다
  /// (손질 → 두껍게 썰어, 없으면 ‘빼 주세요’·‘들어가요?’ 문장).
  ScenarioOrder harder() {
    final s = _swappable;
    final changes = <int, Set<int>>{
      // 2단계에서 바꾼 자리는 한 칸 더 넘겨 2단계와 다른 문장이 되게 합니다.
      for (final g in s) g: _next(g, g == s.last ? 2 : 1),
    };
    int? empty;
    for (var g = 0; g < groups.length; g++) {
      if (selected[g].isEmpty && groups[g].options.isNotEmpty) {
        // 첫 문장 자리를 먼저, 그다음 따로 붙는 문장.
        if (empty == null || (groups[empty].separate && !groups[g].separate)) {
          empty = g;
        }
      }
    }
    if (empty != null) {
      final opts = groups[empty].options;
      changes[empty] = {opts.length > 1 ? 1 : 0};
    }
    return _with(changes);
  }
}

/// 복습 단계. 1 그대로 → 2 살짝 바꿔서 → 3 뜻만 보고 더 길게.
enum ReviewStage {
  same(1, '그대로 말하기', '전에 한 문장 그대로'),
  changed(2, '바꿔 말하기', '카드 하나를 바꾼 문장'),
  hard(3, '뜻만 보고 말하기', '더 길어진 문장을 뜻만 보고');

  const ReviewStage(this.number, this.action, this.description);

  final int number;
  final String action;
  final String description;

  /// 이 단계를 끝내면 다음 복습까지 기다리는 날 수.
  int get waitDays => const [1, 3, 7][number - 1];
}

/// 한 번 해 본 미션 문장 하나.
class ReviewItem {
  ReviewItem({
    required this.id,
    required this.sentence,
    required this.meaning,
    required this.order,
    required this.next,
    this.score,
    this.cleared = 0,
  });

  final String id;

  /// 미션 때 말한 문장 그대로 (서버가 다듬은 문장일 수 있음).
  final String sentence;
  final String meaning;
  final ScenarioOrder? order;

  /// 다음 복습 날.
  DateTime next;

  /// 마지막 발음 점수 (없으면 아직 채점 전)
  int? score;

  /// 끝낸 단계 수 (0~3).
  int cleared;

  Scenario get scenario => order?.scenario ?? butcher;

  bool get done => cleared >= ReviewStage.values.length;

  /// 지금 할 단계. 다 끝냈으면 3단계를 다시 합니다.
  ReviewStage get stage =>
      ReviewStage.values[done ? ReviewStage.values.length - 1 : cleared];

  /// 단계에 맞는 연습 문장과 뜻.
  (String, String) textFor(ReviewStage stage) {
    final o = order;
    if (stage == ReviewStage.same || o == null) return (sentence, meaning);
    final v = stage == ReviewStage.changed ? o.slightlyChanged() : o.harder();
    return (v.sentence, v.meaning);
  }

  /// '오늘', '내일', 'N일 뒤'
  String dueLabel(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(next.year, next.month, next.day);
    final d = day.difference(today).inDays;
    if (d <= 0) return '오늘';
    if (d == 1) return '내일';
    return '$d일 뒤';
  }
}

/// 내가 한 미션 문장을 모아 두는 복습 목록.
/// 음성 연습을 끝내거나 실전으로 넘어가면 [add]로 들어옵니다.
/// TODO(개발자3): 서버 저장으로 바꾸기. 지금은 앱을 다시 켜면 시연 데이터로 돌아갑니다.
abstract final class ReviewStore {
  static final items = ValueNotifier<List<ReviewItem>>(_demo());

  static int _seq = 0;

  /// 미션 문장을 복습 목록 맨 위에 넣습니다. 같은 문장이 있으면 점수만 바꿉니다.
  static void add({
    required String sentence,
    required String meaning,
    ScenarioOrder? order,
    int? score,
  }) {
    final list = items.value;
    for (final i in list) {
      if (i.sentence == sentence) {
        if (score != null) i.score = score;
        items.value = [...list];
        return;
      }
    }
    items.value = [
      ReviewItem(
        id: 'mine-${_seq++}',
        sentence: sentence,
        meaning: meaning,
        order: order,
        score: score,
        next: DateTime.now(),
      ),
      ...list,
    ];
  }

  /// 복습 [stage]를 끝냈을 때. 다음 단계로 넘기고 다음 복습 날을 정합니다.
  static void complete(String id, ReviewStage stage, {int? score}) {
    final list = items.value;
    for (final i in list) {
      if (i.id != id) continue;
      if (i.cleared < stage.number) i.cleared = stage.number;
      if (score != null) i.score = score;
      i.next = DateTime.now().add(Duration(days: stage.waitDays));
    }
    items.value = [...list];
  }

  /// 테스트용: 시연 데이터로 되돌립니다.
  static void reset() => items.value = _demo();

  static List<ReviewItem> _demo() {
    final now = DateTime.now();
    ReviewItem demo(
      String id,
      ScenarioOrder order,
      String meaning, {
      required int days,
      required int score,
      int cleared = 0,
    }) => ReviewItem(
      id: id,
      sentence: order.sentence,
      meaning: meaning,
      order: order,
      next: now.add(Duration(days: days)),
      score: score,
      cleared: cleared,
    );

    return [
      demo(
        'demo-1',
        ScenarioOrder.fromLabels(
          butcher.withMenu('목살', meaning: _meaning(_moksal)),
          ['300그램', '찌개용'],
        ),
        'Cho tôi 300g thịt nạc vai để nấu canh.',
        days: 0,
        score: 76,
      ),
      demo(
        'demo-2',
        ScenarioOrder.fromLabels(butcher, ['600그램', '구이용']),
        'Cho tôi 600g thịt ba chỉ để nướng.',
        days: 1,
        score: 82,
        cleared: 1,
      ),
      demo(
        'demo-3',
        ScenarioOrder.fromLabels(
          restaurant.withMenu('제육볶음', meaning: _meaning(_jeyuk)),
          ['1인분', '덜 맵게'],
        ),
        'Cho tôi một phần thịt heo xào, ít cay.',
        days: 3,
        score: 90,
        cleared: 2,
      ),
    ];
  }

  static String _meaning(Tr t) => t[AppSession.language] ?? t['en']!;

  static const Tr _moksal = {
    'vi': 'thịt nạc vai',
    'en': 'pork shoulder',
    'fil': 'kasim ng baboy',
    'km': 'សាច់ស្មាជ្រូក',
  };

  static const Tr _jeyuk = {
    'vi': 'thịt heo xào cay',
    'en': 'spicy stir-fried pork',
    'fil': 'maanghang na ginisang baboy',
    'km': 'សាច់ជ្រូកឆាហឹរ',
  };
}
