import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

abstract class AppTheme {
  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.surfaceLight,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryPurple,
        secondary: AppColors.accentBlue,
        surface: AppColors.surfaceLightElevated,
        error: AppColors.dangerRed,
        onPrimary: AppColors.textOnDark,
        onSecondary: AppColors.textOnDark,
        onSurface: AppColors.textPrimaryDark,
        outline: AppColors.cardLightBorder,
      ),
    );

    return base.copyWith(
      textTheme: _textTheme(Brightness.light),
      cardTheme: CardThemeData(
        color: AppColors.surfaceLightElevated,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.cardLightBorder),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimaryDark,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: AppTextStyles.headingM.copyWith(
          color: AppColors.textPrimaryDark,
        ),
      ),
      inputDecorationTheme: _inputTheme(Brightness.light),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimaryDark,
        contentTextStyle: AppTextStyles.bodyM.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
        elevation: 6,
      ),
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryPurpleLight,
        secondary: AppColors.accentBlue,
        surface: AppColors.cardDark,
        error: AppColors.dangerRed,
        onPrimary: AppColors.textOnDark,
        onSecondary: AppColors.textOnDark,
        onSurface: AppColors.textOnDark,
        outline: AppColors.cardDarkBorder,
      ),
    );

    return base.copyWith(
      textTheme: _textTheme(Brightness.dark),
      cardTheme: CardThemeData(
        color: AppColors.cardDark,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerDark,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cardDarkElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titleTextStyle: AppTextStyles.headingL.copyWith(
          color: AppColors.textOnDark,
        ),
        contentTextStyle: AppTextStyles.bodyM.copyWith(
          color: AppColors.textSecondaryOnDark,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryPurpleLight;
          }
          return AppColors.textSecondaryOnDark;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryPurple.withValues(alpha: 0.45);
          }
          return AppColors.cardDarkBorder;
        }),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textOnDark,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: AppTextStyles.headingM.copyWith(
          color: AppColors.textOnDark,
        ),
      ),
      inputDecorationTheme: _inputTheme(Brightness.dark),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.cardDark,
        contentTextStyle: AppTextStyles.bodyM.copyWith(
          color: AppColors.textOnDark,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
        elevation: 8,
      ),
    );
  }

  static TextTheme _textTheme(Brightness brightness) {
    final primary = brightness == Brightness.dark
        ? AppColors.textOnDark
        : AppColors.textPrimaryDark;
    final secondary = brightness == Brightness.dark
        ? AppColors.textSecondaryOnDark
        : AppColors.textSecondary;

    return TextTheme(
      displayLarge: AppTextStyles.displayLarge.copyWith(color: primary),
      headlineLarge: AppTextStyles.headingXL.copyWith(color: primary),
      headlineMedium: AppTextStyles.headingL.copyWith(color: primary),
      titleMedium: AppTextStyles.headingM.copyWith(color: primary),
      bodyLarge: AppTextStyles.bodyM.copyWith(color: primary, fontSize: 16),
      bodyMedium: AppTextStyles.bodyM.copyWith(color: secondary),
      bodySmall: AppTextStyles.bodySmallBold.copyWith(color: secondary),
      labelSmall: AppTextStyles.caption.copyWith(color: secondary),
    );
  }

  static InputDecorationTheme _inputTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final fill = isDark ? AppColors.backgroundElevated : Colors.white;
    final border = isDark
        ? AppColors.cardDarkBorder
        : AppColors.cardLightBorder;

    OutlineInputBorder outline(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: 1.2),
    );

    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: AppTextStyles.bodyM.copyWith(
        color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93),
      ),
      labelStyle: AppTextStyles.label.copyWith(
        color: isDark ? AppColors.textOnDark : AppColors.textPrimaryDark,
      ),
      border: outline(border),
      enabledBorder: outline(border),
      focusedBorder: outline(AppColors.primaryPurple),
      errorBorder: outline(AppColors.dangerRed),
    );
  }
}
