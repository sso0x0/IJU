import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../api/api_client.dart';
import '../../app/session.dart';

/// 로그인 API 오류. 서버가 준 [message]를 화면에 그대로 띄우고, 필요할 때만 [code]로 나눕니다.
class AuthException implements Exception {
  AuthException(this.status, this.code, this.message);

  /// HTTP 상태 코드 (서버에 못 붙으면 0)
  final int status;
  final String code;
  final String message;

  bool get offline => status == 0;

  @override
  String toString() => 'AuthException($status $code): $message';
}

/// 서버 /auth/* 호출 (server/AUTH.md). 담당: 개발자1
///
/// [ApiClient.postJson]은 실패하면 응답 본문을 버려서, 오류의 code·message를 읽으려고 따로 둡니다.
abstract final class AuthApi {
  static Future<Map<String, dynamic>> _send(
    String method,
    String path, [
    Map<String, Object?>? body,
  ]) async {
    final token = AppSession.accessToken;
    final req = http.Request(method, Uri.parse('${ApiClient.baseUrl}$path'))
      ..headers['Content-Type'] = 'application/json; charset=utf-8'
      ..headers.addAll({if (token != null) 'Authorization': 'Bearer $token'});
    if (body != null) req.body = jsonEncode(body);

    final http.Response res;
    try {
      final streamed = await req.send().timeout(const Duration(seconds: 12));
      res = await http.Response.fromStream(streamed);
    } catch (_) {
      throw AuthException(0, 'NETWORK', '서버에 연결하지 못했어요. 잠시 후 다시 시도해 주세요.');
    }

    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      json = decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      json = {};
    }
    if (res.statusCode != 200) {
      throw AuthException(
        res.statusCode,
        json['code'] as String? ?? '',
        json['message'] as String? ?? '다시 시도해 주세요.',
      );
    }
    return json;
  }

  static Future<Map<String, dynamic>> terms() => _send('GET', '/auth/terms');

  static Future<void> checkId(String loginId) =>
      _send('POST', '/auth/check-id', {'login_id': loginId});

  static Future<void> checkEmail(String email) =>
      _send('POST', '/auth/check-email', {'email': email});

  static Future<Map<String, dynamic>> signup(Map<String, Object?> body) =>
      _send('POST', '/auth/signup', body);

  static Future<Map<String, dynamic>> login(String loginId, String password) =>
      _send('POST', '/auth/login', {'login_id': loginId, 'password': password});

  static Future<Map<String, dynamic>> google(String idToken) => _send(
    'POST',
    '/auth/social',
    {'provider': 'google', 'id_token': idToken},
  );

  static Future<Map<String, dynamic>> googleSignup(Map<String, Object?> body) =>
      _send('POST', '/auth/social/signup', {'provider': 'google', ...body});

  static Future<Map<String, dynamic>> me() => _send('GET', '/auth/me');

  static Future<Map<String, dynamic>> updateMe(Map<String, Object?> body) =>
      _send('PATCH', '/auth/me', body);
}
