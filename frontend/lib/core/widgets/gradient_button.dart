import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

enum GradientButtonVariant { primary, secondary, tertiary }

class GradientButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final GradientButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final double? width;
  final double height;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? textColor;
  final bool enableScaleAnimation;

  const GradientButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = GradientButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.width,
    this.height = 56,
    this.backgroundColor,
    this.borderColor,
    this.textColor,
    this.enableScaleAnimation = true,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = widget.onPressed == null || widget.isLoading;

    BoxDecoration decoration;
    TextStyle textStyle;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (widget.variant) {
      case GradientButtonVariant.primary:
        final effectiveBg = widget.backgroundColor ?? (isDark ? Colors.white : null);
        final hasCustomOrDarkBg = widget.backgroundColor != null || isDark;

        decoration = BoxDecoration(
          color: effectiveBg,
          gradient: hasCustomOrDarkBg
              ? null
              : (isDisabled
                    ? LinearGradient(
                        colors: [
                          AppColors.gradientPurpleStart.withValues(alpha: 0.5),
                          AppColors.gradientPurpleEnd.withValues(alpha: 0.5),
                        ],
                      )
                    : AppColors.primaryGradient),
          borderRadius: BorderRadius.circular(28),
          boxShadow: isDisabled
              ? []
              : [
                  BoxShadow(
                    color: hasCustomOrDarkBg
                        ? Colors.black.withValues(alpha: 0.20)
                        : AppColors.primaryPurple.withValues(alpha: 0.35),
                    blurRadius: hasCustomOrDarkBg ? 10 : 16,
                    offset: hasCustomOrDarkBg
                        ? const Offset(0, 3)
                        : const Offset(0, 6),
                  ),
                ],
        );
        textStyle = AppTextStyles.headingM.copyWith(
          color: widget.textColor ?? (isDark ? Colors.black : AppColors.textOnDark),
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        );
        break;

      case GradientButtonVariant.secondary:
        final Color defaultBg = isDark
            ? const Color(0xFF1C1C1E)
            : (widget.textColor == Colors.white
                  ? Colors.white.withValues(alpha: 0.08)
                  : AppColors.surfaceLightElevated);

        decoration = BoxDecoration(
          color: widget.backgroundColor ?? defaultBg,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color:
                widget.borderColor ??
                (isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : AppColors.cardLightBorder),
            width: 0.8,
          ),
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : ((widget.backgroundColor != null ||
                      widget.textColor == Colors.white)
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]),
        );
        textStyle = AppTextStyles.headingM.copyWith(
          color: widget.textColor ?? (isDark ? Colors.white : AppColors.textPrimaryOf(context)),
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        );
        break;

      case GradientButtonVariant.tertiary:
        decoration = BoxDecoration(
          color: widget.backgroundColor ?? Colors.transparent,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color:
                widget.borderColor ??
                (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : AppColors.textSecondary.withValues(alpha: 0.35)),
            width: 0.8,
          ),
        );
        textStyle = AppTextStyles.headingM.copyWith(
          color: widget.textColor ?? (isDark ? const Color(0xFF8E8E93) : AppColors.textPrimaryOf(context)),
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        );
        break;
    }

    final buttonContent = Container(
      width: widget.width ?? double.infinity,
      height: widget.height,
      decoration: decoration,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled ? null : widget.onPressed,
          onTapDown: widget.enableScaleAnimation && !isDisabled
              ? (_) => setState(() => _isPressed = true)
              : null,
          onTapUp: widget.enableScaleAnimation && !isDisabled
              ? (_) => setState(() => _isPressed = false)
              : null,
          onTapCancel: widget.enableScaleAnimation && !isDisabled
              ? () => setState(() => _isPressed = false)
              : null,
          borderRadius: BorderRadius.circular(28),
          splashColor: Colors.white10,
          highlightColor: Colors.white12,
          child: Center(
            child: widget.isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        widget.textColor ??
                            (widget.variant == GradientButtonVariant.tertiary
                                ? AppColors.primaryPurple
                                : AppColors.textOnDark),
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, size: 20, color: textStyle.color),
                        const SizedBox(width: 8),
                      ],
                      Text(widget.text, style: textStyle),
                    ],
                  ),
          ),
        ),
      ),
    );

    if (!widget.enableScaleAnimation || isDisabled) {
      return buttonContent;
    }

    return AnimatedScale(
      scale: _isPressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOutCubic,
      child: buttonContent,
    );
  }
}
