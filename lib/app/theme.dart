import 'package:material_ui/material_ui.dart';

import 'colors.dart';

abstract final class AppTheme {
  /// web/manifest.json의 theme_color와 같은 값으로 유지합니다.
  static const Color seedColor = Color(0xFF2E7D5B);

  static final ThemeData light = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: seedColor,
      primary: AppColors.primary,
      surface: AppColors.surface,
    ),
    scaffoldBackgroundColor: AppColors.surface,
  );
}
