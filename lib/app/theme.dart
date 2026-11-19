import 'package:material_ui/material_ui.dart';

import 'colors.dart';

/// 디자인 시스템의 글꼴·모양 값.
///
/// 한글 = 경기천년제목(GyeonggiTitle), 라틴 문자·숫자·베트남어·크메르어 = Noto Sans.
///
/// assets/fonts/GyeonggiTitle-Medium.ttf는 한글 범위만 들어 있어서, 영문·숫자·베트남어는
/// 자동으로 [fallback]의 Noto Sans(없으면 기기 기본 글꼴 Roboto)로 그려집니다.
/// 경기천년제목은 Medium 한 굵기라 굵은 글씨는 기기가 굵게 합성합니다.
abstract final class AppFonts {
  static const String korean = 'GyeonggiTitle';
  static const String latin = 'Noto Sans';
  static const List<String> fallback = [
    latin,
    'Roboto',
    'Noto Sans Khmer',
    'NotoSansKR',
  ];

  /// 모국어·발음 문구용 (Noto Sans 먼저).
  static const List<String> latinFallback = [korean, 'Noto Sans Khmer'];
}

/// 반경 · 터치 · 8pt 그리드.
abstract final class AppRadius {
  static const double card = 20;
  static const double button = 16;
  static const double input = 14;
  static const double sheet = 28;
  static const double section = 24;
}

abstract final class AppSpace {
  static const double buttonHeight = 56;
  static const double touch = 48;
}

/// 글꼴 단계 (00 디자인 시스템 · 글꼴).
abstract final class AppText {
  /// 학습 문장 Display · 32 · 굵게 · 행간 1.3
  static const TextStyle display = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: -0.6,
    color: AppColors.text,
  );

  /// 제목 Title · 24 · 굵게
  static const TextStyle title = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: -0.4,
    color: AppColors.text,
  );

  /// 소제목 Subtitle · 20
  static const TextStyle subtitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: AppColors.text,
  );

  /// 본문 Body · 17 · 행간 1.5
  static const TextStyle body = TextStyle(
    fontSize: 17,
    height: 1.5,
    color: AppColors.textBody,
  );

  /// 캡션 Caption · 14
  static const TextStyle caption = TextStyle(
    fontSize: 14,
    height: 1.4,
    color: AppColors.textSub,
  );

  /// 모국어 뜻 · Noto Sans 15 · 보조색
  static const TextStyle native = TextStyle(
    fontFamily: AppFonts.latin,
    fontFamilyFallback: AppFonts.latinFallback,
    fontSize: 15,
    height: 1.4,
    fontWeight: FontWeight.w500,
    color: AppColors.textBody,
  );

  /// 발음 · Noto Sans 14 · 보조색
  static const TextStyle romanization = TextStyle(
    fontFamily: AppFonts.latin,
    fontFamilyFallback: AppFonts.latinFallback,
    fontSize: 14,
    height: 1.35,
    color: AppColors.textSub,
  );

  /// 가격·포인트 같은 숫자 (탭 숫자).
  static const TextStyle number = TextStyle(
    fontFamily: AppFonts.latin,
    fontFamilyFallback: AppFonts.latinFallback,
    fontWeight: FontWeight.w800,
    fontFeatures: [FontFeature.tabularFigures()],
    color: AppColors.text,
  );
}

abstract final class AppTheme {
  /// web/manifest.json의 theme_color와 같은 값으로 유지합니다.
  static const Color seedColor = AppColors.primary;

  static final ThemeData light = _build();

  static ThemeData _build() {
    final scheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      error: AppColors.danger,
      outline: AppColors.border,
    );
    final base = ThemeData(
      colorScheme: scheme,
      fontFamily: AppFonts.korean,
      fontFamilyFallback: AppFonts.fallback,
      scaffoldBackgroundColor: AppColors.surface,
      dividerColor: AppColors.divider,
      splashFactory: InkSparkle.splashFactory,
    );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.button),
    );
    const buttonText = TextStyle(fontSize: 18, fontWeight: FontWeight.w700);
    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: AppFonts.korean,
          fontFamilyFallback: AppFonts.fallback,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.disabledBg,
          disabledForegroundColor: AppColors.disabledText,
          minimumSize: const Size.fromHeight(AppSpace.buttonHeight),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryDark,
          side: const BorderSide(color: AppColors.primary, width: 2),
          minimumSize: const Size.fromHeight(AppSpace.buttonHeight),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryDark,
          minimumSize: const Size(AppSpace.touch, AppSpace.touch),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: const TextStyle(color: AppColors.textSub),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        modalBarrierColor: AppColors.scrim,
        showDragHandle: true,
        dragHandleColor: AppColors.disabledBg,
        dragHandleSize: Size(44, 5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.section),
        ),
        titleTextStyle: AppText.subtitle.copyWith(
          fontFamily: AppFonts.korean,
          fontFamilyFallback: AppFonts.fallback,
        ),
        contentTextStyle: AppText.body.copyWith(
          fontFamily: AppFonts.korean,
          fontFamilyFallback: AppFonts.fallback,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.dark,
        contentTextStyle: const TextStyle(
          fontFamily: AppFonts.korean,
          fontFamilyFallback: AppFonts.fallback,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.background,
        circularTrackColor: AppColors.primarySoft,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.borderStrong,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.primary
              : Colors.transparent,
        ),
        side: const BorderSide(color: AppColors.borderStrong, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }
}
