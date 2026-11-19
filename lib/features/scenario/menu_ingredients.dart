import '../../app/diet.dart';
import 'scenarios.dart';

/// 메뉴판에서 고른 메뉴 이름으로 문장 틀과 재료를 짐작합니다.
///
/// - 문장 틀: 술·음료([isDrink]) / 굽는 고기([isRawMeat]) / 식당 요리, 맵기([isSpicyDish])
/// - 재료: 이름 속 낱말(스팸, 두부, 고기…) + 서버가 찾아 준 레시피([RecipeMatch])의 재료.
///   보이는 재료는 ‘빼 주세요’, 국물·양념에 숨은 재료는 ‘들어가요?’ 칩이 됩니다.

String _norm(String s) => s.replaceAll(RegExp(r'\s'), '');
bool _endsWithAny(String s, List<String> xs) => xs.any(s.endsWith);
bool _hasAny(String s, List<String> xs) => xs.any(s.contains);

// ---------------------------------------------------------------- 문장 틀 고르기

/// 이름 끝이 이렇게 끝나면 요리 (국거리·탕수육처럼 중간에 든 경우는 빼려고 끝만 봅니다).
const _dishEndings = [
  '국',
  '탕',
  '밥',
  '면',
  '죽',
  '찜',
  '전',
  '회',
  '말이',
  '구이',
  '튀김',
  '무침',
  '조림',
  '볶음',
  '샐러드',
  '덮밥',
  '찌개',
];

/// 이름 어디에 있어도 요리.
const _dishWords = [
  '찌개',
  '전골',
  '볶음',
  '덮밥',
  '김밥',
  '라면',
  '국수',
  '냉면',
  '비빔',
  '정식',
  '백반',
  '만두',
  '떡볶이',
  '돈까스',
  '돈가스',
  '까스',
  '우동',
  '짬뽕',
  '짜장',
  '수제비',
  '국밥',
  '구이',
  '탕수육',
  '오므라이스',
  '제육',
  '짜글이',
  '두루치기',
  '닭갈비',
  '찜닭',
  '불고기',
  '보쌈',
  '족발',
  '순대',
  '수육',
  '강정',
  '치킨',
  '피자',
  '버거',
  '샌드위치',
  '꼬치',
  '샤브',
  '스테이크',
  '파스타',
  '카레',
  '리조또',
  '쌈',
  '부침',
  '어묵',
  '오뎅',
  '튀김',
  '샐러드',
  '떡갈비',
  '해장',
];

/// 식당에서 구워 먹는 고기 (삼겹살, 목살, 등심…). ‘-감/-용’이 붙으면 요리 이름이 들어 있어도 고기입니다.
const _rawExplicit = [
  '불고기감',
  '국거리',
  '다짐육',
  '구이용',
  '찌개용',
  '수육용',
  '장조림용',
  '카레용',
  '샤브용',
  '보쌈용',
];

const _rawMeatWords = [
  '등심',
  '안심',
  '채끝',
  '사태',
  '양지',
  '차돌박이',
  '우둔',
  '홍두깨',
  '생닭',
  '닭다리',
  '닭가슴',
  '닭날개',
  '오리',
  '한우',
  '한돈',
  '돼지고기',
  '소고기',
  '쇠고기',
  '닭고기',
  '갈비',
  '꽃살',
  '항정',
  '가브리',
  '갈매기',
  '토시',
  '부채',
];

/// 국물 요리 (고기·멸치 육수를 물어봐야 하는 메뉴).
const _soupEndings = ['국', '탕'];
const _soupWords = [
  '찌개',
  '전골',
  '국밥',
  '국수',
  '라면',
  '냉면',
  '우동',
  '짬뽕',
  '수제비',
  '짜글이',
  '샤브',
  '뚝배기',
  '해장',
];

/// 맵기를 고를 만한 요리.
const _spicyWords = [
  '찌개',
  '김치',
  '볶음',
  '떡볶이',
  '짬뽕',
  '라면',
  '매운',
  '불닭',
  '닭갈비',
  '제육',
  '낙지',
  '주꾸미',
  '쭈꾸미',
  '육개장',
  '국밥',
  '전골',
  '비빔',
  '부대',
  '짜글이',
  '두루치기',
  '마라',
  '얼큰',
  '고추',
  '닭볶음',
  '해장',
];

/// 메뉴 이름이 구워 먹는 고기가 아니라 요리인지 (스팸두부찌개, 제육볶음, 비빔밥…).
bool isCookedDish(String menu) {
  final s = _norm(menu);
  return _endsWithAny(s, _dishEndings) || _hasAny(s, _dishWords);
}

/// 구워 먹는 고기인지 (삼겹살, 목살, 등심, LA갈비…). ‘삼겹살 2인분 주세요’처럼 인분으로 셉니다.
bool isRawMeat(String menu) {
  final s = _norm(menu);
  if (_hasAny(s, _rawExplicit)) return true;
  if (isCookedDish(s)) return false;
  return s.endsWith('살') || _hasAny(s, _rawMeatWords);
}

bool isSoup(String menu) {
  final s = _norm(menu);
  return _endsWithAny(s, _soupEndings) || _hasAny(s, _soupWords);
}

bool isSpicyDish(String menu) {
  final s = _norm(menu);
  return s.endsWith('탕') || _hasAny(s, _spicyWords);
}

/// 술·음료 (병·잔으로 세는 메뉴).
const _drinkWords = [
  '소주',
  '맥주',
  '막걸리',
  '동동주',
  '와인',
  '소맥',
  '하이볼',
  '청하',
  '매화수',
  '복분자',
  '사케',
  '사이다',
  '콜라',
  '환타',
  '음료',
  '주스',
  '쥬스',
  '생수',
  '탄산수',
  '커피',
  '아메리카노',
  '에이드',
  '맥콜',
  '식혜',
  '라떼',
  '칵테일',
  '위스키',
  '고량주',
  '양주',
  '보드카',
  '전통주',
  '과실주',
  '레몬사와',
  '아이스티',
  '밀크티',
  '홍차',
  '녹차',
  '스무디',
  '쉐이크',
  '셰이크',
  '프라페',
  '우유',
  '두유',
  '요구르트',
  '요거트',
  '수정과',
  '소다',
  '토닉',
  '하이네켄',
  '참이슬',
  '처음처럼',
  '진로',
  '펩시',
  '코카',
  '스프라이트',
  '포카리',
  '게토레이',
  '박카스',
];

/// 잔으로 세는 음료 (나머지는 병).
const _glassWords = [
  '차',
  '티',
  '스무디',
  '쉐이크',
  '셰이크',
  '프라페',
  '생맥주',
  '하이볼',
  '커피',
  '아메리카노',
  '에이드',
  '라떼',
  '칵테일',
  '잔',
  'cc',
];

bool isDrink(String menu) {
  final s = _norm(menu);
  if (isCookedDish(s) && !_hasAny(s, ['우유', '요구르트'])) return false;
  // 유자차·매실차·대추차처럼 ‘-차’로 끝나는 차
  return s == '물' ||
      _hasAny(s, _drinkWords) ||
      (s.length >= 2 && s.endsWith('차'));
}

bool isByGlass(String menu) => _hasAny(_norm(menu), _glassWords);

/// 케이크·빵 같은 디저트. ‘케이크 한 개 주세요’처럼 개수로 세고,
/// 빼 달라고 하기보다 계란·우유·젤라틴이 들어가는지만 묻습니다.
const _dessertWords = [
  '케이크',
  '케익',
  '쿠키',
  '마카롱',
  '아이스크림',
  '빙수',
  '와플',
  '타르트',
  '푸딩',
  '도넛',
  '도너츠',
  '머핀',
  '스콘',
  '크로플',
  '크루아상',
  '크로와상',
  '브라우니',
  '티라미수',
  '젤리',
  '초콜릿',
  '초콜렛',
  '카스텔라',
  '마들렌',
  '휘낭시에',
  '젤라또',
  '셔벗',
  '팬케이크',
  '크레페',
  '츄러스',
  '추로스',
  '베이글',
  '롤케이크',
  '파이',
  '디저트',
  '케잌',
];

bool isDessert(String menu) {
  final s = _norm(menu);
  return s.endsWith('빵') || s.endsWith('떡') || _hasAny(s, _dessertWords);
}

const _dessertEgg = Ingredient(
  '계란',
  {'vi': 'trứng', 'en': 'egg', 'fil': 'itlog', 'km': 'ពង'},
  tags: {FoodTag.egg},
  hidden: true,
);
const _dessertMilk = Ingredient(
  '우유',
  {'vi': 'sữa', 'en': 'milk', 'fil': 'gatas', 'km': 'ទឹកដោះគោ'},
  tags: {FoodTag.dairy},
  hidden: true,
);

/// 젤리·무스·마시멜로에 쓰는 젤라틴은 대개 돼지·소에서 나옵니다.
const _gelatin = Ingredient(
  '젤라틴',
  {'vi': 'gelatin', 'en': 'gelatin', 'fil': 'gelatin', 'km': 'ជែលលីទីន'},
  tags: {FoodTag.pork, FoodTag.beef},
  hidden: true,
);
const _liquor = Ingredient(
  '술',
  {'vi': 'rượu', 'en': 'alcohol', 'fil': 'alak', 'km': 'ស្រា'},
  tags: {FoodTag.alcohol},
  hidden: true,
);

/// 디저트에서 물어볼 재료 (모두 ‘들어가요?’).
List<Ingredient> dessertIngredients(String menu) {
  final s = _norm(menu);
  final plant = _hasAny(s, ['과일', '셔벗', '젤리']) && !s.contains('케이크');
  return [
    if (!plant) _dessertEgg,
    if (!s.contains('셔벗')) _dessertMilk,
    if (_hasAny(s, ['젤리', '무스', '푸딩', '마시멜로', '마카롱', '티라미수', '젤라또'])) _gelatin,
    if (_hasAny(s, ['티라미수', '럼', '와인', '리큐르', '위스키'])) _liquor,
  ];
}

/// 인분 대신 세는 말: 치킨 한 마리, 피자 한 판, 김밥 한 줄, 버거 한 개…
String? counterFor(String menu) {
  final s = _norm(menu);
  if (isDessert(s)) return '개';
  if (_endsWithAny(s, ['치킨', '통닭', '닭강정'])) return '마리';
  if (s.endsWith('피자')) return '판';
  if (s.endsWith('김밥')) return '줄';
  if (_endsWithAny(s, [
    '버거',
    '샌드위치',
    '핫도그',
    '토스트',
    '꼬치',
    '타코',
    '부리또',
    '주먹밥',
    '호떡',
    '붕어빵',
    '만두',
  ])) {
    return s.endsWith('만두') ? null : '개';
  }
  return null;
}

/// ‘한 개 · 두 개 · 세 개’ 같은 개수 그룹.
ScenarioGroup countGroup(String counter) =>
    ScenarioGroup('몇 $counter', _howManySub, initial: 0, [
      for (final (n, word) in [(1, '한'), (2, '두'), (3, '세')])
        ScenarioOption('$word $counter', {
          'vi': '$n',
          'en': '$n',
          'fil': '$n',
          'km': ['១', '២', '៣'][n - 1],
        }),
    ]);

/// ‘추가해 주세요’로 시키는 것 (치즈 추가, 라면사리, 우동사리…).
/// 개수를 세지 않고, 재료를 묻는 문장도 붙이지 않습니다.
bool isExtra(String menu) {
  final s = _norm(menu);
  return s.endsWith('추가') || s.contains('사리');
}

/// 따로 하나씩 더 시키는 곁들임 (공기밥, 계란후라이…). ‘공기밥 하나 주세요’처럼 개수로 셉니다.
const _sideWords = ['공기밥', '공깃밥', '햇반', '계란후라이', '계란프라이', '달걀프라이'];
const _sideExact = ['밥', '김', '김가루', '단무지'];

bool isSideOrder(String menu) {
  final s = _norm(menu);
  return _sideExact.contains(s) || _hasAny(s, _sideWords);
}

/// ‘치즈 추가’ → ‘치즈’ (‘치즈 추가해 주세요’에 들어갈 말).
String extraWord(String menu) =>
    menu.trim().replaceFirst(RegExp(r'\s*추가$'), '');

/// 곁들임(공기밥…): 몇 개 (하나 · 두 개 · 세 개)
const pieceGroup = ScenarioGroup('몇 개', _howManySub, initial: 0, [
  ScenarioOption('하나', {'vi': 'một', 'en': 'one', 'fil': 'isang', 'km': 'មួយ'}),
  ScenarioOption('두 개', {
    'vi': 'hai',
    'en': 'two',
    'fil': 'dalawang',
    'km': 'ពីរ',
  }),
  ScenarioOption('세 개', {
    'vi': 'ba',
    'en': 'three',
    'fil': 'tatlong',
    'km': 'បី',
  }),
]);

const _howManySub = {
  'vi': 'Bao nhiêu',
  'en': 'How many',
  'fil': 'Ilan',
  'km': 'ប៉ុន្មាន',
};

/// 술·음료: 몇 병
const bottleGroup = ScenarioGroup('몇 병', _howManySub, initial: 0, [
  ScenarioOption('한 병', {
    'vi': '1 chai',
    'en': '1 bottle of',
    'fil': '1 bote ng',
    'km': '១ដប',
  }),
  ScenarioOption('두 병', {
    'vi': '2 chai',
    'en': '2 bottles of',
    'fil': '2 bote ng',
    'km': '២ដប',
  }),
  ScenarioOption('세 병', {
    'vi': '3 chai',
    'en': '3 bottles of',
    'fil': '3 bote ng',
    'km': '៣ដប',
  }),
]);

/// 잔에 담아 주는 음료: 몇 잔
const glassGroup = ScenarioGroup('몇 잔', _howManySub, initial: 0, [
  ScenarioOption('한 잔', {
    'vi': '1 ly',
    'en': '1 glass of',
    'fil': '1 baso ng',
    'km': '១កែវ',
  }),
  ScenarioOption('두 잔', {
    'vi': '2 ly',
    'en': '2 glasses of',
    'fil': '2 baso ng',
    'km': '២កែវ',
  }),
  ScenarioOption('세 잔', {
    'vi': '3 ly',
    'en': '3 glasses of',
    'fil': '3 baso ng',
    'km': '៣កែវ',
  }),
]);

// ---------------------------------------------------------------- 재료

const _spam = Ingredient(
  '스팸',
  {'vi': 'thịt hộp Spam', 'en': 'Spam', 'fil': 'Spam', 'km': 'សាច់កំប៉ុង Spam'},
  tags: {FoodTag.pork},
);
const _ham = Ingredient(
  '햄',
  {'vi': 'giăm bông', 'en': 'ham', 'fil': 'ham', 'km': 'សាច់ក្រក'},
  tags: {FoodTag.pork},
);
const _pork = Ingredient(
  '돼지고기',
  {'vi': 'thịt heo', 'en': 'pork', 'fil': 'baboy', 'km': 'សាច់ជ្រូក'},
  tags: {FoodTag.pork},
);
const _beef = Ingredient(
  '소고기',
  {'vi': 'thịt bò', 'en': 'beef', 'fil': 'baka', 'km': 'សាច់គោ'},
  tags: {FoodTag.beef},
);
const _chicken = Ingredient(
  '닭고기',
  {'vi': 'thịt gà', 'en': 'chicken', 'fil': 'manok', 'km': 'សាច់មាន់'},
  tags: {FoodTag.poultry},
);
const _duck = Ingredient(
  '오리고기',
  {'vi': 'thịt vịt', 'en': 'duck', 'fil': 'pato', 'km': 'សាច់ទា'},
  tags: {FoodTag.poultry},
);

/// 이름에 ‘고기’만 있고 무슨 고기인지 모를 때. 채식은 ‘고기는 빼 주세요’,
/// 종교(돼지고기·소고기만 피함)는 아래 ‘돼지고기·소고기 들어가요?’로 묻습니다.
const _anyMeatVisible = Ingredient(
  '고기',
  {'vi': 'thịt', 'en': 'meat', 'fil': 'karne', 'km': 'សាច់'},
  tags: {FoodTag.pork, FoodTag.beef, FoodTag.poultry},
  matchAll: true,
);
const _shrimp = Ingredient(
  '새우',
  {'vi': 'tôm', 'en': 'shrimp', 'fil': 'hipon', 'km': 'បង្គា'},
  tags: {FoodTag.shellfish},
);
const _squid = Ingredient(
  '오징어',
  {'vi': 'mực', 'en': 'squid', 'fil': 'pusit', 'km': 'មឹក'},
  // 비늘·지느러미가 없는 해산물이라 코셔에서도 피합니다.
  tags: {FoodTag.shellfish},
);
const _seafood = Ingredient(
  '해물',
  {'vi': 'hải sản', 'en': 'seafood', 'fil': 'seafood', 'km': 'អាហារសមុទ្រ'},
  tags: {FoodTag.fish, FoodTag.shellfish},
);
const _tuna = Ingredient(
  '참치',
  {'vi': 'cá ngừ', 'en': 'tuna', 'fil': 'tuna', 'km': 'ត្រីធូណា'},
  tags: {FoodTag.fish},
);
const _fish = Ingredient(
  '생선',
  {'vi': 'cá', 'en': 'fish', 'fil': 'isda', 'km': 'ត្រី'},
  tags: {FoodTag.fish},
);
const _fishCake = Ingredient(
  '어묵',
  {'vi': 'chả cá', 'en': 'fish cake', 'fil': 'fish cake', 'km': 'ប្រហិតត្រី'},
  tags: {FoodTag.fish},
);
const _anchovy = Ingredient(
  '멸치',
  {'vi': 'cá cơm', 'en': 'anchovy', 'fil': 'dilis', 'km': 'ត្រីតូច'},
  tags: {FoodTag.fish},
);
const _egg = Ingredient(
  '계란',
  {'vi': 'trứng', 'en': 'egg', 'fil': 'itlog', 'km': 'ពង'},
  tags: {FoodTag.egg},
);
const _cheese = Ingredient(
  '치즈',
  {'vi': 'phô mai', 'en': 'cheese', 'fil': 'keso', 'km': 'ឈីស'},
  tags: {FoodTag.dairy},
);
const _milk = Ingredient(
  '우유',
  {'vi': 'sữa', 'en': 'milk', 'fil': 'gatas', 'km': 'ទឹកដោះគោ'},
  tags: {FoodTag.dairy},
);
const _tofu = Ingredient(
  '두부',
  {'vi': 'đậu phụ', 'en': 'tofu', 'fil': 'tokwa', 'km': 'តៅហ៊ូ'},
  tags: {FoodTag.plant},
);
const _greenOnion = Ingredient(
  '파',
  {
    'vi': 'hành lá',
    'en': 'green onion',
    'fil': 'dahon ng sibuyas',
    'km': 'ស្លឹកខ្ទឹម',
  },
  tags: {FoodTag.plant},
);
// 숨은 재료 (들어가요?)
const _meatBroth = Ingredient(
  '고기 육수',
  {
    'vi': 'nước hầm thịt',
    'en': 'meat broth',
    'fil': 'sabaw ng karne',
    'km': 'ទឹកស៊ុបសាច់',
  },
  tags: {FoodTag.pork, FoodTag.beef},
  hidden: true,
);
const _anchovyBroth = Ingredient(
  '멸치 육수',
  {
    'vi': 'nước dùng cá cơm',
    'en': 'anchovy broth',
    'fil': 'sabaw ng dilis',
    'km': 'ទឹកស៊ុបត្រីតូច',
  },
  tags: {FoodTag.fish},
  hidden: true,
);
const _salted = Ingredient(
  '젓갈',
  {
    'vi': 'mắm (tôm, cá)',
    'en': 'salted seafood',
    'fil': 'bagoong',
    'km': 'ប្រហុក (បង្គា ត្រី)',
  },
  tags: {FoodTag.fish, FoodTag.shellfish},
  hidden: true,
);
const _anyMeatHidden = Ingredient(
  '고기',
  {'vi': 'thịt', 'en': 'meat', 'fil': 'karne', 'km': 'សាច់'},
  tags: {FoodTag.pork, FoodTag.beef, FoodTag.poultry},
  hidden: true,
);
const _porkHidden = Ingredient(
  '돼지고기',
  {'vi': 'thịt heo', 'en': 'pork', 'fil': 'baboy', 'km': 'សាច់ជ្រូក'},
  tags: {FoodTag.pork},
  hidden: true,
);
const _beefHidden = Ingredient(
  '소고기',
  {'vi': 'thịt bò', 'en': 'beef', 'fil': 'baka', 'km': 'សាច់គោ'},
  tags: {FoodTag.beef},
  hidden: true,
);
const _oysterSauce = Ingredient(
  '굴소스',
  {
    'vi': 'dầu hào',
    'en': 'oyster sauce',
    'fil': 'oyster sauce',
    'km': 'ទឹកប្រេងខ្យង',
  },
  tags: {FoodTag.shellfish},
  hidden: true,
);

/// 낱말([keys] 중 하나가 들어 있음) → 재료. 메뉴 이름과 레시피 재료 이름에 같이 씁니다.
/// 먼저 나온 줄이 이깁니다 (새우젓은 새우보다 젓갈, 굴소스는 굴보다 굴소스).
const List<(List<String>, Ingredient)> _words = [
  (['새우젓', '액젓', '까나리', '젓갈', '멸치액'], _salted),
  (['굴소스'], _oysterSauce),
  (['사골', '고기육수', '쇠고기육수', '소고기육수', '닭육수', '돼지뼈'], _meatBroth),
  (['스팸'], _spam),
  (['햄', '소시지', '부대', '베이컨'], _ham),
  (
    [
      '돼지',
      '제육',
      '삼겹',
      '목살',
      '돈까스',
      '돈가스',
      '보쌈',
      '족발',
      '순대',
      '탕수육',
      '김치찌개',
      '감자탕',
      '짜장',
      '두루치기',
      '항정',
      '앞다리',
    ],
    _pork,
  ),
  (
    [
      '소고기',
      '쇠고기',
      '불고기',
      '육개장',
      '갈비탕',
      '곰탕',
      '설렁탕',
      '차돌',
      '우삼겹',
      '육회',
      '우민찌',
      '한우',
      '장조림',
      '스테이크',
      '떡갈비',
      '양지',
      '채끝',
    ],
    _beef,
  ),
  (['닭', '치킨', '삼계탕'], _chicken),
  (['오리'], _duck),
  (['새우'], _shrimp),
  (['오징어', '낙지', '주꾸미', '쭈꾸미', '문어'], _squid),
  (
    [
      '조개',
      '바지락',
      '홍합',
      '해물',
      '해산물',
      '짬뽕',
      '멍게',
      '전복',
      '꽃게',
      '대게',
      '꼬막',
      '모시조개',
      '관자',
    ],
    _seafood,
  ),
  (['참치'], _tuna),
  (
    [
      '생선',
      '고등어',
      '동태',
      '명태',
      '갈치',
      '꽁치',
      '연어',
      '대구',
      '코다리',
      '북어',
      '황태',
      '삼치',
      '조기',
      '굴비',
      '가자미',
      '광어',
      '우럭',
      '장어',
      '명란',
      '알탕',
    ],
    _fish,
  ),
  (['어묵', '오뎅'], _fishCake),
  (['멸치', '디포리'], _anchovy),
  (['계란', '달걀', '오므라이스', '메추리알', '마요네즈', '비빔밥', '김밥'], _egg),
  (['치즈'], _cheese),
  (['우유', '버터', '생크림', '크림', '요구르트'], _milk),
  (['두부'], _tofu),
];

/// 낱말 하나로 찾은 재료 (없으면 null).
Ingredient? _ingredientOf(String word) {
  final s = _norm(word);
  for (final (keys, ing) in _words) {
    if (_hasAny(s, keys)) return ing;
  }
  return null;
}

/// 메뉴 이름이 재료를 직접 말하지 않고 ‘보통 들어가는’ 재료만 알려 주는 낱말.
/// 김치찌개의 돼지고기·비빔밥의 계란처럼 빼 달라고 할 수 있는 재료입니다.
const _impliedKeys = {'김치찌개', '짜장', '부대', '비빔밥', '김밥'};

/// 메뉴 이름 속 재료들 (스팸두부찌개 → 스팸·두부, 새우튀김 → 새우).
/// 이름에 든 재료는 그 메뉴의 주재료라 [Ingredient.main]으로 표시합니다.
List<Ingredient> _fromName(String s) {
  final found = <Ingredient>[];
  void add(Ingredient i) {
    if (!found.any((f) => f.label == i.label)) found.add(i);
  }

  for (final (keys, ing) in _words) {
    // 이름 속 술·젓갈은 메뉴 재료로 보지 않습니다 (와인삼겹살 같은 이름은 드뭅니다).
    if (ing.hidden) continue;
    final matched = [
      for (final k in keys)
        if (s.contains(k)) k,
    ];
    if (matched.isEmpty) continue;
    add(matched.any((k) => !_impliedKeys.contains(k)) ? ing.asMain : ing);
  }
  // 굴은 한 글자라 이름에서만 따로 봅니다 (굴비·굴소스 빼고).
  if (s.contains('굴') && !s.contains('굴비')) add(_seafood.asMain);
  return found;
}

/// 메뉴 이름에 든 주재료만 (삼겹살 → 돼지고기). 고기 메뉴의 ‘들어가요’ 안내에 씁니다.
List<Ingredient> mainIngredientsFor(String menu) => [
  for (final i in _fromName(_norm(menu)))
    if (i.main) i,
];

bool _isSeafood(Ingredient i) =>
    !i.hidden && i.tags.any((t) => t == FoodTag.fish || t == FoodTag.shellfish);
bool _isAnimal(Ingredient i) => i.tags.any((t) => t != FoodTag.plant);
bool _isMeat(Ingredient i) => i.tags.any(
  (t) => t == FoodTag.pork || t == FoodTag.beef || t == FoodTag.poultry,
);

// ---------------------------------------------------------------- 레시피 (서버 /recipes/match)

/// 레시피 한 개의 재료 이름 (서버가 재료 글을 나눠 줌).
class Recipe {
  const Recipe({
    required this.name,
    this.category,
    this.main = const [],
    this.sauce = const [],
  });

  factory Recipe.fromJson(Map<String, dynamic> json) => Recipe(
    name: json['name'] as String,
    category: json['category'] as String?,
    main: [for (final m in json['main'] as List? ?? const []) '$m'],
    sauce: [for (final s in json['sauce'] as List? ?? const []) '$s'],
  );

  final String name;

  /// 국&찌개, 반찬, 일품, 밥, 후식, 기타
  final String? category;

  /// 보이는 재료 이름
  final List<String> main;

  /// 육수·국물·양념·소스 재료 이름
  final List<String> sauce;
}

/// 메뉴에 맞춰 서버가 찾은 레시피들.
class RecipeMatch {
  const RecipeMatch({required this.mode, required this.recipes});

  factory RecipeMatch.fromJson(Map<String, dynamic> json) => RecipeMatch(
    mode: json['mode'] as String?,
    recipes: [
      for (final r in json['recipes'] as List? ?? const [])
        Recipe.fromJson(r as Map<String, dynamic>),
    ],
  );

  /// exact(같은 이름) · contained(메뉴 이름 안에 든 레시피) · similar(비슷한 레시피 여럿)
  final String? mode;
  final List<Recipe> recipes;

  bool get isEmpty => recipes.isEmpty;

  /// 비슷한 레시피 여럿이면 재료가 레시피마다 달라서 절반 이상에 든 재료만 씁니다.
  bool get similar => mode == 'similar' && recipes.length > 1;

  /// 레시피 절반 이상이 국&찌개면 국물 요리로 봅니다 (육수를 물어봄).
  bool get mostlySoup =>
      recipes.isNotEmpty &&
      recipes.where((r) => r.category == '국&찌개').length * 2 >= recipes.length;
}

/// 레시피 한 개에서 식단과 관련 있는 재료. 육수·양념 쪽 재료는 ‘들어가요?’(hidden)로 바꿉니다.
List<Ingredient> _fromRecipe(Recipe r) {
  final found = <Ingredient>[];
  void add(Ingredient i) {
    if (!found.any((f) => f.label == i.label)) found.add(i);
  }

  for (final item in r.main) {
    final ing = _ingredientOf(item);
    if (ing == null) continue;
    // 멸치·디포리는 국물을 내는 데 주로 써서 보이는 재료보다 ‘멸치 육수 들어가요?’로 묻습니다.
    add(ing == _anchovy && r.category == '국&찌개' ? _anchovyBroth : ing);
  }
  for (final item in r.sauce) {
    final ing = _ingredientOf(item);
    if (ing == null) continue;
    if (ing.hidden) {
      add(ing);
    } else if (ing == _anchovy) {
      add(_anchovyBroth);
    } else if (_isMeat(ing)) {
      add(_meatBroth);
    } else if (_isAnimal(ing)) {
      add(ing.asHidden);
    }
  }
  return found;
}

/// 여러 레시피 중 절반 이상에 든 재료 (similar), 아니면 첫 레시피 재료 그대로.
List<Ingredient> _recipeIngredients(RecipeMatch match) {
  if (match.isEmpty) return const [];
  if (!match.similar) return _fromRecipe(match.recipes.first);
  final per = [for (final r in match.recipes) _fromRecipe(r)];
  final need = (per.length + 1) ~/ 2;
  final counts = <String, int>{};
  final first = <String, Ingredient>{};
  for (final list in per) {
    for (final i in list) {
      counts[i.label] = (counts[i.label] ?? 0) + 1;
      first.putIfAbsent(i.label, () => i);
    }
  }
  return [
    for (final e in first.entries)
      if (counts[e.key]! >= need) e.value,
  ];
}

// ---------------------------------------------------------------- 합치기

/// 메뉴판에서 고른 식당 메뉴의 재료를 짐작합니다.
///
/// 이름 속 낱말로 먼저 찾고, [recipe](Supabase recipes 표에서 찾은 레시피)가 있으면
/// 그 재료를 더합니다. 이름에 있는 재료는 확실하니 먼저, 레시피 재료는 그 뒤에 둡니다.
/// 보이는 재료(스팸·두부…)는 ‘빼 주세요’, 숨은 재료(육수·젓갈)는 ‘들어가요?’가 되고,
/// 조미료·맛술처럼 어느 집이나 넣는 양념은 묻지 않습니다.
/// 내 식단·종교와 맞지 않는 재료는 [Scenario.groupsFor]가 점으로 표시합니다.
List<Ingredient> ingredientsFor(String menu, {RecipeMatch? recipe}) {
  final s = _norm(menu);
  final soup = isSoup(s) || (recipe?.mostlySoup ?? false);
  final out = <Ingredient>[];
  void add(Ingredient i) {
    // 같은 이름이 보이는 재료와 숨은 재료로 둘 다 나오면 보이는 재료만 둡니다.
    final at = out.indexWhere((o) => o.label == i.label);
    if (at < 0) {
      out.add(i);
    } else if (out[at].hidden && !i.hidden) {
      out[at] = i;
    }
  }

  final fromName = _fromName(s);
  fromName.forEach(add);
  if (recipe != null) _recipeIngredients(recipe).forEach(add);

  // 이름에 ‘고기’만 있고 무슨 고기인지 모르면
  final knownMeat = out.any((i) => !i.hidden && _isMeat(i));
  if (s.contains('고기') && !knownMeat) {
    add(_anyMeatVisible.asMain);
    add(_porkHidden);
    add(_beefHidden);
  }

  if (soup) add(_greenOnion);
  if (soup) {
    add(_meatBroth);
    add(_anchovyBroth);
  } else if (!out.any(_isMeat) && !out.any(_isSeafood)) {
    // 고기·해물이 안 보이는 요리(비빔밥, 떡볶이…)는 고기가 들어가는지 물어봅니다.
    add(_anyMeatHidden);
  }
  if (s.contains('김치')) add(_salted);

  // 보이는 재료 먼저, 숨은 재료 뒤에 (칩 순서)
  return [
    for (final i in out)
      if (!i.hidden) i,
    for (final i in out)
      if (i.hidden) i,
  ];
}
