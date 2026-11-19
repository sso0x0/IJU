import '../../app/diet.dart';
import '../../app/session.dart';

/// 학습자 언어별 번역. 키는 서버 Language 값(vi, en, fil, km).
typedef Tr = Map<String, String>;

/// 지금 사용자 언어로 고릅니다. 없는 언어(ko 등)는 영어로.
String tr(Tr m) => m[AppSession.language] ?? m['en'] ?? '';

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

/// 문장 틀에서 그룹이 들어가는 문장.
enum SentenceKind {
  /// 첫 문장 ‘김치찌개 1인분 … 주세요.’
  order,

  /// 따로 붙는 ‘돼지고기는 빼 주세요.’
  without,

  /// 따로 붙는 ‘고기 육수 들어가요?’
  ask,
}

/// 메뉴에 들어가는 재료 하나. 사용자 식단·종교와 맞지 않으면 문장 만들기에서
/// 보이는 재료는 ‘빼 주세요’, 숨은 재료([hidden])는 ‘들어가요?’로 미리 골라 둡니다.
class Ingredient {
  const Ingredient(
    this.label,
    this.meaning, {
    this.tags = const {},
    this.hidden = false,
    this.info,
  });

  final String label;
  final Tr meaning;
  final Set<FoodTag> tags;

  /// 국물·양념처럼 눈에 안 보여 빼 달라기보다 물어봐야 하는 재료.
  final bool hidden;
  final Tr? info;
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
  }) : slot = slot ?? title;

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
  });

  /// 메뉴 재료. 있으면 [groupsFor]가 ‘빼 주세요’·‘들어가요?’ 그룹을 붙입니다.
  final List<Ingredient> ingredients;

  /// 화면에 보여 줄 그룹: 시나리오 그룹 + 재료로 만든 ‘빼 주세요’·‘들어가요?’.
  /// [diets]와 맞지 않는 재료는 미리 골라 두고 빨강(보이는 재료)·노랑(숨은 재료)으로 표시합니다.
  List<ScenarioGroup> groupsFor(Set<Diet> diets) {
    ScenarioGroup? build(bool hidden) {
      final items = [
        for (final i in ingredients)
          if (i.hidden == hidden) i,
      ];
      if (items.isEmpty) return null;
      final conflicts = [for (final i in items) Diet.conflicts(i.tags, diets)];
      final options = [
        for (final (n, i) in items.indexed)
          ScenarioOption(
            i.label,
            i.meaning,
            token: hidden ? i.label : '${withTopic(i.label)} 빼',
            info: i.info,
            conflicts: conflicts[n],
            caution: conflicts[n].isEmpty
                ? null
                : (hidden ? Caution.hidden : Caution.contains),
          ),
      ];
      final picked = {
        for (var n = 0; n < items.length; n++)
          if (conflicts[n].isNotEmpty) n,
      };
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
              initialAll: picked,
            )
          : ScenarioGroup(
              '빼 주세요',
              _withoutSub,
              options,
              required: false,
              multi: true,
              kind: SentenceKind.without,
              slot: '빼기',
              rule: _withoutRule,
              initialAll: picked,
            );
    }

    return [...groups, ?build(false), ?build(true)];
  }

  /// 서버 store_type과 같은 값 (butcher, restaurant, side_dish)
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
      all.firstWhere((s) => s.id == id, orElse: () => butcher);

  static const all = [butcher, restaurant, sideDish];

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
    final lang = AppSession.language;
    final please = (_please[lang] ?? _please['en']!).replaceFirst(
      '{}',
      parts.join(' '),
    );
    String fill(Map<String, String> t, List<ScenarioOption> os) =>
        (t[lang] ?? t['en']!).replaceFirst(
          '{}',
          os.map((o) => tr(o.meaning)).join(', '),
        );
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

// ---------------------------------------------------------------- 정육점

const _howMuch = {
  'vi': 'Bao nhiêu',
  'en': 'How much',
  'fil': 'Gaano karami',
  'km': 'ប៉ុន្មាន',
};

const butcher = Scenario(
  id: 'butcher',
  place: '정육점',
  tip: '잘했어요! 용도 뒤에는 ‘-으로’를 붙여요. 구이용으로, 찌개용으로',
  menu: '삼겹살',
  menuMeaning: {
    'vi': 'thịt ba chỉ',
    'en': 'pork belly',
    'fil': 'liempo',
    'km': 'សាច់ជ្រូកបីជាន់',
  },
  groups: [
    ScenarioGroup('얼마나', _howMuch, initial: 1, [
      ScenarioOption('300그램', {
        'vi': '300g',
        'en': '300g',
        'fil': '300g',
        'km': '300g',
      }),
      ScenarioOption('600그램', {
        'vi': '600g',
        'en': '600g',
        'fil': '600g',
        'km': '600g',
      }),
      ScenarioOption('한 근', {
        'vi': '1 geun (600g)',
        'en': '1 geun (600g)',
        'fil': '1 geun (600g)',
        'km': '1 geun (600g)',
      }),
    ]),
    ScenarioGroup(
      '어떻게 먹어요?',
      {
        'vi': 'Dùng để làm gì',
        'en': 'How will you cook it',
        'fil': 'Paano lulutuin',
        'km': 'ធ្វើម្ហូបអ្វី',
      },
      initial: 0,
      slot: '용도',
      rule: {
        'vi': 'Thêm “-으로” sau mục đích, nghĩa là “để …”.',
        'en': 'Add “-으로” after the purpose. It means “for …”.',
        'fil': 'Idagdag ang “-으로” pagkatapos ng layunin. Ibig sabihin: “para sa …”.',
        'km': 'បន្ថែម “-으로” ក្រោយគោលបំណង មានន័យថា “សម្រាប់ …”។',
      },
      [
        ScenarioOption('구이용', token: '구이용으로', {
          'vi': 'để nướng',
          'en': 'for grilling',
          'fil': 'pang-ihaw',
          'km': 'សម្រាប់អាំង',
        }),
        ScenarioOption('찌개용', token: '찌개용으로', {
          'vi': 'để nấu canh',
          'en': 'for stew',
          'fil': 'pang-sabaw',
          'km': 'សម្រាប់ស្ល',
        }),
        ScenarioOption('수육용', token: '수육용으로', {
          'vi': 'để luộc',
          'en': 'for boiling',
          'fil': 'pampakulo',
          'km': 'សម្រាប់ស្ងោរ',
        }),
      ],
    ),
    ScenarioGroup(
      '손질',
      {'vi': 'Cách cắt', 'en': 'Cut', 'fil': 'Hiwa', 'km': 'របៀបកាត់'},
      required: false,
      rule: {
        'vi': '“썰어” nghĩa là “cắt”: “두껍게 썰어” = cắt dày.',
        'en': '“썰어” means “slice”: “두껍게 썰어” = slice it thick.',
        'fil': 'Ang “썰어” ay “hiwain”: “두껍게 썰어” = hiwain nang makapal.',
        'km': '“썰어” មានន័យថា “កាត់”៖ “두껍게 썰어” = កាត់ក្រាស់។',
      },
      [
        ScenarioOption('그대로', {
          'vi': 'để nguyên',
          'en': 'as is',
          'fil': 'buo',
          'km': 'ទុកដដែល',
        }),
        ScenarioOption('두껍게', token: '두껍게 썰어', {
          'vi': 'cắt dày',
          'en': 'thick-sliced',
          'fil': 'makapal na hiwa',
          'km': 'កាត់ក្រាស់',
        }),
        ScenarioOption('얇게', token: '얇게 썰어', {
          'vi': 'cắt mỏng',
          'en': 'thin-sliced',
          'fil': 'manipis na hiwa',
          'km': 'កាត់ស្តើង',
        }),
      ],
    ),
  ],
  turns: [
    ScenarioTurn('어서 오세요. 뭐 드릴까요?', {
      'vi': 'Xin mời. Anh cần gì ạ?',
      'en': 'Welcome. What can I get you?',
      'fil': 'Magandang araw po. Ano po ang kailangan nila?',
      'km': 'សូមស្វាគមន៍។ ត្រូវការអ្វីដែរ?',
    }),
    ScenarioTurn(
      '네, 여기 있어요. 더 필요한 거 있으세요?',
      {
        'vi': 'Vâng, đây ạ. Anh cần gì thêm không?',
        'en': 'Here you go. Anything else?',
        'fil': 'Heto po. May kailangan pa po ba kayo?',
        'km': 'នេះបាទ។ ត្រូវការអ្វីទៀតទេ?',
      },
      target: '아니요, 괜찮아요.',
      targetMeaning: {
        'vi': 'Không, vậy được rồi.',
        'en': "No, that's all.",
        'fil': 'Wala na po, okay na.',
        'km': 'ទេ បានហើយ។',
      },
    ),
  ],
);

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
      initial: 0,
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
  // 식단·종교에 맞지 않는 재료는 groupsFor가 ‘빼 주세요’·‘들어가요?’에 미리 골라 둡니다.
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
      '조미료',
      {'vi': 'bột ngọt', 'en': 'MSG', 'fil': 'vetsin', 'km': 'ម្សៅស៊ុប'},
      info: {
        'vi': '“조미료” là gia vị như bột ngọt. Kim chi và nước dùng có thể đã có sẵn, nên không phải lúc nào cũng bỏ hết được.',
        'en': '“조미료” means seasoning like MSG. The kimchi and broth may already contain it, so it cannot always be left out completely.',
        'fil': 'Ang “조미료” ay pampalasa tulad ng vetsin. Maaaring mayroon na nito ang kimchi at sabaw, kaya hindi laging matatanggal nang buo.',
        'km': '“조미료” គឺគ្រឿងទេសដូចម្សៅស៊ុប។ គីមឈី និងទឹកស៊ុបអាចមានរួចហើយ ដូច្នេះមិនតែងតែដកចេញទាំងស្រុងបានទេ។',
      },
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
