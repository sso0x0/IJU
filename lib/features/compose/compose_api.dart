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

  /// 요청에 보낸 옵션. 응답이 늦게 와도 지금 고른 조합과 같은지 비교하는 데 씁니다.
  final List<String> options;
  final String sentence;
  final String meaning;

  /// 카드 단어 → 학습자 언어 뜻
  final Map<String, String> meanings;
  final String? feedback;
}

abstract final class ComposeApi {
  /// 서버가 꺼져 있거나 실패하면 null. 화면은 자체 조립 결과를 계속 보여 줍니다.
  static Future<ComposeResult?> compose({
    required String menu,
    required List<String> options,
  }) async {
    try {
      final json = await ApiClient.postJson('/ai/compose', {
        'menu_item': menu,
        'selected_options': options,
        'language': AppSession.language,
      });
      final cards = (json['cards'] as List? ?? const [])
          .cast<Map<String, dynamic>>();
      final meaning = (json['meaning'] as String? ?? '').trim();
      return ComposeResult(
        options: List.unmodifiable(options),
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
