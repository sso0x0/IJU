import 'package:material_ui/material_ui.dart';

/// Figma '이주 앱 화면 구성'의 색상 값. 화면에서는 색을 직접 쓰지 말고 여기서 가져다 씁니다.
abstract final class AppColors {
  // 브랜드
  static const Color primary = Color(0xFF0E7C5A);
  static const Color primaryDark = Color(0xFF0A5C43);
  static const Color primarySoft = Color(0xFFE7F4EF);
  static const Color onPrimaryMuted = Color(0xFFCFEDE2);

  // 글자
  static const Color text = Color(0xFF1A1D21);
  static const Color textBody = Color(0xFF4A4F57);
  static const Color textSub = Color(0xFF5A606A);

  // 선·배경
  static const Color border = Color(0xFFD5D8DD);
  static const Color divider = Color(0xFFE3E6E9);
  static const Color surface = Colors.white;
  static const Color background = Color(0xFFF4F6F5);
  static const Color dark = Color(0xFF23272D);

  static const Color borderStrong = Color(0xFFB5BAC1);
  static const Color darkChip = Color(0xFF2E3239);

  // 포인트
  static const Color pointBg = Color(0xFFFFE3CC);
  static const Color pointText = Color(0xFF7A3A0A);

  // 쿠폰·빈칸 강조 (주황)
  static const Color accent = Color(0xFFFFB27A);
  static const Color couponText = Color(0xFF5C2A05);
  static const Color couponTextStrong = Color(0xFF3D1C03);

  // 경고 (인식 신뢰도 낮음)
  static const Color warnBg = Color(0xFFFFF6EE);
  static const Color warnBorder = Color(0xFFC2620F);
  static const Color warnText = Color(0xFF8A4208);

  // 재료 주의: 빨강(들어 있음) / 노랑(숨어 있을 수 있음)
  static const Color danger = Color(0xFFD93025);
  static const Color dangerBg = Color(0xFFFDECEA);
  static const Color dangerText = Color(0xFF8C1D18);
  static const Color caution = Color(0xFFE8A100);
  static const Color cautionBg = Color(0xFFFFF6D6);
  static const Color cautionText = Color(0xFF6B4A00);
}
