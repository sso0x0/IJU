import '../../app/diet.dart';
import '../../app/extra_translations.dart';
import '../../app/session.dart';
import 'menu_ingredients.dart';

export 'menu_ingredients.dart'
    show
        RecipeMatch,
        Recipe,
        ingredientsFor,
        extraWord,
        isExtra,
        isSideOrder,
        isCookedDish,
        isDrink,
        isRawMeat;

/// 학습자 언어별 번역. 키는 서버 Language 값(vi, en, fil, km).
typedef Tr = Map<String, String>;

/// 지금 사용자 언어로 고릅니다. 맵에 없으면 새 언어 번역표([extraTranslations])에서
/// 영어 원문으로 찾고, 그래도 없으면(ko 등) 영어로.
String tr(Tr m) {
  final lang = AppSession.language;
  final en = m['en'];
  return m[lang] ?? extraTranslations[en]?[lang] ?? en ?? '';
}

/// 재료 주의 표시. 칩과 ⓘ 안내에 색으로 보여 줍니다.
enum Caution {
  /// 빨강: 이 메뉴에 들어 있어요.
  contains,

  /// 노랑: 국물·양념에 숨어 있을 수 있어요. 빼 달라고 해도 완전히 빠지지 않을 수 있습니다.
  hidden,
}

/// 받침이 있는 한글 낱말인지 (서버 compose.py `_has_batchim`과 같음).
bool hasBatchim(String word) {
  if (word.isEmpty) return false;
  final c = word.codeUnitAt(word.length - 1);
  return c >= 0xAC00 && c <= 0xD7A3 && (c - 0xAC00) % 28 != 0;
}

/// 두 낱말을 잇는 ‘-랑/이랑’. 돼지고기 → 돼지고기랑, 버섯 → 버섯이랑
String withAnd(String word) => word + (hasBatchim(word) ? '이랑' : '랑');

/// ‘-는/은’. 돼지고기 → 돼지고기는, 버섯 → 버섯은
String withTopic(String word) => word + (hasBatchim(word) ? '은' : '는');

/// 여러 낱말을 ‘-랑’으로 잇기. 치즈, 라면사리 → 치즈랑 라면사리
String joinAnd(List<String> words) => [
  for (var i = 0; i < words.length; i++)
    i < words.length - 1 ? withAnd(words[i]) : words[i],
].join(' ');

/// 한 번에 주문하는 메뉴 하나 ([Scenario.forOrder]).
class OrderLine {
  const OrderLine(this.name, this.meaning, {this.extra = false});

  /// 메뉴판에 적힌 이름 (치즈 추가, 김치찌개)
  final String name;
  final Tr meaning;

  /// ‘치즈 추가해 주세요’로 시키는 것 (○○ 추가·사리)
  final bool extra;

  /// 문장에 들어갈 말: ‘치즈 추가’ → ‘치즈’
  String get word => extra ? extraWord(name) : name;
}

/// 문장 틀에서 그룹이 들어가는 문장.
enum SentenceKind {
  /// 첫 문장 ‘김치찌개 1인분 … 주세요.’
  order,

  /// 여러 메뉴를 한 번에 주문할 때 메뉴마다 따로 붙는 ‘김치찌개는 덜 맵게 해 주세요.’
  style,

  /// 따로 붙는 ‘돼지고기는 빼 주세요.’
  without,

  /// 따로 붙는 ‘고기 육수 들어가요?’
  ask,
}

/// 메뉴에 들어가는 재료 하나. 사용자 식단·종교와 맞지 않으면 문장 만들기에서
/// 보이는 재료는 ‘빼 주세요’, 숨은 재료([hidden])는 ‘들어가요?’ 칩에 주의 표시를 합니다.
class Ingredient {
  const Ingredient(
    this.label,
    this.meaning, {
    this.tags = const {},
    this.hidden = false,
    this.info,
    this.matchAll = false,
    this.item,
    this.main = false,
  });

  /// 메뉴 이름에 든 주재료 (새우튀김의 새우, 삼겹살의 돼지고기).
  /// 빼 달라고 할 수 없으니 칩 대신 ‘이 메뉴에 들어가요’로 안내만 합니다.
  final bool main;

  /// 주재료로 ([main]).
  Ingredient get asMain => Ingredient(
    label,
    meaning,
    tags: tags,
    info: info,
    matchAll: matchAll,
    item: item,
    main: true,
  );

  final String label;
  final Tr meaning;
  final Set<FoodTag> tags;

  /// 여러 메뉴를 한 번에 주문할 때 이 재료가 든 메뉴 (‘김치찌개는 돼지고기 빼 주세요’).
  final String? item;

  /// [item] 메뉴의 재료로.
  Ingredient forItem(String item) => Ingredient(
    label,
    meaning,
    tags: tags,
    hidden: hidden,
    info: info,
    matchAll: matchAll,
    item: item,
    main: main,
  );

  /// 국물·양념처럼 눈에 안 보여 빼 달라기보다 물어봐야 하는 재료.
  final bool hidden;
  final Tr? info;

  /// true면 [tags]를 모두 피하는 식단만 걸립니다. 무슨 고기인지 모르는 ‘고기’는
  /// 채식(고기 전부 피함)만 ‘고기는 빼 주세요’로 고르고, 종교(돼지고기만 피함)는
  /// ‘돼지고기 들어가요?’로 따로 묻습니다.
  final bool matchAll;

  /// 국물·양념 쪽에 든 같은 재료 (‘들어가요?’로 묻기).
  Ingredient get asHidden =>
      Ingredient(label, meaning, tags: tags, hidden: true, matchAll: matchAll);

  /// 이 재료를 피해야 하는 식단 ([diets] 중에서).
  List<Diet> conflictsWith(Iterable<Diet> diets) => matchAll
      ? [
          for (final d in diets)
            if (tags.every(d.avoid.contains)) d,
        ]
      : Diet.conflicts(tags, diets);
}

/// 문장 조립에서 고를 수 있는 키워드 하나.
///
/// [label]은 칩과 서버로 보내는 단어, [token]은 문장 카드에 들어갈 모양
/// (서버 compose.py의 규칙과 같게 맞춥니다).
class ScenarioOption {
  const ScenarioOption(
    this.label,
    this.meaning, {
    String? token,
    this.info,
    this.caution,
    this.conflicts = const [],
  }) : token = token ?? label;

  final String label;
  final String token;
  final Tr meaning;

  /// 칩의 ⓘ를 누르면 보여 줄 재료 안내 (왜 들어가는지, 빼도 안전한지, 대신 물어볼 말).
  final Tr? info;
  final Caution? caution;

  /// 이 재료를 피해야 하는 사용자 식단·종교 (ⓘ 안내에 보여 줌).
  final List<Diet> conflicts;
}

class ScenarioGroup {
  const ScenarioGroup(
    this.title,
    this.sub,
    this.options, {
    this.required = true,
    this.initial,
    String? slot,
    this.rule,
    this.multi = false,
    this.kind = SentenceKind.order,
    this.initialAll = const {},
    this.item,
  }) : slot = slot ?? title;

  /// 여러 메뉴를 한 번에 주문할 때 이 그룹이 속한 메뉴 이름 (그 외에는 null).
  final String? item;

  /// 여러 메뉴 주문에 넣을 [item] 메뉴의 그룹. 처음에는 고르지 않습니다.
  /// [inline]이면 첫 문장(김치찌개 1인분이랑 …)에, 아니면 따로 한 문장(김치찌개는 덜 맵게 해 주세요)에.
  ScenarioGroup forItem(String item, {required bool inline}) => ScenarioGroup(
    title,
    sub,
    options,
    required: false,
    slot: slot,
    rule: rule,
    kind: inline ? SentenceKind.order : SentenceKind.style,
    item: item,
  );

  final String title;
  final Tr sub;
  final List<ScenarioOption> options;

  /// 문장 틀에서 이 자리 위에 붙는 짧은 이름 (예: '용도'). 없으면 [title].
  final String slot;

  /// 카드 모양이 바뀌는 이유(조사·어미)를 학습자 언어로 설명합니다.
  /// 예: 구이용 → 구이용으로. 바뀌지 않는 그룹은 null.
  final Tr? rule;

  /// false면 고르지 않아도 되고, 같은 칩을 다시 누르면 선택이 풀립니다.
  final bool required;
  final int? initial;

  /// true면 여러 개를 함께 고를 수 있습니다 (돼지고기 + 두부).
  final bool multi;

  /// 처음부터 골라 둘 옵션들 (multi 그룹, 식단에 맞지 않는 재료).
  final Set<int> initialAll;

  final SentenceKind kind;

  /// 첫 문장 ‘… 주세요.’ 뒤에 따로 한 문장을 만드는지 (돼지고기는 빼 주세요.).
  bool get separate => kind != SentenceKind.order;

  /// 이 그룹 문장을 끝내는 말.
  String get ending => kind == SentenceKind.ask ? '들어가요?' : '주세요.';

  /// 고른 카드들이 문장 속에 들어갈 모양. 여러 개면 앞 카드는 ‘-랑’으로 잇습니다.
  /// 돼지고기, 두부 → 돼지고기랑 / 두부는 빼
  List<String> tokensFor(List<ScenarioOption> picked) => [
    for (var i = 0; i < picked.length; i++)
      i < picked.length - 1 ? withAnd(picked[i].label) : picked[i].token,
  ];
}

/// AI 사장님 대사 한 턴과 손님 대답. [target]이 null이면 문장 조립에서 만든 문장.
class ScenarioTurn {
  const ScenarioTurn(
    this.ai,
    this.aiMeaning, {
    this.target,
    this.targetMeaning,
  });

  final String ai;
  final Tr aiMeaning;
  final String? target;
  final Tr? targetMeaning;
}

class Scenario {
  const Scenario({
    required this.id,
    required this.place,
    required this.menu,
    required this.menuMeaning,
    required this.groups,
    required this.turns,
    required this.tip,
    this.ingredients = const [],
    this.recipes = const [],
    this.lines = const [],
  });

  /// 여러 메뉴를 한 번에 주문할 때 메뉴 목록 ([forOrder]). 메뉴 하나짜리 시나리오는 비어 있음.
  final List<OrderLine> lines;

  /// 여러 메뉴를 한 문장으로 주문하는 시나리오인지.
  bool get isOrder => lines.isNotEmpty;

  /// 재료를 짐작하는 데 쓴 레시피 이름 (Supabase recipes 표). 화면에 ‘레시피 참고’로 보여 줍니다.
  final List<String> recipes;

  /// 메뉴 재료. 있으면 [groupsFor]가 ‘빼 주세요’·‘들어가요?’ 그룹을 붙입니다.
  final List<Ingredient> ingredients;

  /// 메뉴 이름에 든 주재료 (칩 없이 ‘들어가요’ 안내만).
  List<Ingredient> get mainIngredients => [
    for (final i in ingredients)
      if (i.main) i,
  ];

  /// 화면에 보여 줄 그룹: 시나리오 그룹 + 재료로 만든 ‘빼 주세요’·‘들어가요?’.
  /// [diets]와 맞지 않는 재료는 빨강(보이는 재료)·노랑(숨은 재료) 점으로 표시만 하고,
  /// 고르는 건 사용자에게 맡깁니다 (처음에는 아무것도 고르지 않음).
  List<ScenarioGroup> groupsFor(Set<Diet> diets) {
    ScenarioGroup? build(bool hidden, String? item) {
      final mine = [
        for (final i in ingredients)
          if (i.item == item) i,
      ];
      // ‘고기’를 피해야 하면 ‘돼지고기 들어가요?’처럼 그 안에 드는 질문에는 따로 표시하지 않습니다.
      final removedTags = {
        for (final i in mine)
          if (!i.hidden && i.matchAll && i.conflictsWith(diets).isNotEmpty)
            ...i.tags,
      };
      final items = [
        for (final i in mine)
          if (i.hidden == hidden && !i.main) i,
      ];
      if (items.isEmpty) return null;
      final conflicts = [
        for (final i in items)
          // 고기 육수는 고기를 빼도 국물에 남으니 계속 묻습니다.
          hidden && i.label.endsWith('고기') && i.tags.every(removedTags.contains)
              ? <Diet>[]
              : i.conflictsWith(diets),
      ];
      final options = [
        for (final (n, i) in items.indexed)
          ScenarioOption(
            i.label,
            i.meaning,
            // 메뉴가 여럿이면 ‘김치찌개는 돼지고기 빼 주세요’라 재료 뒤에 ‘-는’을 붙이지 않습니다.
            token: hidden
                ? i.label
                : (item == null ? '${withTopic(i.label)} 빼' : '${i.label} 빼'),
            info: i.info,
            conflicts: conflicts[n],
            caution: conflicts[n].isEmpty
                ? null
                : (hidden ? Caution.hidden : Caution.contains),
          ),
      ];
      return hidden
          ? ScenarioGroup(
              '들어가요?',
              _askSub,
              options,
              required: false,
              multi: true,
              kind: SentenceKind.ask,
              slot: '질문',
              rule: _askRule,
              item: item,
            )
          : ScenarioGroup(
              '빼 주세요',
              _withoutSub,
              options,
              required: false,
              multi: true,
              kind: SentenceKind.without,
              slot: '빼기',
              rule: item == null ? _withoutRule : null,
              item: item,
            );
    }

    // 메뉴 순서대로 (메뉴 하나면 item이 모두 null이라 한 번만)
    final items = <String?>[];
    for (final i in ingredients) {
      if (!items.contains(i.item)) items.add(i.item);
    }
    return [
      ...groups,
      for (final item in items) ...[?build(false, item), ?build(true, item)],
    ];
  }

  /// 서버 store_type과 같은 값 (restaurant, side_dish)
  final String id;

  /// 연습 화면 부제목에 쓰는 가게 이름
  final String place;
  final String menu;
  final Tr menuMeaning;
  final List<ScenarioGroup> groups;
  final List<ScenarioTurn> turns;

  /// 서버 조언이 오기 전·서버가 없을 때 보여 줄 문법 조언 (‘ ’ 안은 굵게)
  final String tip;

  static Scenario byId(String? id) =>
      all.firstWhere((s) => s.id == id, orElse: () => restaurant);

  /// 메뉴판에서 고른 메뉴로 바꾼 시나리오. 옵션·대사는 그대로 두고 메뉴만 바꿉니다.
  /// [meaning]은 메뉴판 인식이 돌려준 모국어 뜻(이미 사용자 언어)입니다.
  /// 재료가 있는 시나리오(식당)는 원래 메뉴(김치찌개) 재료 대신 메뉴 이름으로
  /// 재료를 다시 짐작합니다 ([ingredientsFor]). 스팸두부찌개 → 스팸·두부·고기 육수…
  Scenario withMenu(String name, {String? meaning}) {
    if (name == menu) return this;
    final m = (meaning == null || meaning.trim().isEmpty) ? name : meaning;
    return Scenario(
      id: id,
      place: place,
      menu: name,
      menuMeaning: {'en': m, AppSession.language: m},
      groups: groups,
      turns: turns,
      tip: tip,
      ingredients: ingredients.isEmpty ? const [] : ingredientsFor(name),
    );
  }

  /// 서버가 찾아 준 레시피 재료를 더한 시나리오. 재료가 없는 시나리오(고기·음료)는 그대로.
  Scenario withRecipe(RecipeMatch match) {
    // 손으로 쓴 시연 메뉴(김치찌개)의 재료는 ⓘ 안내까지 있어 그대로 둡니다.
    if (ingredients.isEmpty ||
        match.isEmpty ||
        isDessert(menu) ||
        isRawMeat(menu) ||
        ingredients.any((i) => i.info != null)) {
      return this;
    }
    return Scenario(
      id: id,
      place: place,
      menu: menu,
      menuMeaning: menuMeaning,
      groups: groups,
      turns: turns,
      tip: tip,
      ingredients: ingredientsFor(menu, recipe: match),
      recipes: [for (final r in match.recipes) r.name],
    );
  }

  /// 메뉴판에서 고른 메뉴에 맞는 시나리오. 메뉴 이름을 보고 문장 틀을 고릅니다.
  ///
  /// - 술·음료(소주, 맥주, 콜라…): ‘소주 한 병 주세요’ — 몇 병/몇 잔만 고릅니다.
  /// - 삼겹살·목살 같은 고기도 ‘삼겹살 2인분 주세요’처럼 인분으로 셉니다.
  /// - 맵기는 찌개·볶음처럼 매울 수 있는 요리에만 둡니다.
  Scenario forMenu(String name, {String? meaning}) {
    if (name == menu) return this;
    if (isDessert(name)) return _dessertScenario(name, meaning);
    if (isDrink(name)) return _drinkScenario(name, meaning);
    if (isExtra(name)) return forOrder([(name, meaning)]);
    if (isSideOrder(name)) return _sideScenario(name, meaning);
    final s = withMenu(name, meaning: meaning);
    if (s.id != 'restaurant') return s;
    if (isRawMeat(name)) return _meatScenario(s);
    // 치킨 한 마리·피자 한 판·김밥 한 줄처럼 인분으로 세지 않는 요리
    final counter = counterFor(name);
    final spicy = isSpicyDish(name);
    if (counter == null && spicy) return s;
    return Scenario(
      id: s.id,
      place: s.place,
      menu: s.menu,
      menuMeaning: s.menuMeaning,
      groups: [
        for (final g in s.groups)
          if (g.title == '몇 인분' && counter != null)
            countGroup(counter)
          else if (g.title != '맵기' || spicy)
            g,
      ],
      turns: s.turns,
      tip: s.tip,
      ingredients: s.ingredients,
    );
  }

  /// 식당에서 굽는 고기 (삼겹살, 목살, 갈비…): ‘삼겹살 2인분 주세요’.
  /// 고기 자체가 메뉴라 빼 달라거나 들어가는지 묻는 문장은 붙이지 않습니다.
  static Scenario _meatScenario(Scenario s) => Scenario(
    id: s.id,
    place: s.place,
    menu: s.menu,
    menuMeaning: s.menuMeaning,
    groups: [
      for (final g in s.groups)
        if (g.title == '몇 인분') g,
    ],
    turns: s.turns,
    tip: '고기는 ‘1인분, 2인분’으로 시켜요. 삼겹살 2인분 주세요',
    // 삼겹살 → 돼지고기처럼 주재료만 안내합니다.
    ingredients: mainIngredientsFor(s.menu),
  );

  /// 케이크·빵 같은 디저트: ‘케이크 한 개 주세요’. 빼 달라는 말 없이
  /// 계란·우유·젤라틴이 들어가는지만 묻습니다.
  static Scenario _dessertScenario(String name, String? meaning) {
    final m = (meaning == null || meaning.trim().isEmpty) ? name : meaning;
    return Scenario(
      id: restaurant.id,
      place: restaurant.place,
      menu: name,
      menuMeaning: {'en': m, AppSession.language: m},
      groups: [countGroup('개')],
      turns: restaurant.turns,
      tip: '케이크·빵은 ‘한 개, 두 개’로 세요. 케이크 한 개 주세요',
      ingredients: dessertIngredients(name),
    );
  }

  /// 공기밥 같은 곁들임: ‘공기밥 하나 주세요’. 재료를 묻는 문장은 붙이지 않습니다.
  static Scenario _sideScenario(String name, String? meaning) {
    final m = (meaning == null || meaning.trim().isEmpty) ? name : meaning;
    return Scenario(
      id: restaurant.id,
      place: restaurant.place,
      menu: name,
      menuMeaning: {'en': m, AppSession.language: m},
      groups: const [pieceGroup],
      turns: restaurant.turns,
      tip: '공기밥처럼 하나씩 더 시킬 때는 ‘하나, 두 개’로 세요. 공기밥 하나 주세요',
    );
  }

  static Scenario _drinkScenario(String name, String? meaning) {
    final m = (meaning == null || meaning.trim().isEmpty) ? name : meaning;
    return Scenario(
      id: restaurant.id,
      place: restaurant.place,
      menu: name,
      menuMeaning: {'en': m, AppSession.language: m},
      groups: [isByGlass(name) ? glassGroup : bottleGroup],
      turns: restaurant.turns,
      tip: isByGlass(name)
          ? '잔에 담아 주는 건 ‘한 잔, 두 잔’으로 세요. 생맥주 한 잔 주세요'
          : '병에 든 술·음료는 ‘한 병, 두 병’으로 세요. 소주 한 병 주세요',
    );
  }

  /// 메뉴판에서 여러 메뉴를 고르면 한 번에 주문하는 문장으로 만듭니다.
  ///
  ///   김치찌개 1인분이랑 공기밥 하나랑 콜라 주세요.   ← 메뉴마다 첫 그룹(몇 인분·몇 개·몇 병)
  ///   김치찌개는 덜 맵게 해 주세요.                   ← 나머지 그룹(맵기·용도·손질)은 메뉴마다 따로
  ///   치즈랑 라면사리 추가해 주세요.                  ← ○○ 추가·사리
  ///   돼지고기는 빼 주세요. 고기 육수 들어가요?        ← 모든 메뉴의 재료를 합쳐서
  ///
  /// 처음에는 개수·맵기 모두 고르지 않아 ‘김치찌개랑 콜라 주세요.’로 시작합니다.
  /// [menus]는 (메뉴 이름, 모국어 뜻), [recipes]는 메뉴별로 서버가 찾아 준 레시피입니다.
  Scenario forOrder(
    List<(String, String?)> menus, {
    Map<String, RecipeMatch> recipes = const {},
  }) {
    final lines = <OrderLine>[];
    final groups = <ScenarioGroup>[];
    final ingredients = <Ingredient>[];
    final recipeNames = <String>[];
    for (final (name, meaning) in menus) {
      final m = (meaning == null || meaning.trim().isEmpty) ? name : meaning;
      if (isExtra(name)) {
        lines.add(
          OrderLine(name, {'en': m, AppSession.language: m}, extra: true),
        );
        continue;
      }
      var s = forMenu(name, meaning: meaning);
      if (recipes[name] case final r?) s = s.withRecipe(r);
      lines.add(OrderLine(name, s.menuMeaning));
      recipeNames.addAll(s.recipes);
      for (final (i, g) in s.groups.indexed) {
        // 반찬가게 ‘하나 더’처럼 다른 메뉴를 고르는 그룹은 이미 여러 메뉴를 골랐으니 뺍니다.
        if (g.multi) continue;
        groups.add(g.forItem(name, inline: i == 0));
      }
      // 메뉴마다 따로 묻습니다: ‘김치찌개는 돼지고기 빼 주세요’, ‘떡볶이에 고기 들어가요?’
      ingredients.addAll(s.ingredients.map((i) => i.forItem(name)));
    }
    final meanings = lines.map((l) => tr(l.meaning)).join(', ');
    return Scenario(
      id: id,
      place: place,
      menu: lines.map((l) => l.name).join(' · '),
      menuMeaning: {'en': meanings, AppSession.language: meanings},
      groups: groups,
      turns: turns,
      tip: lines.length > 1
          ? '여러 가지를 같이 시킬 때는 ‘-랑’으로 이어요. 김치찌개랑 콜라 주세요'
          : '더 넣어 달라고 할 때는 ‘추가해 주세요’라고 해요. 치즈 추가해 주세요',
      ingredients: ingredients,
      recipes: recipeNames,
      lines: lines,
    );
  }

  /// 고른 카드로 만든 문장. [picked]는 [groups]마다 고른 옵션입니다.
  /// 문장 만들기 화면의 자체 조립과 복습(카드 바꾸기)이 같이 씁니다.
  String sentenceFor(
    List<ScenarioGroup> groups,
    List<List<ScenarioOption>> picked,
  ) {
    String separate(int g) =>
        '${groups[g].tokensFor(picked[g]).join(' ')} ${groups[g].ending}';
    final tail = [
      for (var g = 0; g < groups.length; g++)
        if (groups[g].kind == SentenceKind.without ||
            groups[g].kind == SentenceKind.ask)
          if (picked[g].isNotEmpty)
            '${itemPrefix(groups[g]) ?? ''}${separate(g)}',
    ];
    if (!isOrder) {
      final main = [
        menu,
        for (var g = 0; g < groups.length; g++)
          if (!groups[g].separate) ...groups[g].tokensFor(picked[g]),
      ];
      return ['${main.join(' ')} 주세요.', ...tail].join(' ');
    }
    final dishes = [
      for (final l in lines)
        if (!l.extra) l,
    ];
    final words = <String>[];
    for (final (k, l) in dishes.indexed) {
      final item = [
        l.name,
        for (var g = 0; g < groups.length; g++)
          if (groups[g].item == l.name && groups[g].kind == SentenceKind.order)
            ...groups[g].tokensFor(picked[g]),
      ];
      if (k < dishes.length - 1) item.last = withAnd(item.last);
      words.addAll(item);
    }
    final extras = [
      for (final l in lines)
        if (l.extra) l.word,
    ];
    return [
      if (words.isNotEmpty) '${words.join(' ')} 주세요.',
      for (var g = 0; g < groups.length; g++)
        if (groups[g].kind == SentenceKind.style && picked[g].isNotEmpty)
          '${withTopic(groups[g].item!)} ${separate(g)}',
      if (extras.isNotEmpty) '${joinAnd(extras)} 추가해 주세요.',
      ...tail,
    ].join(' ');
  }

  /// 메뉴가 여럿일 때 빼기·질문 문장 앞에 붙는 메뉴: ‘김치찌개는 ’, ‘김치찌개에 ’.
  static String? itemPrefix(ScenarioGroup g) => switch ((g.item, g.kind)) {
    (final item?, SentenceKind.without) => '${withTopic(item)} ',
    (final item?, SentenceKind.ask) => '$item에 ',
    _ => null,
  };

  /// 서버 없이 만드는 간단 번역 ([sentenceFor]와 같은 카드로).
  String meaningFor(
    List<ScenarioGroup> groups,
    List<List<ScenarioOption>> picked,
  ) {
    List<ScenarioOption> of(SentenceKind kind) => [
      for (var g = 0; g < groups.length; g++)
        if (groups[g].kind == kind) ...picked[g],
    ];
    if (!isOrder) {
      return localMeaning(
        of(SentenceKind.order),
        without: of(SentenceKind.without),
        ask: of(SentenceKind.ask),
      );
    }
    String itemMeaning(OrderLine l) => [
      for (var g = 0; g < groups.length; g++)
        if (groups[g].item == l.name && groups[g].kind == SentenceKind.order)
          ...picked[g].map((o) => tr(o.meaning)),
      tr(l.meaning),
      for (var g = 0; g < groups.length; g++)
        if (groups[g].item == l.name && groups[g].kind == SentenceKind.style)
          ...picked[g].map((o) => tr(o.meaning)),
    ].join(' ');
    final items = [
      for (final l in lines)
        l.extra ? tr(_extra).replaceFirst('{}', tr(l.meaning)) : itemMeaning(l),
    ];
    String fill(Map<String, String> t, List<ScenarioOption> os) =>
        tr(t).replaceFirst('{}', os.map((o) => tr(o.meaning)).join(', '));
    String itemFill(int g) {
      final t = groups[g].kind == SentenceKind.ask ? _ask : _without;
      final line = lines.where((l) => l.name == groups[g].item).firstOrNull;
      final text = fill(t, picked[g]);
      return line == null ? text : '(${tr(line.meaning)}) $text';
    }

    return [
      tr(_please).replaceFirst('{}', items.join(', ')),
      for (var g = 0; g < groups.length; g++)
        if ((groups[g].kind == SentenceKind.without ||
                groups[g].kind == SentenceKind.ask) &&
            picked[g].isNotEmpty)
          itemFill(g),
    ].join(' ');
  }

  static const _extra = {
    'vi': 'thêm {}',
    'en': 'extra {}',
    'fil': 'dagdag na {}',
    'km': 'បន្ថែម{}',
  };

  static const all = [restaurant, sideDish];

  /// 서버 없이 만드는 간단 번역. 정확한 번역은 POST /ai/compose가 돌려줍니다.
  /// [without]은 따로 붙는 ‘빼 주세요’, [ask]는 ‘들어가요?’ 문장의 카드입니다.
  String localMeaning(
    List<ScenarioOption> picked, {
    List<ScenarioOption> without = const [],
    List<ScenarioOption> ask = const [],
  }) {
    final parts = [
      if (picked.isNotEmpty) tr(picked.first.meaning),
      tr(menuMeaning),
      if (picked.length > 1)
        picked.skip(1).map((o) => tr(o.meaning)).join(', '),
    ];
    final please = tr(_please).replaceFirst('{}', parts.join(' '));
    String fill(Map<String, String> t, List<ScenarioOption> os) =>
        tr(t).replaceFirst('{}', os.map((o) => tr(o.meaning)).join(', '));
    return [
      please,
      if (without.isNotEmpty) fill(_without, without),
      if (ask.isNotEmpty) fill(_ask, ask),
    ].join(' ');
  }

  static const _ask = {
    'vi': 'Có {} không?',
    'en': 'Is there {} in it?',
    'fil': 'May {} po ba?',
    'km': 'មាន{}ទេ?',
  };

  static const _please = {
    'vi': 'Cho tôi {}.',
    'en': '{}, please.',
    'fil': 'Pabili po ng {}.',
    'km': 'សូមឲ្យខ្ញុំ {}។',
  };

  static const _without = {
    'vi': 'Đừng cho {} nhé.',
    'en': 'No {}, please.',
    'fil': 'Huwag na pong lagyan ng {}.',
    'km': 'សូមកុំដាក់{}។',
  };
}

// ---------------------------------------------------------------- 재료 그룹 문구

const Tr _withoutSub = {
  'vi': 'Không cho vào',
  'en': 'Leave out',
  'fil': 'Huwag lagyan',
  'km': 'កុំដាក់',
};

const Tr _withoutRule = {
  'vi': '“-는 빼 주세요” nghĩa là “đừng cho … vào”. Nối hai thứ bằng “-랑”: 돼지고기랑 두부는 빼 주세요.',
  'en': '“-는 빼 주세요” means “please leave out …”. Join two with “-랑”: 돼지고기랑 두부는 빼 주세요.',
  'fil': 'Ang “-는 빼 주세요” ay “pakitanggal po ang …”. Pagdugtungin ang dalawa gamit ang “-랑”: 돼지고기랑 두부는 빼 주세요.',
  'km':
      '“-는 빼 주세요” មានន័យថា “សូមកុំដាក់ …”។ ភ្ជាប់ពីរដោយ “-랑”៖ 돼지고기랑 두부는 빼 주세요។',
};

const Tr _askSub = {
  'vi': 'Hỏi có … không',
  'en': 'Ask if it has',
  'fil': 'Itanong kung may',
  'km': 'សួរថាមាន…ទេ',
};

const Tr _askRule = {
  'vi': '“… 들어가요?” nghĩa là “Có … trong món này không?”. Mỗi quán nấu khác nhau nên hãy hỏi.',
  'en': '“… 들어가요?” means “Is there … in it?”. Every restaurant cooks differently, so ask.',
  'fil': 'Ang “… 들어가요?” ay “May … po ba rito?”. Iba-iba ang luto ng bawat kainan, kaya magtanong.',
  'km': '“… 들어가요?” មានន័យថា “មាន … ក្នុងនេះទេ?”។ ហាងនីមួយៗធ្វើខុសគ្នា ដូច្នេះសូមសួរ។',
};

// ---------------------------------------------------------------- 공통

const _howMuch = {
  'vi': 'Bao nhiêu',
  'en': 'How much',
  'fil': 'Gaano karami',
  'km': 'ប៉ុន្មាន',
};

// ---------------------------------------------------------------- 식당

const restaurant = Scenario(
  id: 'restaurant',
  place: '식당',
  tip: '빼고 싶은 재료는 ‘-는 빼 주세요’로 말해요. 돼지고기는 빼 주세요',
  menu: '김치찌개',
  menuMeaning: {
    'vi': 'canh kim chi',
    'en': 'kimchi stew',
    'fil': 'kimchi stew',
    'km': 'ស៊ុបគីមឈី',
  },
  groups: [
    ScenarioGroup(
      '몇 인분',
      {
        'vi': 'Mấy phần',
        'en': 'How many servings',
        'fil': 'Ilang order',
        'km': 'ប៉ុន្មានចាន',
      },
      initial: 0,
      [
        ScenarioOption('1인분', {
          'vi': '1 phần',
          'en': '1 serving of',
          'fil': '1 order ng',
          'km': '១ចាន',
        }),
        ScenarioOption('2인분', {
          'vi': '2 phần',
          'en': '2 servings of',
          'fil': '2 order ng',
          'km': '២ចាន',
        }),
        ScenarioOption('3인분', {
          'vi': '3 phần',
          'en': '3 servings of',
          'fil': '3 order ng',
          'km': '៣ចាន',
        }),
      ],
    ),
    ScenarioGroup(
      '맵기',
      {'vi': 'Độ cay', 'en': 'Spiciness', 'fil': 'Anghang', 'km': 'កម្រិតហឹរ'},
      // 맵기는 처음에 고르지 않고, 원할 때만 눌러서 붙입니다.
      required: false,
      rule: {
        'vi': '“-게 해 주세요” nghĩa là “làm cho … giúp tôi”.',
        'en': '“-게 해 주세요” means “make it …, please”.',
        'fil': 'Ang “-게 해 주세요” ay “gawin pong …”.',
        'km': '“-게 해 주세요” មានន័យថា “សូមធ្វើឲ្យ …”។',
      },
      [
        ScenarioOption('덜 맵게', token: '덜 맵게 해', {
          'vi': 'ít cay',
          'en': 'less spicy',
          'fil': 'hindi masyadong maanghang',
          'km': 'កុំហឹរពេក',
        }),
        ScenarioOption('보통으로', token: '보통으로 해', {
          'vi': 'cay vừa',
          'en': 'regular spicy',
          'fil': 'katamtamang anghang',
          'km': 'ហឹរធម្មតា',
        }),
        ScenarioOption('아주 맵게', token: '아주 맵게 해', {
          'vi': 'thật cay',
          'en': 'extra spicy',
          'fil': 'sobrang anghang',
          'km': 'ហឹរខ្លាំង',
        }),
      ],
    ),
  ],
  // 식단·종교에 맞지 않는 재료는 groupsFor가 ‘빼 주세요’·‘들어가요?’ 칩에 점으로 표시합니다.
  ingredients: [
    Ingredient(
      '돼지고기',
      {'vi': 'thịt heo', 'en': 'pork', 'fil': 'baboy', 'km': 'សាច់ជ្រូក'},
      tags: {FoodTag.pork},
      info: {
        'vi': 'Canh kim chi thường nấu với thịt heo. Dù bỏ thịt, nước dùng vẫn có thể có vị heo, nên hãy hỏi thêm “고기 육수 들어가요?”. Bạn cũng có thể gọi 참치김치찌개 (canh kim chi cá ngừ).',
        'en': 'Kimchi stew is usually cooked with pork. Even without the meat, the broth may still have pork in it, so also ask “고기 육수 들어가요?”. You can also order 참치김치찌개 (tuna kimchi stew).',
        'fil': 'Karaniwang may baboy ang kimchi stew. Kahit tanggalin ang karne, maaaring may baboy pa rin ang sabaw, kaya itanong din ang “고기 육수 들어가요?”. Puwede ring umorder ng 참치김치찌개 (kimchi stew na may tuna).',
        'km': 'ស៊ុបគីមឈីជាធម្មតាដាក់សាច់ជ្រូក។ ទោះដកសាច់ចេញ ទឹកស៊ុបអាចនៅមានជ្រូក ដូច្នេះសូមសួរផង “고기 육수 들어가요?”។ អាចកុម្ម៉ង់ 참치김치찌개 (ស៊ុបគីមឈីត្រីធូណា) ក៏បាន។',
      },
    ),
    Ingredient(
      '두부',
      {'vi': 'đậu phụ', 'en': 'tofu', 'fil': 'tokwa', 'km': 'តៅហ៊ូ'},
      tags: {FoodTag.plant},
      info: {
        'vi': 'Đậu phụ làm từ đậu nành. Nếu bạn dị ứng đậu nành, nước dùng cũng có thể có nước tương hoặc tương đậu.',
        'en': 'Tofu is made from soybeans. If you are allergic to soy, the broth may also have soy sauce or soybean paste.',
        'fil': 'Gawa sa soybeans ang tokwa. Kung allergic ka sa soy, maaaring may toyo o soybean paste din ang sabaw.',
        'km': 'តៅហ៊ូធ្វើពីសណ្ដែកសៀង។ បើអ្នកអាលែកហ្ស៊ីសណ្ដែក ទឹកស៊ុបក៏អាចមានទឹកស៊ីអ៊ីវ ឬសៀងដែរ។',
      },
    ),
    Ingredient(
      '파',
      {
        'vi': 'hành lá',
        'en': 'green onion',
        'fil': 'dahon ng sibuyas',
        'km': 'ស្លឹកខ្ទឹម',
      },
      tags: {FoodTag.plant},
    ),
    Ingredient(
      '고기 육수',
      {
        'vi': 'nước hầm thịt',
        'en': 'meat broth',
        'fil': 'sabaw ng karne',
        'km': 'ទឹកស៊ុបសាច់',
      },
      tags: {FoodTag.pork, FoodTag.beef},
      hidden: true,
      info: {
        'vi': 'Nhiều quán nấu nước dùng bằng xương heo hoặc thịt bò. Không nhìn thấy được nên hãy hỏi.',
        'en': 'Many restaurants make the broth with pork bones or beef. You cannot see it, so ask.',
        'fil': 'Maraming kainan ang gumagawa ng sabaw mula sa buto ng baboy o baka. Hindi ito nakikita, kaya magtanong.',
        'km': 'ហាងជាច្រើនធ្វើទឹកស៊ុបពីឆ្អឹងជ្រូក ឬសាច់គោ។ មើលមិនឃើញទេ ដូច្នេះសូមសួរ។',
      },
    ),
    Ingredient(
      '멸치 육수',
      {
        'vi': 'nước dùng cá cơm',
        'en': 'anchovy broth',
        'fil': 'sabaw ng dilis',
        'km': 'ទឹកស៊ុបត្រីតូច',
      },
      tags: {FoodTag.fish},
      hidden: true,
      info: {
        'vi': 'Nước dùng canh Hàn Quốc thường nấu bằng cá cơm khô, kể cả món không có thịt.',
        'en': 'Korean soups are often made with dried anchovy broth, even when there is no meat.',
        'fil': 'Madalas gawa sa tuyong dilis ang sabaw ng Korean soup, kahit walang karne.',
        'km': 'ស៊ុបកូរ៉េច្រើនតែធ្វើពីទឹកស៊ុបត្រីតូចស្ងួត ទោះគ្មានសាច់ក៏ដោយ។',
      },
    ),
    Ingredient(
      '젓갈',
      {
        'vi': 'mắm (tôm, cá)',
        'en': 'salted seafood',
        'fil': 'bagoong',
        'km': 'ប្រហុក (បង្គា ត្រី)',
      },
      tags: {FoodTag.fish, FoodTag.shellfish},
      hidden: true,
      info: {
        'vi': 'Kim chi thường được muối với mắm tôm hoặc mắm cá (젓갈). Món chay cũng có thể có.',
        'en': 'Kimchi is usually made with salted shrimp or fish (젓갈). It can be in dishes that look vegetarian.',
        'fil': 'Karaniwang may bagoong na hipon o isda (젓갈) ang kimchi. Puwede itong nasa pagkaing mukhang gulay lang.',
        'km': 'គីមឈីជាធម្មតាធ្វើជាមួយប្រហុកបង្គា ឬត្រី (젓갈)។ អាចមានក្នុងម្ហូបដែលមើលទៅដូចបួស។',
      },
    ),
  ],
  turns: [
    ScenarioTurn('어서 오세요. 주문하시겠어요?', {
      'vi': 'Xin mời. Anh gọi món chưa ạ?',
      'en': 'Welcome. Are you ready to order?',
      'fil': 'Magandang araw po. Oorder na po ba kayo?',
      'km': 'សូមស្វាគមន៍។ តើចង់កុម្ម៉ង់ទេ?',
    }),
    ScenarioTurn(
      '네. 드시고 가세요, 포장하세요?',
      {
        'vi': 'Vâng. Ăn tại đây hay mang về ạ?',
        'en': 'Sure. For here or to go?',
        'fil': 'Sige po. Dito po ba kakain o take-out?',
        'km': 'បាទ។ ញ៉ាំនៅទីនេះ ឬខ្ចប់យកទៅ?',
      },
      target: '먹고 갈게요.',
      targetMeaning: {
        'vi': 'Tôi ăn ở đây.',
        'en': 'For here, please.',
        'fil': 'Dito na po kakain.',
        'km': 'ញ៉ាំនៅទីនេះ។',
      },
    ),
  ],
);

// ---------------------------------------------------------------- 반찬가게

const sideDish = Scenario(
  id: 'side_dish',
  place: '반찬가게',
  tip: '하나 더 살 때는 ‘-도’를 붙여요. 콩자반도 주세요',
  menu: '멸치볶음',
  menuMeaning: {
    'vi': 'cá cơm rim',
    'en': 'stir-fried anchovies',
    'fil': 'ginisang dilis',
    'km': 'ត្រីតូចៗឆា',
  },
  groups: [
    ScenarioGroup('얼마나', _howMuch, initial: 0, [
      ScenarioOption('한 팩', {
        'vi': '1 hộp',
        'en': '1 pack of',
        'fil': '1 pakete ng',
        'km': '១កញ្ចប់',
      }),
      ScenarioOption('두 팩', {
        'vi': '2 hộp',
        'en': '2 packs of',
        'fil': '2 pakete ng',
        'km': '២កញ្ចប់',
      }),
      ScenarioOption('오천 원어치', {
        'vi': '5.000 won',
        'en': '5,000 won of',
        'fil': '5,000 won na',
        'km': 'តម្លៃ ៥០០០ វ៉ុន',
      }),
    ]),
    ScenarioGroup(
      '하나 더',
      {
        'vi': 'Thêm món',
        'en': 'One more dish',
        'fil': 'Isa pang ulam',
        'km': 'ម្ហូបមួយទៀត',
      },
      initial: 0,
      required: false,
      rule: {
        'vi': 'Thêm “-도” khi mua thêm một món, nghĩa là “cũng, thêm”.',
        'en': 'Add “-도” when you buy one more. It means “also, too”.',
        'fil': 'Idagdag ang “-도” kapag bibili pa ng isa. Ibig sabihin: “din, rin”.',
        'km': 'បន្ថែម “-도” ពេលទិញមួយទៀត មានន័យថា “ផងដែរ”។',
      },
      [
        ScenarioOption('콩자반', token: '콩자반도', {
          'vi': 'thêm đậu đen kho',
          'en': 'and braised black beans',
          'fil': 'at nilagang itim na beans',
          'km': 'និងសណ្ដែកខ្មៅខ',
        }),
        ScenarioOption('시금치나물', token: '시금치나물도', {
          'vi': 'thêm rau chân vịt trộn',
          'en': 'and seasoned spinach',
          'fil': 'at tinimplahang spinach',
          'km': 'និងស្ពៃស្ពាណាចលាយ',
        }),
        ScenarioOption('깍두기', token: '깍두기도', {
          'vi': 'thêm kim chi củ cải',
          'en': 'and radish kimchi',
          'fil': 'at labanos na kimchi',
          'km': 'និងគីមឈីឆៃថាវ',
        }),
      ],
    ),
  ],
  turns: [
    ScenarioTurn('어서 오세요. 뭐 담아 드릴까요?', {
      'vi': 'Xin mời. Anh muốn lấy món gì ạ?',
      'en': 'Welcome. What would you like?',
      'fil': 'Magandang araw po. Ano po ang ilalagay ko?',
      'km': 'សូមស្វាគមន៍។ ចង់បានម្ហូបអ្វីដែរ?',
    }),
    ScenarioTurn(
      '네, 담아 드릴게요. 봉투 필요하세요?',
      {
        'vi': 'Vâng, tôi gói cho. Anh cần túi không?',
        'en': "Sure, I'll pack them. Do you need a bag?",
        'fil': "Sige po, ilalagay ko. Kailangan n'yo po ba ng supot?",
        'km': 'បាទ ខ្ញុំខ្ចប់ឲ្យ។ ត្រូវការថង់ទេ?',
      },
      target: '네, 봉투 하나 주세요.',
      targetMeaning: {
        'vi': 'Vâng, cho tôi một cái túi.',
        'en': 'Yes, one bag please.',
        'fil': 'Opo, isang supot po.',
        'km': 'បាទ សូមថង់មួយ។',
      },
    ),
  ],
);
