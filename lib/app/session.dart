import 'package:flutter/foundation.dart' show ValueNotifier;

import 'diet.dart';

/// 로그인한 사용자 정보. 서버 호출 때 학습자 모국어를 같이 보냅니다.
///
/// 로그인·가입하면 features/login/auth_session.dart가 [accessToken], [userId], [nickname],
/// [language]를 채웁니다. 로그인 없이 둘러볼 때는 시연 기본값(베트남어)입니다.
abstract final class AppSession {
  /// 서버 schemas.py의 Language: vi, en, fil, km, ko
  /// 메뉴 카드의 뜻·설명 언어로도 씁니다.
  static String language = 'vi';

  /// 서버 users.id. 다른 API의 user_id로 보냅니다 (없으면 시연용 사용자).
  static String? userId;

  /// POST /auth/login 등에서 받은 토큰. 있으면 Authorization 헤더로 보냅니다.
  static String? accessToken;

  static String? nickname;

  static bool get loggedIn => accessToken != null;

  /// 지금 있는 가게 (places.id). 있으면 메뉴 인식에 업종 힌트가 들어갑니다.
  static String? placeId;

  /// 온보딩·내 정보에서 고른 식단(채식 단계)과 종교. 여러 개를 고를 수 있습니다.
  /// 문장 만들기에서 ‘빼 주세요’·‘들어가요?’를 미리 골라 두는 데 씁니다.
  static final diets = ValueNotifier<Set<Diet>>(const {});
}
