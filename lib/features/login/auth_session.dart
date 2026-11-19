import 'package:shared_preferences/shared_preferences.dart';

import '../../app/router.dart';
import '../../app/session.dart';
import 'auth_api.dart';

/// 로그인 상태 저장·복원 (청온의 SharedPreferences "loginInfo"). 담당: 개발자1
abstract final class AuthSession {
  static const _token = 'accessToken';
  static const _userId = 'userId';
  static const _nickname = 'nickname';
  static const _language = 'language';
  static const _provider = 'authProvider';

  /// 로그인·가입 성공 응답(`access_token`, `user`)을 저장하고, 다음에 갈 화면 주소를 돌려줍니다.
  static Future<String> save(Map<String, dynamic> body) async {
    final token = body['access_token'] as String?;
    final user = body['user'] as Map<String, dynamic>? ?? const {};
    AppSession.accessToken = token;
    _apply(user);
    await _write({
      _token: token,
      _userId: AppSession.userId,
      _nickname: AppSession.nickname,
      _language: user['language'] as String?,
      _provider: user['auth_provider'] as String?,
    });
    return nextRoute(user);
  }

  /// 모국어를 아직 안 골랐으면 온보딩, 골랐으면 홈.
  static String nextRoute(Map<String, dynamic> user) =>
      user['language'] == null ? AppRoutes.onboarding : AppRoutes.home;

  /// 앱을 켰을 때: 저장된 토큰이 있으면 GET /auth/me로 확인합니다.
  /// 갈 화면 주소를 돌려주고, 다시 로그인해야 하면 null.
  static Future<String?> restore() async {
    final prefs = await _prefs();
    final token = prefs?.getString(_token);
    if (prefs == null || token == null) return null;

    AppSession.accessToken = token;
    try {
      final user = await AuthApi.me();
      _apply(user);
      return nextRoute(user);
    } on AuthException catch (e) {
      if (!e.offline) {
        await clear(); // 토큰 만료·삭제된 사용자
        return null;
      }
      // 서버가 잠깐 꺼져 있어도 시연이 끊기지 않게 저장해 둔 값으로 들어갑니다.
      AppSession.userId = prefs.getString(_userId);
      AppSession.nickname = prefs.getString(_nickname);
      final language = prefs.getString(_language);
      if (language != null) AppSession.language = language;
      return language == null ? AppRoutes.onboarding : AppRoutes.home;
    }
  }

  /// 온보딩·내 정보에서 바뀐 값을 반영합니다.
  static Future<void> update(Map<String, dynamic> user) async {
    _apply(user);
    await _write({
      _nickname: AppSession.nickname,
      _language: user['language'] as String?,
    });
  }

  static Future<void> clear() async {
    AppSession.accessToken = null;
    AppSession.userId = null;
    AppSession.nickname = null;
    final prefs = await _prefs();
    for (final key in [_token, _userId, _nickname, _language, _provider]) {
      await prefs?.remove(key);
    }
  }

  static void _apply(Map<String, dynamic> user) {
    final id = user['id'];
    if (id != null) AppSession.userId = '$id';
    AppSession.nickname = user['nickname'] as String? ?? AppSession.nickname;
    final language = user['language'] as String?;
    if (language != null) AppSession.language = language;
  }

  static Future<void> _write(Map<String, String?> values) async {
    final prefs = await _prefs();
    if (prefs == null) return;
    for (final MapEntry(:key, :value) in values.entries) {
      if (value == null) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, value);
      }
    }
  }

  /// 위젯 테스트처럼 저장소 플러그인이 없는 곳에서는 null (저장 없이 진행).
  static Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }
}
