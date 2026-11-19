import '../../app/session.dart';

/// 학습자 언어별 번역. 키는 서버 Language 값(vi, en, fil, km).
typedef Tr = Map<String, String>;

/// 지금 사용자 언어로 고릅니다. 없는 언어(ko 등)는 영어로.
String tr(Tr m) => m[AppSession.language] ?? m['en'] ?? '';

/// 문장 조립에서 고를 수 있는 키워드 하나.
///
/// [label]은 칩과 서버로 보내는 단어, [token]은 문장 카드에 들어갈 모양
/// (서버 compose.py의 규칙과 같게 맞춥니다).
class ScenarioOption {
  const ScenarioOption(this.label, this.meaning, {String? token})
    : token = token ?? label;

  final String label;
  final String token;
  final Tr meaning;
}

class ScenarioGroup {
  const ScenarioGroup(
    this.title,
    this.sub,
    this.options, {
    this.required = true,
    this.initial,
  });

  final String title;
  final Tr sub;
  final List<ScenarioOption> options;

  /// false면 고르지 않아도 되고, 같은 칩을 다시 누르면 선택이 풀립니다.
  final bool required;
  final int? initial;
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
  });

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
  String localMeaning(List<ScenarioOption> picked) {
    final parts = [
      if (picked.isNotEmpty) tr(picked.first.meaning),
      tr(menuMeaning),
      if (picked.length > 1)
        picked.skip(1).map((o) => tr(o.meaning)).join(', '),
    ];
    final template = _please[AppSession.language] ?? _please['en']!;
    return template.replaceFirst('{}', parts.join(' '));
  }

  static const _please = {
    'vi': 'Cho tôi {}.',
    'en': '{}, please.',
    'fil': 'Pabili po ng {}.',
    'km': 'សូមឲ្យខ្ញុំ {}។',
  };
}

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
  tip: '맵기는 ‘-게 해 주세요’로 부탁해요. 덜 맵게 해 주세요',
  menu: '제육볶음',
  menuMeaning: {
    'vi': 'thịt heo xào cay',
    'en': 'spicy stir-fried pork',
    'fil': 'maanghang na ginisang baboy',
    'km': 'សាច់ជ្រូកឆាហឹរ',
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
