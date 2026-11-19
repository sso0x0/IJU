import '../../api/api_client.dart';
import '../../app/session.dart';

/// POST /ai/pronunciation 응답 (server/app/schemas.py PronunciationOut).
class PronunciationResult {
  const PronunciationResult({
    required this.transcript,
    required this.score,
    required this.wrongWords,
    required this.feedback,
  });

  final String transcript;
  final int score;

  /// [transcript]의 어절 중 틀린 것. 화면에서 주황으로 칠합니다.
  final List<String> wrongWords;
  final String feedback;
}

abstract final class PracticeApi {
  /// 서버가 꺼져 있으면 기기에서 간단히 채점합니다.
  static Future<PronunciationResult> score({
    required String transcript,
    required String target,
  }) async {
    try {
      final json = await ApiClient.postJson('/ai/pronunciation', {
        'transcript': transcript,
        'target_sentence': target,
        'language': AppSession.language,
      });
      return PronunciationResult(
        transcript: json['transcript'] as String,
        score: json['score'] as int,
        wrongWords: (json['wrong_words'] as List).cast<String>(),
        feedback: json['feedback'] as String,
      );
    } on ApiException {
      return localScore(transcript: transcript, target: target);
    }
  }

  /// 서버 없이 쓰는 간단 채점: 문장부호·띄어쓰기를 뺀 글자 편집 거리.
  static PronunciationResult localScore({
    required String transcript,
    required String target,
  }) {
    String clean(String s) => s.replaceAll(RegExp(r'[\s.,!?~]'), '');
    final a = clean(transcript);
    final b = clean(target);
    final longest = a.length > b.length ? a.length : b.length;
    final score = longest == 0
        ? 0
        : (100 * (1 - _distance(a, b) / longest)).round().clamp(0, 100);
    final targetWords = {for (final w in target.split(' ')) clean(w)};
    final wrong = [
      for (final w in transcript.split(RegExp(r'\s+')))
        if (w.isNotEmpty && !targetWords.contains(clean(w))) w,
    ];
    return PronunciationResult(
      transcript: transcript,
      score: score,
      wrongWords: score == 100 ? const [] : wrong,
      feedback: score == 100
          ? '정확해요! 이 문장 그대로 가게에서 말해 보세요.'
          : '‘정답 듣기’로 들어 보고 다시 말해 보세요.',
    );
  }

  static int _distance(String a, String b) {
    var prev = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        cur[j] = [
          prev[j] + 1,
          cur[j - 1] + 1,
          prev[j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
      prev = cur;
    }
    return prev[b.length];
  }
}
