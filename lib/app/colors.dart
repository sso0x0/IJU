import 'package:material_ui/material_ui.dart';

/// '이주 (이거 주세요) UI/UX' 디자인 시스템(00 디자인 시스템)의 색상 값.
/// 화면에서는 색을 직접 쓰지 말고 여기서 가져다 씁니다.
///
/// 깨끗한 흰 바탕 위에 초록과 오렌지 두 색만 씁니다. 판정(먹어도 돼요·물어보세요·
/// 피하세요) 색은 학습·보상 오렌지와 섞지 않습니다.
abstract final class AppColors {
  // 브랜드 · Primary (로고 초록 #007354 기준)
  static const Color primary900 = Color(0xFF003F2E); // 눌림·진한 제목
  static const Color primaryDark = Color(0xFF005A41); // 800 링크·아이콘 글자
  static const Color primary = Color(0xFF007354); // 700 버튼·강조·로고
  static const Color primary200 = Color(0xFFB8DCCF); // 테두리·비활성
  static const Color primarySoft = Color(0xFFDCEFE7); // 100 선택 배경·링
  static const Color primary50 = Color(0xFFEFF7F3); // 옅은 배경

  /// 초록 바탕 위의 흐린 글자.
  static const Color onPrimaryMuted = Color(0xFFD7E6E0);

  // 글자 (본문 대비 4.5:1 이상)
  static const Color text = Color(0xFF1B1F1D); // 제목·학습 문장
  static const Color textBody = Color(0xFF4A504C); // 본문
  static const Color textSub = Color(0xFF6B716D); // 발음·모국어·캡션

  // 선·배경
  static const Color border = Color(0xFFE3E7E5);
  static const Color divider = Color(0xFFE3E7E5);
  static const Color borderStrong = Color(0xFFB6BEB9);
  static const Color surface = Colors.white;

  /// 옅은 채움 (안내 박스·트랙·탭 화면 바탕).
  static const Color background = Color(0xFFF3F5F4);
  static const Color skeleton = Color(0xFFEDF0EE);
  static const Color dark = Color(0xFF1B1F1D);
  static const Color scrim = Color(0x731B1F1D);

  // 비활성 버튼
  static const Color disabledBg = Color(0xFFD2D8D4);
  static const Color disabledText = Color(0xFF5F6561);

  // 학습·보상 오렌지: 빈칸·조사/어미·포인트·쿠폰에만.
  // 흰 바탕 위 오렌지 글자는 대비가 낮아서 글자는 [pointText]를 씁니다.
  static const Color accent = Color(0xFFFF8A3D);
  static const Color pointBg = Color(0xFFFFEBDD);
  static const Color pointText = Color(0xFFB4530A);
  static const Color couponText = Color(0xFFB4530A);
  static const Color couponTextStrong = Color(0xFF7A3805);

  // 인식 신뢰도 낮음: 판정 색과 겹치지 않는 회색 점선 + "확인해 주세요".
  static const Color warnBg = Color(0xFFF3F5F4);
  static const Color warnBorder = Color(0xFF8A908C);
  static const Color warnText = Color(0xFF4A504C);

  // 판정 · 색만으로 구분하지 않아요 (아이콘 + 글자 + 색)
  static const Color safe = Color(0xFF1E7B3A); // 먹어도 돼요
  static const Color safeBg = Color(0xFFE6F4EA);
  static const Color caution = Color(0xFFF2B200); // 물어보세요 포인트
  static const Color cautionBg = Color(0xFFFFF3C4);
  static const Color cautionText = Color(0xFF6B4A00);
  static const Color danger = Color(0xFFD93025); // 피하세요 포인트
  static const Color dangerBg = Color(0xFFFDE8E6);
  static const Color dangerText = Color(0xFFA3261D);

  // 메뉴판 촬영 · 칠판 메뉴판 그림 (C1~C3, C6)
  static const Color camera = Color(0xFF0E1210); // 촬영 화면 바탕
  static const Color onCameraMuted = Color(0xFFC9D3CE);
  static const Color scanLine = Color(0xFF7EE0B8); // 읽는 중 스캔 줄
  static const Color board = Color(0xFF26352E); // 칠판
  static const Color boardFrame = Color(0xFF8B6A47); // 나무 틀
  static const Color chalk = Color(0xFFF4F1E8); // 분필 글씨
  static const Color chalkTitle = Color(0xFFFFE9A8);

  /// 어두운 칠판 위 판정 테두리 (밝게).
  static const Color boardSafe = Color(0xFF5CC27E);
  static const Color boardDanger = Color(0xFFFF6B5E);
  static const Color tabTrack = Color(0xFFEEF1EF);
}
