import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Soft atmospheric backdrop.
///
/// Important for mobile performance:
/// - Never rebuilds [child] on the drift ticker
/// - Avoids [ImageFiltered] blurs (very expensive on phones)
/// - Disables continuous motion on phones so nav stays responsive
class AppAtmosphere extends StatefulWidget {
  final Widget child;
  final bool safeArea;

  const AppAtmosphere({super.key, required this.child, this.safeArea = true});

  @override
  State<AppAtmosphere> createState() => _AppAtmosphereState();
}

class _AppAtmosphereState extends State<AppAtmosphere>
    with SingleTickerProviderStateMixin {
  AnimationController? _drift;

  bool get _shouldAnimate {
    if (kIsWeb) return true;
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disableAnimations) return false;
    final view = View.maybeOf(context);
    final shortest = view?.physicalSize.shortestSide;
    final dpr = view?.devicePixelRatio ?? 1.0;
    if (shortest != null && shortest / dpr < 600) return false;
    return true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate = _shouldAnimate;
    if (animate && _drift == null) {
      _drift = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 14),
      )..repeat(reverse: true);
    } else if (!animate && _drift != null) {
      _drift!.dispose();
      _drift = null;
    }
  }

  @override
  void dispose() {
    _drift?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.safeArea
        ? SafeArea(child: widget.child)
        : widget.child;

    final backdrop = _drift == null
        ? const _AtmosphereBackdrop(t: 0.35)
        : AnimatedBuilder(
            animation: _drift!,
            builder: (context, _) {
              final t = Curves.easeInOut.transform(_drift!.value);
              return _AtmosphereBackdrop(t: t);
            },
          );

    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(child: backdrop),
        content,
      ],
    );
  }
}

class _AtmosphereBackdrop extends StatelessWidget {
  final double t;

  const _AtmosphereBackdrop({required this.t});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(gradient: AppColors.heroOf(context)),
          ),
          if (isDark)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.0, -0.9),
                  radius: 0.9,
                  colors: [
                    const Color(0xFF6366F1).withValues(alpha: 0.07),
                    Colors.transparent,
                  ],
                ),
              ),
            )
          else ...[
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.15 + t * 0.2, -0.85),
                  radius: 1.2,
                  colors: [
                    AppColors.primaryPurple.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Positioned(
              top: -100 + t * 16,
              right: -60 + t * 10,
              child: _GlowOrb(
                size: 200,
                color: AppColors.primaryPurple.withValues(alpha: 0.14),
              ),
            ),
            Positioned(
              bottom: 90 - t * 18,
              left: -80,
              child: _GlowOrb(
                size: 160,
                color: AppColors.auroraCyan.withValues(alpha: 0.08),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

// Apple Liquid Glass Surface

/// Theme-aware frosted / elevated surface used by cards and panels.
///
/// Implements Apple Liquid Glass:
///   - BackdropFilter blur (18px sigma) for frosted translucency
///   - Specular top-left highlight via foregroundDecoration
///   - Subtle translucent glass fill gradient
///   - Layered ambient + brand-coloured shadow
///
/// Set [blur] to false for dense scrolling lists.
class GlassSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius borderRadius;
  final Gradient? gradient;
  final VoidCallback? onTap;
  final bool elevated;
  final bool blur;

  const GlassSurface({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.gradient,
    this.onTap,
    this.elevated = false,
    this.blur = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    final glassGradient =
        gradient ??
        LinearGradient(
          colors: isDark
              ? [
                  Colors.white.withValues(alpha: elevated ? 0.13 : 0.09),
                  Colors.white.withValues(alpha: elevated ? 0.07 : 0.04),
                ]
              : [
                  Colors.white.withValues(alpha: elevated ? 0.96 : 0.88),
                  Colors.white.withValues(alpha: elevated ? 0.84 : 0.72),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

    final specularDecoration = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: const Alignment(0.5, 0.9),
        colors: [
          Colors.white.withValues(alpha: isDark ? 0.20 : 0.44),
          Colors.white.withValues(alpha: isDark ? 0.06 : 0.12),
          Colors.transparent,
        ],
        stops: const [0.0, 0.28, 1.0],
      ),
      borderRadius: borderRadius,
    );

    Widget glass = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: glassGradient,
        borderRadius: borderRadius,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.75),
          width: 1.0,
        ),
      ),
      foregroundDecoration: specularDecoration,
      child: child,
    );

    if (blur) {
      glass = ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: glass,
        ),
      );
    } else {
      glass = ClipRRect(borderRadius: borderRadius, child: glass);
    }

    final List<BoxShadow> shadows = [
      BoxShadow(
        color: isDark
            ? Colors.black.withValues(alpha: 0.42)
            : Colors.black.withValues(alpha: 0.10),
        blurRadius: 28,
        offset: const Offset(0, 10),
        spreadRadius: -4,
      ),
      BoxShadow(
        color: isDark
            ? Colors.black.withValues(alpha: 0.20)
            : Colors.black.withValues(alpha: 0.04),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
      if (isDark)
        BoxShadow(
          color: AppColors.primaryPurple.withValues(alpha: 0.12),
          blurRadius: 40,
          offset: const Offset(0, 6),
          spreadRadius: -2,
        ),
    ];

    Widget result = Container(
      decoration: BoxDecoration(borderRadius: borderRadius, boxShadow: shadows),
      child: glass,
    );

    if (onTap == null) return result;

    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: borderRadius, child: result),
    );
  }
}
