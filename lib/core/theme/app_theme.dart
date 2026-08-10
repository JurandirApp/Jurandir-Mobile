import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Tema base do app (creme claro). O corpo usa Hanken Grotesk; títulos usam
/// Bricolage via [AppText].
abstract final class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.canvas,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.coral,
        brightness: Brightness.light,
      ).copyWith(surface: AppColors.canvas),
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        fontFamily: 'Hanken Grotesk',
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
      ),
    );
  }
}
