import 'package:flutter/foundation.dart' show ValueNotifier;

import '../../app/session.dart';
import '../login/auth_api.dart';
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

  /// 서버(review_cards.order_data)에 저장할 값. 시나리오·메뉴와 그룹별 고른 카드 이름.
  Map<String, Object?> toJson() => {
    'scenario': scenario.id,
    'menu': scenario.menu,
    'menu_meaning': tr(scenario.menuMeaning),
    'labels': [
      for (var g = 0; g < groups.length; g++)
        [for (final o in _picked(g)) o.label],
    ],
  };

  /// [toJson]으로 저장한 값을 되살립니다. 메뉴판 레시피·여러 메뉴 주문처럼 같은 카드로
  /// 다시 만들 수 없으면 null (복습 2·3단계는 저장한 문장을 그대로 씁니다).
  static ScenarioOrder? fromJson(Object? json, {required String sentence}) {
    if (json is! Map) return null;
    try {
      final menu = json['menu'] as String?;
      var scenario = Scenario.byId(json['scenario'] as String?);
      if (menu != null) {
        scenario = scenario.forMenu(
          menu,
          meaning: json['menu_meaning'] as String?,
        );
      }
      final groups = scenario.groupsFor(const {});
      final labels = [
        for (final l in json['labels'] as List)
          [for (final s in l as List) '$s'],
      ];
      if (labels.length != groups.length) return null;
      final order = ScenarioOrder(
        scenario: scenario,
        groups: groups,
        selected: [
          for (var g = 0; g < groups.length; g++)
            {
              for (final (i, o) in groups[g].options.indexed)
                if (labels[g].contains(o.label)) i,
            },
        ],
      );
      return order.sentence == sentence ? order : null;
    } catch (_) {
      return null;
    }
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

  List<List<ScenarioOption>> get _pickedAll => [
    for (var g = 0; g < groups.length; g++) _picked(g),
  ];

  /// 고른 카드로 만든 문장 (문장 만들기 화면의 자체 조립과 같은 규칙).
  String get sentence => scenario.sentenceFor(groups, _pickedAll);

  /// 서버 없이 만드는 모국어 뜻.
  String get meaning => scenario.meaningFor(groups, _pickedAll);

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

  /// 2단계: 카드 하나만 바꿉니다 (마지막으로 바꿀 수 있는 자리, 예: 덜 맵게 → 보통으로).
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
    this._meaning,
    required this.order,
    required this.next,
    this.score,
    this.cleared = 0,
  });

  final String id;

  /// 미션 때 말한 문장 그대로 (서버가 다듬은 문장일 수 있음).
  final String sentence;

  /// 모국어 뜻. 저장한 뜻이 없으면(시연 문장) 카드 조합으로 지금 언어에 맞게 만듭니다.
  String get meaning => _meaning ?? order?.meaning ?? '';
  final String? _meaning;
  final ScenarioOrder? order;

  /// 다음 복습 날.
  DateTime next;

  /// 마지막 발음 점수 (없으면 아직 채점 전)
  int? score;

  /// 끝낸 단계 수 (0~3).
  int cleared;

  Scenario get scenario => order?.scenario ?? restaurant;

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
///
/// 로그인하면 서버(review_cards, GET·POST /me/reviews)에 저장하고 [load]로 불러옵니다.
/// 로그인 없이 둘러볼 때는 시연 데이터를 보여 주고 저장하지 않습니다.
abstract final class ReviewStore {
  static final items = ValueNotifier<List<ReviewItem>>(_demo());

  static int _seq = 0;

  /// 로그인했을 때: 서버에 저장된 내 복습 목록으로 바꿉니다.
  /// 불러오는 동안 새로 넣은 문장은 남기고 서버에도 올립니다.
  static Future<void> load() async {
    if (!AppSession.loggedIn) return;
    items.value = [];
    try {
      final json = await AuthApi.reviews();
      final saved = [
        for (final r in json['reviews'] as List)
          _fromJson(r as Map<String, dynamic>),
      ];
      final names = {for (final i in saved) i.sentence};
      final added = [
        for (final i in items.value)
          if (!names.contains(i.sentence)) i,
      ];
      items.value = [...added, ...saved];
      added.forEach(_push);
    } on AuthException {
      // 서버에 못 붙으면 빈 목록. 새로 하는 문장은 그대로 쌓이고 올리기를 시도합니다.
    }
  }

  static ReviewItem _fromJson(Map<String, dynamic> r) {
    final sentence = r['sentence'] as String;
    return ReviewItem(
      id: r['id'] as String,
      sentence: sentence,
      meaning: r['meaning'] as String? ?? '',
      order: ScenarioOrder.fromJson(r['order'], sentence: sentence),
      next:
          DateTime.tryParse(r['next_review_at'] as String)?.toLocal() ??
          DateTime.now(),
      score: r['score'] as int?,
      cleared: r['cleared'] as int? ?? 0,
    );
  }

  /// 서버에 저장합니다 (같은 문장이면 진행 상태만 바뀜). 실패해도 화면은 그대로.
  static Future<void> _push(ReviewItem i) async {
    if (!AppSession.loggedIn) return;
    try {
      await AuthApi.saveReview({
        'sentence': i.sentence,
        'meaning': i.meaning,
        'order': i.order?.toJson(),
        'score': i.score,
        'cleared': i.cleared,
        'next_review_at': i.next.toUtc().toIso8601String(),
      });
    } on AuthException {
      // 다음 로그인 때 다시 불러오면 서버 값으로 맞춰집니다.
    }
  }

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
        _push(i);
        return;
      }
    }
    final item = ReviewItem(
      id: 'mine-${_seq++}',
      sentence: sentence,
      meaning: meaning,
      order: order,
      score: score,
      next: DateTime.now(),
    );
    items.value = [item, ...list];
    _push(item);
  }

  /// 복습 [stage]를 끝냈을 때. 다음 단계로 넘기고 다음 복습 날을 정합니다.
  static void complete(String id, ReviewStage stage, {int? score}) {
    final list = items.value;
    for (final i in list) {
      if (i.id != id) continue;
      if (i.cleared < stage.number) i.cleared = stage.number;
      if (score != null) i.score = score;
      i.next = DateTime.now().add(Duration(days: stage.waitDays));
      _push(i);
    }
    items.value = [...list];
  }

  /// 테스트용: 시연 데이터로 되돌립니다.
  static void reset() => items.value = _demo();

  static List<ReviewItem> _demo() {
    final now = DateTime.now();
    // 뜻은 비워 두면 보여 줄 때의 모국어로 만들어요 (온보딩에서 언어를 바꿔도 따라감).
    ReviewItem demo(
      String id,
      ScenarioOrder order, {
      required int days,
      required int score,
      int cleared = 0,
    }) => ReviewItem(
      id: id,
      sentence: order.sentence,
      order: order,
      next: now.add(Duration(days: days)),
      score: score,
      cleared: cleared,
    );

    return [
      demo(
        'demo-1',
        ScenarioOrder.fromLabels(
          restaurant.withMenu('삼겹살', meaning: _meaning(_samgyeop)),
          ['2인분'],
        ),
        days: 0,
        score: 76,
      ),
      demo(
        'demo-2',
        ScenarioOrder.fromLabels(restaurant, ['2인분', '덜 맵게']),
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
        days: 3,
        score: 90,
        cleared: 2,
      ),
    ];
  }

  static String _meaning(Tr t) => tr(t);

  static const Tr _samgyeop = {
    'vi': 'thịt ba chỉ',
    'en': 'pork belly',
    'fil': 'liempo',
    'km': 'សាច់ជ្រូកបីជាន់',
  };

  static const Tr _jeyuk = {
    'vi': 'thịt heo xào cay',
    'en': 'spicy stir-fried pork',
    'fil': 'maanghang na ginisang baboy',
    'km': 'សាច់ជ្រូកឆាហឹរ',
  };
}
