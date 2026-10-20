import 'package:flutter/material.dart';

/// Centralized color palette for Pitch Coach design system.
abstract class AppColors {
  // Dark surfaces — Apple Space Black & System Gray materials
  static const Color background = Color(0xFF000000);
  static const Color backgroundElevated = Color(0xFF121214);
  static const Color cardDark = Color(0xFF1C1C1E);
  static const Color cardDarkElevated = Color(0xFF2C2C2E);
  static const Color cardDarkBorder = Color(0xFF38383A);
  static const Color glassDark = Color(0xCC1C1C1E);

  // Light surfaces
  static const Color surfaceLight = Color(0xFFF6F5FB);
  static const Color surfaceLightElevated = Color(0xFFFFFFFF);
  static const Color cardLightBorder = Color(0xFFE6E3F2);
  static const Color glassLight = Color(0xE6FFFFFF);

  // Brand
  static const Color primaryPurple = Color(0xFF8B7CFF);
  static const Color primaryPurpleLight = Color(0xFFB4A9FF);
  static const Color primaryPurpleDeep = Color(0xFF6354E0);
  static const Color gradientPurpleStart = Color(0xFF8B7CFF);
  static const Color gradientPurpleEnd = Color(0xFFC084FC);
  static const Color auroraCyan = Color(0xFF22D3EE);
  static const Color secondaryCyan = auroraCyan;
  static const Color cardLight = surfaceLightElevated;
  static const Color auroraPink = Color(0xFFF472B6);
  static const Color auroraIndigo = Color(0xFF6366F1);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [gradientPurpleStart, gradientPurpleEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient auroraGradient = LinearGradient(
    colors: [Color(0xFF8B7CFF), Color(0xFF22D3EE), Color(0xFFF472B6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = auroraGradient;

  static const LinearGradient heroDarkGradient = LinearGradient(
    colors: [Color(0xFF000000), Color(0xFF0A0A0E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient heroLightGradient = LinearGradient(
    colors: [Color(0xFFF7F6FB), Color(0xFFEEEAF8), Color(0xFFF3F7FC)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardDarkGradient = LinearGradient(
    colors: [Color(0xFF242428), Color(0xFF1C1C1E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Accents
  static const Color accentBlue = Color(0xFF60A5FA);
  static const Color accentBlueDark = Color(0xFF3B82F6);
  static const Color accentGreen = Color(0xFF34D399);
  static const Color accentGreenLight = Color(0xFF10B981);
  static const Color accentTeal = Color(0xFF2DD4BF);

  // Text
  static const Color textPrimaryDark = Color(0xFF15132A);
  static const Color textSecondary = Color(0xFF6B6885);
  static const Color textSecondaryOnDark = Color(0xFF8E8E93);
  static const Color textOnDark = Color(0xFFFFFFFF);
  static const Color textMutedOnDark = Color(0xFF636366);

  // Status
  static const Color successGreen = Color(0xFF30D158);
  static const Color warningAmber = Color(0xFFFF9F0A);
  static const Color dangerRed = Color(0xFFFF453A);
  static const Color errorRed = dangerRed;

  // UI chrome
  static const Color divider = Color(0xFFE7E5F0);
  static const Color dividerDark = Color(0xFF38383A);
  static const Color cardShadow = Color(0x140C0C1A);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color scaffoldOf(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;

  static Color cardOf(BuildContext context) =>
      isDark(context) ? cardDark : surfaceLightElevated;

  static Color elevatedCardOf(BuildContext context) =>
      isDark(context) ? cardDarkElevated : surfaceLightElevated;

  static Color borderOf(BuildContext context) =>
      isDark(context) ? cardDarkBorder : cardLightBorder;

  static Color textPrimaryOf(BuildContext context) =>
      isDark(context) ? textOnDark : textPrimaryDark;

  static Color textSecondaryOf(BuildContext context) =>
      isDark(context) ? textSecondaryOnDark : textSecondary;

  static Color glassOf(BuildContext context) =>
      isDark(context) ? glassDark : glassLight;

  static LinearGradient heroOf(BuildContext context) =>
      isDark(context) ? heroDarkGradient : heroLightGradient;

  static Color dividerOf(BuildContext context) =>
      isDark(context) ? dividerDark : divider;

  static Color iconButtonBgOf(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.08)
      : const Color(0xFFEBEBF5);

  static Color chipBgOf(BuildContext context) =>
      isDark(context) ? cardDark : surfaceLightElevated;

  static Color surfaceSubtleOf(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.05)
      : Colors.black.withValues(alpha: 0.04);

  static List<BoxShadow> softShadowOf(BuildContext context) {
    if (isDark(context)) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.28),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ];
    }
    return const [
      BoxShadow(color: cardShadow, blurRadius: 12, offset: Offset(0, 4)),
    ];
  }
}
