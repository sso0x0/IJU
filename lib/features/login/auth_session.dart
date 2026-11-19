import 'package:shared_preferences/shared_preferences.dart';

import '../../app/diet.dart';
import '../../app/router.dart';
import '../../app/session.dart';
import '../order_map/order_place_store.dart';
import '../review/review_store.dart';
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
    _loadUserData();
    return nextRoute(user);
  }

  /// 내 복습 목록·주문 지도를 서버에서 불러옵니다 (기다리지 않음).
  static void _loadUserData() {
    ReviewStore.load();
    OrderPlaceStore.load();
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
      _loadUserData();
      return nextRoute(user);
    } on AuthException catch (e) {
      if (!e.offline) {
        await clear(); // 토큰 만료·삭제된 사용자
        return null;
      }
      // 서버가 잠깐 꺼져 있어도 시연이 끊기지 않게 저장해 둔 값으로 들어갑니다.
      AppSession.userId = prefs.getString(_userId);
      AppSession.nickname = prefs.getString(_nickname);
      AppSession.authProvider = prefs.getString(_provider);
      final language = prefs.getString(_language);
      if (language != null) AppSession.language = language;
      _loadUserData(); // 못 불러오면 빈 목록에서 시작
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

  /// 식단·종교를 바꿨을 때: 바로 반영하고, 로그인했으면 계정에도 저장합니다
  /// (PATCH /auth/me diets). 저장에 실패해도 이 기기에서는 바뀐 값을 씁니다.
  static Future<void> saveDiets(Set<Diet> diets) async {
    AppSession.diets.value = diets;
    if (!AppSession.loggedIn) return;
    try {
      await AuthApi.updateMe({
        'diets': [for (final d in diets) d.name],
      });
    } on AuthException {
      // 다음에 식단을 다시 저장하면 올라가요.
    }
  }

  /// '커뮤니티 지도에 공유' 켜기/끄기 (PATCH /auth/me share_map).
  /// 실패하면 원래 값으로 되돌리고 [AuthException]을 던집니다.
  static Future<void> saveShareMap(bool on) async {
    final before = AppSession.shareMap.value;
    AppSession.shareMap.value = on;
    try {
      await AuthApi.updateMe({'share_map': on});
    } on AuthException {
      AppSession.shareMap.value = before;
      rethrow;
    }
  }

  static Future<void> clear() async {
    AppSession.accessToken = null;
    AppSession.userId = null;
    AppSession.nickname = null;
    AppSession.authProvider = null;
    AppSession.diets.value = const {};
    AppSession.shareMap.value = false;
    // 다른 사람이 로그인 없이 둘러봐도 내 기록이 보이지 않게 시연 데이터로 되돌립니다.
    ReviewStore.reset();
    OrderPlaceStore.reset();
    final prefs = await _prefs();
    for (final key in [_token, _userId, _nickname, _language, _provider]) {
      await prefs?.remove(key);
    }
  }

  static void _apply(Map<String, dynamic> user) {
    final id = user['id'];
    if (id != null) AppSession.userId = '$id';
    AppSession.nickname = user['nickname'] as String? ?? AppSession.nickname;
    AppSession.authProvider =
        user['auth_provider'] as String? ?? AppSession.authProvider;
    final language = user['language'] as String?;
    if (language != null) AppSession.language = language;
    // 계정에 저장된 식단·종교와 지도 공유 설정 (모르는 이름은 건너뜀)
    final diets = user['diets'];
    if (diets is List) {
      AppSession.diets.value = {
        for (final name in diets)
          for (final d in Diet.values)
            if (d.name == name) d,
      };
    }
    final share = user['share_map'];
    if (share is bool) AppSession.shareMap.value = share;
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
