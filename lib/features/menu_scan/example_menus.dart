import '../scenario/scenarios.dart';
import 'menu_scan_api.dart';

/// 가게에 가기 전에 연습할 때 쓰는 예시 메뉴판 (가게 종류별 4개).
/// 메뉴판 인식 결과와 같은 모양이라 고른 뒤 흐름이 똑같습니다.
/// [price]는 예시 메뉴판 그림과 카드 설명 줄에 씁니다.
class ExampleMenu {
  const ExampleMenu(this.name, this.romanization, this.meaning, this.price);

  final String name;
  final String romanization;
  final Tr meaning;
  final String price;

  MenuCardData toCard() => MenuCardData(
    name: name,
    confidence: 1,
    romanization: romanization,
    meaning: tr(meaning),
    description: price,
  );
}

const _restaurant = [
  ExampleMenu('김치찌개', 'kimchi jjigae', {
    'vi': 'canh kim chi',
    'en': 'kimchi stew',
  }, '9,000원'),
  ExampleMenu('된장찌개', 'doenjang jjigae', {
    'vi': 'canh tương đậu',
    'en': 'soybean paste stew',
  }, '9,000원'),
  ExampleMenu('제육볶음', 'jeyuk bokkeum', {
    'vi': 'thịt heo xào cay',
    'en': 'spicy stir-fried pork',
  }, '10,000원'),
  ExampleMenu('비빔밥', 'bibimbap', {
    'vi': 'cơm trộn',
    'en': 'mixed rice',
  }, '9,000원'),
  ExampleMenu('삼겹살', 'samgyeopsal', {
    'vi': 'thịt ba chỉ',
    'en': 'pork belly',
  }, '1인분 15,000원'),
];

const _sideDish = [
  ExampleMenu('멸치볶음', 'myeolchi bokkeum', {
    'vi': 'cá cơm rim',
    'en': 'stir-fried anchovies',
  }, '한 팩 4,000원'),
  ExampleMenu('콩자반', 'kongjaban', {
    'vi': 'đậu đen rim',
    'en': 'braised black beans',
  }, '한 팩 3,500원'),
  ExampleMenu('시금치나물', 'sigeumchi namul', {
    'vi': 'rau chân vịt trộn',
    'en': 'seasoned spinach',
  }, '한 팩 3,000원'),
  ExampleMenu('배추김치', 'baechu kimchi', {
    'vi': 'kim chi cải thảo',
    'en': 'napa cabbage kimchi',
  }, '500g 6,000원'),
];

List<ExampleMenu> exampleMenusFor(String scenarioId) => switch (scenarioId) {
  'side_dish' => _sideDish,
  _ => _restaurant,
};
