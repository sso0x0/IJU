import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// 이주 API 서버(server/) 호출 공용 클라이언트.
///
/// 주소는 `--dart-define=API_BASE_URL=http://192.168.0.10:8000`으로 바꿀 수 있고,
/// 없으면 Android 에뮬레이터는 10.0.2.2, 나머지(웹·iOS 시뮬레이터)는 127.0.0.1을 씁니다.
/// (localhost는 IPv6(::1)로 먼저 붙어 서버가 0.0.0.0에만 열려 있으면 멈출 수 있음)
abstract final class ApiClient {
  static const _defined = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_defined.isNotEmpty) return _defined;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  /// JSON을 보내고 JSON을 받습니다. 연결 실패·시간 초과·4xx/5xx는 [ApiException].
  static Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, Object?> body, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl$path'),
            headers: const {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode(body),
          )
          .timeout(timeout);
      if (res.statusCode != 200) {
        throw ApiException('$path → ${res.statusCode}');
      }
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('$path → $e');
    }
  }
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => 'ApiException: $message';
}
