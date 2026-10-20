import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';
import 'app_icon.dart';

/// Animated sun/moon control that flips light and dark themes via SettingsProvider.
class ThemeToggleButton extends StatelessWidget {
  final double size;
  final bool compact;

  const ThemeToggleButton({super.key, this.size = 42, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isDark = settings.isDarkMode(context);
    final border = AppColors.borderOf(context);
    final iconColor = AppColors.textPrimaryOf(context);

    return Tooltip(
      message: isDark ? 'Switch to light mode' : 'Switch to dark mode',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => settings.toggleDarkMode(context),
          borderRadius: BorderRadius.circular(size),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.9),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.14) : border,
              ),
              boxShadow: compact
                  ? null
                  : [
                      BoxShadow(
                        color: isDark
                            ? AppColors.primaryPurple.withValues(alpha: 0.25)
                            : Colors.black.withValues(alpha: 0.06),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(
                      begin: 0.85,
                      end: 1,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Center(
                key: ValueKey(isDark),
                child: AppIcon(
                  isDark ? AppIcons.sun : AppIcons.moon,
                  size: size * 0.48,
                  color: isDark ? const Color(0xFFFFD56A) : iconColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
