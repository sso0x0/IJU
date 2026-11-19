import '../../api/api_client.dart';
import '../../app/session.dart';

/// POST /ai/compose 응답 (server/app/schemas.py ComposeOut).
class ComposeResult {
  const ComposeResult({
    required this.options,
    required this.sentence,
    required this.meaning,
    required this.meanings,
    this.feedback,
  });

  /// 요청에 보낸 조합([ComposeApi.keyOf]). 응답이 늦게 와도 지금 고른 조합과 같은지 비교하는 데 씁니다.
  final List<String> options;
  final String sentence;
  final String meaning;

  /// 카드 단어 → 학습자 언어 뜻
  final Map<String, String> meanings;
  final String? feedback;
}

abstract final class ComposeApi {
  /// 요청 조합을 한 줄로. 같은 단어가 첫 문장·빼기·질문에 있어도 구분되게 앞에 표시를 붙입니다.
  static List<String> keyOf(
    List<String> options,
    List<String> without,
    List<String> ask,
  ) => List.unmodifiable([
    ...options,
    for (final w in without) '-$w',
    for (final a in ask) '?$a',
  ]);

  /// 서버가 꺼져 있거나 실패하면 null. 화면은 자체 조립 결과를 계속 보여 줍니다.
  /// [without]은 ‘빼 주세요’, [ask]는 ‘들어가요?’ 문장의 재료입니다.
  static Future<ComposeResult?> compose({
    required String menu,
    required List<String> options,
    List<String> without = const [],
    List<String> ask = const [],
  }) async {
    try {
      final json = await ApiClient.postJson('/ai/compose', {
        'menu_item': menu,
        'selected_options': options,
        'without': without,
        'ask': ask,
        'language': AppSession.language,
      });
      final cards = (json['cards'] as List? ?? const [])
          .cast<Map<String, dynamic>>();
      final meaning = (json['meaning'] as String? ?? '').trim();
      return ComposeResult(
        options: keyOf(options, without, ask),
        sentence: json['sentence'] as String,
        meaning: meaning,
        meanings: {
          for (final c in cards) c['word'] as String: c['meaning'] as String,
        },
        feedback: (json['feedback'] as String?)?.trim(),
      );
    } on Exception {
      return null;
    }
  }
}
