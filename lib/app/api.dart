import 'package:flutter/foundation.dart';

/// 서버 주소.
///
/// 실기기에서는 `--dart-define=API_BASE_URL=http://<노트북 IP>:8000`으로 실행하세요.
/// 지정하지 않으면 Android 에뮬레이터는 10.0.2.2, 그 외(웹·iOS 시뮬레이터)는 localhost를 씁니다.
abstract final class Api {
  static const _fromEnv = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_fromEnv.isNotEmpty) return _fromEnv;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }
}
