/// 로그인 전까지 쓰는 간단한 앱 상태. 서버 연동(POST /users) 후 교체합니다.
abstract final class AppSession {
  /// 모국어 코드: vi, en, fil, km. 메뉴 카드의 뜻·설명 언어로 씁니다.
  static String language = 'vi';

  /// 지금 있는 가게 (places.id). 있으면 메뉴 인식에 업종 힌트가 들어갑니다.
  static String? placeId;
}
