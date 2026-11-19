import 'session.dart';

/// 재료가 어떤 음식 종류인지. 식단·종교마다 피하는 종류가 다릅니다.
enum FoodTag {
  pork,
  beef,
  poultry,
  fish,
  shellfish,
  egg,
  dairy,
  alcohol,

  /// 과일·견과류가 아닌 채소·곡물·콩 (프루테리언이 피함)
  plant,
}

const _meat = {FoodTag.pork, FoodTag.beef, FoodTag.poultry};
const _sea = {FoodTag.fish, FoodTag.shellfish};

/// 사용자가 고르는 식단(채식 7단계)과 종교. 여러 개를 함께 고를 수 있습니다.
///
/// [avoid]에 든 재료는 문장 만들기에서 자동으로 ‘빼 주세요’(보이는 재료)나
/// ‘들어가요?’(국물·양념에 숨은 재료)로 들어갑니다.
enum Diet {
  fruitarian(
    '프루테리언',
    {..._meat, ..._sea, FoodTag.egg, FoodTag.dairy, FoodTag.plant},
    {
      'vi': 'Chỉ ăn trái cây và các loại hạt',
      'en': 'Fruitarian: only fruit and nuts',
      'fil': 'Fruitarian: prutas at mani lang',
      'km': 'ញ៉ាំតែផ្លែឈើ និងគ្រាប់',
    },
  ),
  vegan(
    '비건',
    {..._meat, ..._sea, FoodTag.egg, FoodTag.dairy},
    {
      'vi': 'Thuần chay: không thịt, cá, trứng, sữa',
      'en': 'Vegan: no meat, fish, eggs or dairy',
      'fil': 'Vegan: walang karne, isda, itlog o gatas',
      'km': 'បួសសុទ្ធ៖ គ្មានសាច់ ត្រី ពង ទឹកដោះគោ',
    },
  ),
  lacto(
    '락토',
    {..._meat, ..._sea, FoodTag.egg},
    {
      'vi': 'Lacto: ăn sữa, không thịt, cá, trứng',
      'en': 'Lacto: dairy is OK; no meat, fish or eggs',
      'fil': 'Lacto: puwede ang gatas; walang karne, isda, itlog',
      'km': 'ឡាក់តូ៖ ទឹកដោះគោបាន គ្មានសាច់ ត្រី ពង',
    },
  ),
  ovo(
    '오보',
    {..._meat, ..._sea, FoodTag.dairy},
    {
      'vi': 'Ovo: ăn trứng, không thịt, cá, sữa',
      'en': 'Ovo: eggs are OK; no meat, fish or dairy',
      'fil': 'Ovo: puwede ang itlog; walang karne, isda, gatas',
      'km': 'អូវ៉ូ៖ ពងបាន គ្មានសាច់ ត្រី ទឹកដោះគោ',
    },
  ),
  lactoOvo(
    '락토오보',
    {..._meat, ..._sea},
    {
      'vi': 'Lacto-ovo: ăn trứng và sữa, không thịt, cá',
      'en': 'Lacto-ovo: eggs and dairy are OK; no meat or fish',
      'fil': 'Lacto-ovo: puwede ang itlog at gatas; walang karne, isda',
      'km': 'ឡាក់តូអូវ៉ូ៖ ពង ទឹកដោះគោបាន គ្មានសាច់ ត្រី',
    },
  ),
  pesco('페스코', _meat, {
    'vi': 'Pesco: ăn cá, hải sản; không thịt',
    'en': 'Pesco: fish and seafood are OK; no meat',
    'fil': 'Pesco: puwede ang isda at seafood; walang karne',
    'km': 'ប៉េស្កូ៖ ត្រី អាហារសមុទ្របាន គ្មានសាច់',
  }),
  pollo(
    '폴로',
    {FoodTag.pork, FoodTag.beef},
    {
      'vi': 'Pollo: ăn gà, cá; không thịt heo, bò',
      'en': 'Pollo: chicken and fish are OK; no pork or beef',
      'fil': 'Pollo: puwede ang manok at isda; walang baboy, baka',
      'km': 'ប៉ូឡូ៖ មាន់ ត្រីបាន គ្មានសាច់ជ្រូក គោ',
    },
  ),
  islam(
    '이슬람 (할랄)',
    {FoodTag.pork, FoodTag.alcohol},
    {
      'vi': 'Hồi giáo (halal): không thịt heo, rượu',
      'en': 'Islam (halal): no pork or alcohol',
      'fil': 'Islam (halal): walang baboy o alak',
      'km': 'ឥស្លាម (ហាឡាល់)៖ គ្មានសាច់ជ្រូក ស្រា',
    },
  ),
  judaism(
    '유대교 (코셔)',
    {FoodTag.pork, FoodTag.shellfish},
    {
      'vi': 'Do Thái (kosher): không thịt heo, hải sản có vỏ',
      'en': 'Judaism (kosher): no pork or shellfish',
      'fil': 'Judaism (kosher): walang baboy o shellfish',
      'km': 'យូដា (កូស៊ែរ)៖ គ្មានសាច់ជ្រូក សត្វសមុទ្រមានសំបក',
    },
  ),
  hindu(
    '힌두교',
    {FoodTag.beef},
    {
      'vi': 'Hindu: không thịt bò',
      'en': 'Hindu: no beef',
      'fil': 'Hindu: walang baka',
      'km': 'ហិណ្ឌូ៖ គ្មានសាច់គោ',
    },
  );

  const Diet(this.label, this.avoid, this.about);

  /// 칩에 보이는 한국어 이름
  final String label;
  final Set<FoodTag> avoid;

  /// 학습자 언어로 된 짧은 설명 (ⓘ, 재료 안내)
  final Map<String, String> about;

  /// 종교 칩(이슬람·유대교·힌두교)인지. 아니면 채식 단계.
  bool get religion => index >= Diet.islam.index;

  static List<Diet> get vegetarian => [
    for (final d in values)
      if (!d.religion) d,
  ];

  static List<Diet> get religions => [
    for (final d in values)
      if (d.religion) d,
  ];

  /// [tags] 재료를 피해야 하는 식단 (사용자가 고른 [diets] 중에서).
  static List<Diet> conflicts(Set<FoodTag> tags, Iterable<Diet> diets) => [
    for (final d in diets)
      if (d.avoid.any(tags.contains)) d,
  ];
}

/// 고른 식단을 칩 순서대로 이어 붙인 이름. 없으면 null.
String? dietLabels(Iterable<Diet> diets) {
  final sorted = diets.toList()..sort((a, b) => a.index - b.index);
  return sorted.isEmpty ? null : sorted.map((d) => d.label).join(' · ');
}

/// 지금 사용자 언어로 된 식단 설명.
String dietAbout(Diet d) => d.about[AppSession.language] ?? d.about['en']!;
