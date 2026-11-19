/// 로그인한 사용자 정보. 서버 호출 때 학습자 모국어를 같이 보냅니다.
///
/// TODO(개발자1): 온보딩에서 POST /users 후 [language], [userId]를 채워 주세요.
/// 지금은 시연 기본값(베트남어)입니다.
abstract final class AppSession {
  /// 서버 schemas.py의 Language: vi, en, fil, km, ko
  static String language = 'vi';
  static String? userId;
}
