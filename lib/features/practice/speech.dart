import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// 기기 기본 음성인식(STT)과 음성합성(TTS). Android·iOS·웹(Chrome Web Speech API) 모두 동작합니다.
///
/// 플러그인은 처음 쓸 때 초기화합니다 (위젯 테스트에서 화면만 띄울 때는 건드리지 않게).
class Speech {
  final _stt = SpeechToText();
  FlutterTts? _tts;
  bool? _sttReady;

  /// 한국어 TTS 기본 속도. 플랫폼마다 '보통'의 값이 다릅니다.
  static double get _normalRate => kIsWeb ? 0.9 : 0.5;

  Future<void> speak(String text, {bool slow = false}) async {
    final tts = _tts ??= await _initTts();
    await tts.stop();
    await tts.setSpeechRate(_normalRate * (slow ? 0.55 : 1));
    await tts.speak(text);
  }

  Future<FlutterTts> _initTts() async {
    final tts = FlutterTts();
    await tts.setLanguage('ko-KR');
    await tts.setPitch(1);
    return tts;
  }

  /// 마이크 권한을 묻고 음성인식을 준비합니다. 권한 거부·미지원이면 false.
  Future<bool> _ensureStt() async {
    if (_sttReady == true) return true;
    _sttReady = await _stt.initialize(
      onError: (e) => _onError?.call(e),
      onStatus: (s) => _onStatus?.call(s),
    );
    return _sttReady!;
  }

  void Function(SpeechRecognitionError)? _onError;
  void Function(String)? _onStatus;

  bool get isListening => _stt.isListening;

  /// 듣기 시작. [onWords]는 말하는 동안 계속, [onDone]은 끝났을 때 한 번(최종 문장, 빈 문자열 가능).
  Future<bool> listen({
    required void Function(String words) onWords,
    required void Function(String words) onDone,
    void Function(double level)? onLevel,
  }) async {
    if (!await _ensureStt()) return false;
    await _tts?.stop();

    var words = '';
    var finished = false;
    void finish() {
      if (finished) return;
      finished = true;
      onDone(words);
    }

    _onError = (_) => finish();
    _onStatus = (status) {
      if (status == SpeechToText.doneStatus ||
          status == SpeechToText.notListeningStatus) {
        // 최종 결과가 상태 변경보다 조금 늦게 오는 기기가 있어 잠깐 기다립니다.
        Timer(const Duration(milliseconds: 400), finish);
      }
    };

    await _stt.listen(
      onSoundLevelChange: onLevel,
      listenOptions: SpeechListenOptions(
        localeId: 'ko_KR',
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      ),
      onResult: (SpeechRecognitionResult r) {
        words = r.recognizedWords;
        onWords(words);
        if (r.finalResult) finish();
      },
    );
    return true;
  }

  /// 사용자가 다시 눌러 끝냄. 결과는 listen의 onDone으로 옵니다.
  Future<void> stop() => _stt.stop();

  Future<void> dispose() async {
    await _stt.cancel();
    await _tts?.stop();
  }
}
