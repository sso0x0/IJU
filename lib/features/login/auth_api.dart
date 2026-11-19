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

/// 서버 /auth/* 호출 (README.md). 담당: 개발자1
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

  static Future<void> changePassword(String current, String next) => _send(
    'POST',
    '/auth/password',
    {'current_password': current, 'new_password': next},
  );

  // ---- 내 학습 데이터 (server/app/routers/me.py). 로그인 토큰으로 사용자를 찾습니다. ----

  static Future<Map<String, dynamic>> reviews() => _send('GET', '/me/reviews');

  static Future<Map<String, dynamic>> saveReview(Map<String, Object?> body) =>
      _send('POST', '/me/reviews', body);

  static Future<Map<String, dynamic>> orderPlaces() =>
      _send('GET', '/me/order-places');

  static Future<Map<String, dynamic>> saveOrderPlace(
    Map<String, Object?> body,
  ) => _send('POST', '/me/order-places', body);

  static Future<Map<String, dynamic>> stats() => _send('GET', '/me/stats');

  // ---------- 커뮤니티 (server/app/routers/community.py) ----------

  /// 글 목록. [following]이면 팔로우한 사람 글만, [mine]이면 내 글만.
  static Future<Map<String, dynamic>> communityPosts({
    bool following = false,
    bool mine = false,
    int offset = 0,
    int limit = 10,
  }) => _send(
    'GET',
    '/community/posts?following=$following&offset=$offset&limit=$limit'
        '${mine ? '&author=me' : ''}',
  );

  static Future<Map<String, dynamic>> writePost(Map<String, Object?> body) =>
      _send('POST', '/community/posts', body);

  /// '커뮤니티 지도에 공유'를 켠 사람들의 내 지도 가게.
  static Future<Map<String, dynamic>> sharedPlaces({bool following = false}) =>
      _send('GET', '/community/shared-places?following=$following');

  static Future<void> deletePost(String id) =>
      _send('DELETE', '/community/posts/$id');

  static Future<void> follow(String userId, {required bool on}) =>
      _send(on ? 'POST' : 'DELETE', '/community/follow/$userId');
}
