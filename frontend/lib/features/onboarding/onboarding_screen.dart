import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_atmosphere.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/theme_toggle_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _waveController;
  late final AnimationController _enterController;
  late final AnimationController _pulseController;
  late final AnimationController _rotationController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;
  late final List<Animation<double>> _barAnimations;
  int _currentPage = 0;
  Timer? _autoPlayTimer;
  bool _restoredRouteHandled = false;

  static const List<double> _leftBaseHeights = [22, 32, 45, 38, 58, 72, 88];
  static const List<double> _rightBaseHeights = [88, 72, 58, 38, 45, 32, 22];
  static const List<double> _leftOpacities = [
    0.3,
    0.4,
    0.55,
    0.7,
    0.8,
    0.9,
    1.0,
  ];
  static const List<double> _rightOpacities = [
    1.0,
    0.9,
    0.8,
    0.7,
    0.55,
    0.4,
    0.3,
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    // Pre-compute all 14 bar animations once — no allocation inside build()
    _barAnimations = List.generate(14, (barIndex) {
      final start = ((barIndex * 0.08) % 0.6);
      final end = (start + 0.4).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _waveController,
        curve: Interval(start, end, curve: Curves.easeInOutCubic),
      );
    });

    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = CurvedAnimation(parent: _enterController, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _enterController, curve: Curves.easeOutCubic),
        );
    _enterController.forward();

    _startAutoPlay();
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final next = (_currentPage + 1) % 3;
      _goToPage(next);
    });
  }

  void _goToPage(int page) {
    if (!_pageController.hasClients) return;
    if (_currentPage != page) {
      setState(() {
        _currentPage = page;
      });
    }
    _startAutoPlay();
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    _waveController.dispose();
    _enterController.dispose();
    _pulseController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_restoredRouteHandled && context.watch<UserProvider>().isLoggedIn) {
      _restoredRouteHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/home');
      });
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.scaffoldOf(context),
      body: AppAtmosphere(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: FadeTransition(
                opacity: _fadeIn,
                child: SlideTransition(
                  position: _slideUp,
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      const Align(
                        alignment: Alignment.topRight,
                        child: ThemeToggleButton(size: 40, compact: true),
                      ),
                      const Spacer(flex: 1),
                      // ── CAROUSEL HERO SECTION (3 ANIMATED SLIDES) ──────────────────
                      SizedBox(
                        height: 240,
                        width: double.infinity,
                        child: PageView(
                          controller: _pageController,
                          onPageChanged: (index) {
                            setState(() {
                              _currentPage = index;
                            });
                            _startAutoPlay();
                          },
                          children: [
                            _buildHero0(isDark),
                            _buildHero1(isDark),
                            _buildHero2(isDark),
                          ],
                        ),
                      ),
                      const Spacer(flex: 1),
                      // ── INTERACTIVE 3-DOT INDICATOR ────────────────────────────────
                      _buildPageIndicator(isDark),
                      const SizedBox(height: 24),
                      // ── SWIPEABLE / ANIMATED TYPOGRAPHY ───────────────────────────
                      GestureDetector(
                        onHorizontalDragEnd: (details) {
                          if (details.primaryVelocity != null) {
                            if (details.primaryVelocity! < -150 && _currentPage < 2) {
                              _goToPage(_currentPage + 1);
                            } else if (details.primaryVelocity! > 150 && _currentPage > 0) {
                              _goToPage(_currentPage - 1);
                            }
                          }
                        },
                        child: _buildTypographySection(isDark),
                      ),
                      const Spacer(flex: 2),
                      _buildButtonStack(context, isDark),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SLIDE 0: VOICE & WAVEFORMS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildHero0(bool isDark) {
    return SizedBox(
      height: 240,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Breathing radial glow
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              final scale = 1.0 + 0.08 * _pulseController.value;
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        (isDark
                                ? const Color(0xFF5E5CE6)
                                : AppColors.primaryPurple)
                            .withValues(alpha: isDark ? 0.12 : 0.22),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          // Subtle expanding pulse ring
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              final size = 114.0 + 36.0 * _pulseController.value;
              final opacity = (0.35 * (1.0 - _pulseController.value)).clamp(0.0, 1.0);
              return Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: (isDark
                            ? const Color(0xFF5E5CE6)
                            : AppColors.primaryPurple)
                        .withValues(alpha: isDark ? opacity * 0.25 : opacity),
                    width: 1.0,
                  ),
                ),
              );
            },
          ),
          // Waves + Mic center
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _waveController,
              child: Container(
                width: 114,
                height: 114,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isDark
                      ? const LinearGradient(
                          colors: [Color(0xFF2E2E38), Color(0xFF141418)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        )
                      : AppColors.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: (isDark
                              ? const Color(0xFF5E5CE6)
                              : AppColors.primaryPurple)
                          .withValues(alpha: isDark ? 0.18 : 0.40),
                      blurRadius: isDark ? 28 : 28,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withValues(alpha: isDark ? 0.20 : 0.25),
                    width: 1.0,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (isDark)
                      Positioned(
                        top: 0,
                        child: Container(
                          width: 114,
                          height: 57,
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(57),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.16),
                                Colors.white.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const Icon(
                      Icons.mic_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  ],
                ),
              ),
              builder: (context, child) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildWaveGroup(
                      baseHeights: _leftBaseHeights,
                      opacities: _leftOpacities,
                      startBarIndex: 0,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 14),
                    child!,
                    const SizedBox(width: 14),
                    _buildWaveGroup(
                      baseHeights: _rightBaseHeights,
                      opacities: _rightOpacities,
                      startBarIndex: 7,
                      isDark: isDark,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaveGroup({
    required List<double> baseHeights,
    required List<double> opacities,
    required int startBarIndex,
    required bool isDark,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(baseHeights.length, (index) {
        final baseH = baseHeights[index];
        final opacity = opacities[index];
        final animatedHeight =
            baseH * (0.55 + 0.5 * _barAnimations[startBarIndex + index].value);
        final barColor =
            isDark ? const Color(0xFF5E5CE6) : AppColors.primaryPurpleLight;
        final barAlpha = isDark ? (0.45 + 0.55 * opacity) : opacity;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.2),
          child: Container(
            width: 3.5,
            height: animatedHeight,
            decoration: BoxDecoration(
              gradient: isDark
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF818CF8).withValues(alpha: barAlpha),
                        const Color(0xFF5E5CE6).withValues(alpha: barAlpha * 0.85),
                      ],
                    )
                  : null,
              color: isDark ? null : barColor.withValues(alpha: barAlpha),
              borderRadius: BorderRadius.circular(2.0),
            ),
          ),
        );
      }),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SLIDE 1: REAL-TIME AI SPEECH INTELLIGENCE & METRICS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildHero1(bool isDark) {
    return SizedBox(
      height: 240,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ambient radial glow
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              final scale = 1.0 + 0.10 * _pulseController.value;
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        (isDark
                                ? const Color(0xFF0A84FF)
                                : const Color(0xFF06B6D4))
                            .withValues(alpha: isDark ? 0.10 : 0.20),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          // Rotating dashed radar ring
          RotationTransition(
            turns: _rotationController,
            child: CustomPaint(
              size: const Size(140, 140),
              painter: DashedCirclePainter(
                color: (isDark
                        ? const Color(0xFF5E5CE6)
                        : const Color(0xFF06B6D4))
                    .withValues(alpha: isDark ? 0.20 : 0.40),
              ),
            ),
          ),
          // Center Badge
          Container(
            width: 114,
            height: 114,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isDark
                  ? const LinearGradient(
                      colors: [Color(0xFF1E2638), Color(0xFF0F1420)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              boxShadow: [
                BoxShadow(
                  color: (isDark
                          ? const Color(0xFF0A84FF)
                          : const Color(0xFF06B6D4))
                      .withValues(alpha: isDark ? 0.20 : 0.38),
                  blurRadius: isDark ? 28 : 28,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(
                color: (isDark ? const Color(0xFF0A84FF) : Colors.white)
                    .withValues(alpha: isDark ? 0.35 : 0.30),
                width: 1.0,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (isDark)
                  Positioned(
                    top: 0,
                    child: Container(
                      width: 114,
                      height: 57,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(57),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.16),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                const Icon(
                  Icons.insights_rounded,
                  color: Colors.white,
                  size: 46,
                ),
              ],
            ),
          ),
          // Top-Left Floating Metric Chip (WPM Pace)
          Positioned(
            left: 10,
            top: 28,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final offset = 4.0 * math.sin(_pulseController.value * math.pi);
                return Transform.translate(
                  offset: Offset(0, offset),
                  child: child,
                );
              },
              child: _buildGlassChip(
                icon: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF30D158).withValues(alpha: isDark ? 0.16 : 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.speed_rounded,
                    color: Color(0xFF30D158),
                    size: 16,
                  ),
                ),
                title: '138 WPM',
                subtitle: 'Optimal Pace',
                subtitleColor: const Color(0xFF30D158),
                isDark: isDark,
              ),
            ),
          ),
          // Top-Right Floating Metric Chip (Clarity Score)
          Positioned(
            right: 10,
            top: 28,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final offset = -4.0 * math.sin(_pulseController.value * math.pi);
                return Transform.translate(
                  offset: Offset(0, offset),
                  child: child,
                );
              },
              child: _buildGlassChip(
                icon: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A84FF).withValues(alpha: isDark ? 0.16 : 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.verified_rounded,
                    color: Color(0xFF0A84FF),
                    size: 16,
                  ),
                ),
                title: '94% Clarity',
                subtitle: 'Clear Tone',
                subtitleColor: const Color(0xFF64D2FF),
                isDark: isDark,
              ),
            ),
          ),
          // Bottom Centered Micro Pill (Filler Words)
          Positioned(
            bottom: 4,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final offset = 2.0 * math.sin(_pulseController.value * math.pi);
                return Transform.translate(
                  offset: Offset(0, offset),
                  child: child,
                );
              },
              child: _buildBottomPill(
                icon: Icons.check_circle_rounded,
                iconColor: const Color(0xFF30D158),
                text: '0 Filler Words - Clean Speech',
                isDark: isDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SLIDE 2: INTERVIEW FRAMEWORKS & STRUCTURED MASTERY
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildHero2(bool isDark) {
    return SizedBox(
      height: 240,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ambient warm radial glow
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              final scale = 1.0 + 0.10 * _pulseController.value;
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFFF9F0A).withValues(
                          alpha: isDark ? 0.08 : 0.18,
                        ),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          // Concentric pulsing achievement rings
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              final size = 114.0 + 36.0 * _pulseController.value;
              final opacity = (0.35 * (1.0 - _pulseController.value)).clamp(0.0, 1.0);
              return Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFF9F0A)
                        .withValues(alpha: isDark ? opacity * 0.22 : opacity),
                    width: 1.0,
                  ),
                ),
              );
            },
          ),
          // Center Badge
          Container(
            width: 114,
            height: 114,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isDark
                  ? const LinearGradient(
                      colors: [Color(0xFF342A1E), Color(0xFF16120C)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFFF59E0B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF9F0A)
                      .withValues(alpha: isDark ? 0.20 : 0.38),
                  blurRadius: isDark ? 28 : 28,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(
                color: (isDark ? const Color(0xFFFF9F0A) : Colors.white)
                    .withValues(alpha: isDark ? 0.35 : 0.30),
                width: 1.0,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (isDark)
                  Positioned(
                    top: 0,
                    child: Container(
                      width: 114,
                      height: 57,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(57),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.16),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              ],
            ),
          ),
          // Top-Left Floating Coaching Chip (STAR Method)
          Positioned(
            left: 10,
            top: 28,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final offset = 4.0 * math.sin(_pulseController.value * math.pi);
                return Transform.translate(
                  offset: Offset(0, offset),
                  child: child,
                );
              },
              child: _buildGlassChip(
                icon: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9F0A).withValues(alpha: isDark ? 0.16 : 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    color: Color(0xFFFF9F0A),
                    size: 16,
                  ),
                ),
                title: 'STAR Method',
                subtitle: 'Behavioral Drills',
                subtitleColor: const Color(0xFFFF9F0A),
                isDark: isDark,
              ),
            ),
          ),
          // Top-Right Floating Coaching Chip (Curated Video Lessons)
          Positioned(
            right: 10,
            top: 28,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final offset = -4.0 * math.sin(_pulseController.value * math.pi);
                return Transform.translate(
                  offset: Offset(0, offset),
                  child: child,
                );
              },
              child: _buildGlassChip(
                icon: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFBF5AF2).withValues(alpha: isDark ? 0.16 : 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.play_circle_filled_rounded,
                    color: Color(0xFFBF5AF2),
                    size: 16,
                  ),
                ),
                title: 'Video Guides',
                subtitle: 'CareerVidz Lessons',
                subtitleColor: const Color(0xFFBF5AF2),
                isDark: isDark,
              ),
            ),
          ),
          // Bottom Centered Micro Pill (Streak Tracking)
          Positioned(
            bottom: 4,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final offset = 2.0 * math.sin(_pulseController.value * math.pi);
                return Transform.translate(
                  offset: Offset(0, offset),
                  child: child,
                );
              },
              child: _buildBottomPill(
                icon: Icons.trending_up_rounded,
                iconColor: const Color(0xFFFF9F0A),
                text: 'Track Weekly Speech Streaks',
                isDark: isDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REUSABLE GLASS CHIP & BOTTOM PILL (APPLE LIQUID GLASS MATERIAL)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildGlassChip({
    required Widget icon,
    required String title,
    required String subtitle,
    required Color subtitleColor,
    required bool isDark,
  }) {
    final border = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : AppColors.cardLightBorder;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? null : Colors.white.withValues(alpha: 0.94),
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF28282C), Color(0xFF18181C)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              )
            : null,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
            blurRadius: isDark ? 16 : 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: AppTextStyles.bodySmallBold.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: isDark ? Colors.white : AppColors.textPrimaryDark,
                  letterSpacing: -0.2,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                  color: subtitleColor,
                  letterSpacing: -0.1,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPill({
    required IconData icon,
    required Color iconColor,
    required String text,
    required bool isDark,
  }) {
    final border = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : AppColors.cardLightBorder;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? null : Colors.white.withValues(alpha: 0.94),
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF26262A), Color(0xFF16161A)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              )
            : null,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 11,
              letterSpacing: -0.2,
              color: isDark ? const Color(0xFFF2F2F7) : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INTERACTIVE 3-DOT PAGE INDICATOR (APPLE UIPAGECONTROL STYLE)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildPageIndicator(bool isDark) {
    final inactive = isDark
        ? Colors.white.withValues(alpha: 0.22)
        : AppColors.textSecondary.withValues(alpha: 0.35);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final isActive = _currentPage == index;
        return GestureDetector(
          key: ValueKey('onboarding_dot_$index'),
          onTap: () => _goToPage(index),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: isActive ? 28 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: isActive
                    ? (isDark ? Colors.white : null)
                    : inactive,
                gradient: isActive
                    ? (isDark ? null : AppColors.primaryGradient)
                    : null,
                borderRadius: BorderRadius.circular(4),
                boxShadow: (isActive && isDark)
                    ? [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: Offset.zero,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        );
      }),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SWIPEABLE / ANIMATED TYPOGRAPHY (APPLE SF DISPLAY HIERARCHY)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildTypographySection(bool isDark) {
    final titles = [
      'Pitch Coach',
      'Real-Time AI Feedback',
      'Master Any Interview',
    ];
    final subtitles = [
      'Speak with confidence.\nPresent with clarity.',
      'Instant breakdown of pacing, filler words,\nclarity, and vocal confidence.',
      'Structured frameworks, video drills,\nand personalized practice plans.',
    ];

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.15),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Column(
        key: ValueKey<int>(_currentPage),
        children: [
          Text(
            titles[_currentPage],
            textAlign: TextAlign.center,
            style: AppTextStyles.headingXL.copyWith(
              color: isDark ? Colors.white : const Color(0xFF15132A),
              fontSize: _currentPage == 1 ? 28 : 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.9,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitles[_currentPage],
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyM.copyWith(
              color: isDark ? const Color(0xFF8E8E93) : AppColors.textSecondary,
              fontSize: 15,
              height: 1.45,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACTION BUTTONS (APPLE FLAGSHIP DARK CAPSULE DESIGN)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildButtonStack(BuildContext context, bool isDark) {
    final outline = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : AppColors.cardLightBorder;
    final text = AppColors.textPrimaryOf(context);

    return Column(
      children: [
        GradientButton(
          text: 'Login',
          variant: GradientButtonVariant.primary,
          height: 56,
          backgroundColor: isDark ? Colors.white : null,
          textColor: isDark ? Colors.black : null,
          onPressed: () => context.push('/login', extra: false),
        ),
        const SizedBox(height: 12),
        GradientButton(
          text: 'Sign Up',
          variant: GradientButtonVariant.secondary,
          height: 56,
          backgroundColor: isDark ? const Color(0xFF1C1C1E) : null,
          borderColor: outline,
          textColor: isDark ? Colors.white : text,
          onPressed: () => context.push('/login', extra: true),
        ),
        const SizedBox(height: 12),
        GradientButton(
          text: 'Continue as Guest',
          variant: GradientButtonVariant.tertiary,
          height: 56,
          backgroundColor: Colors.transparent,
          borderColor: isDark ? Colors.white.withValues(alpha: 0.10) : outline,
          textColor: isDark ? const Color(0xFF8E8E93) : text,
          onPressed: () async {
            await Provider.of<UserProvider>(
              context,
              listen: false,
            ).loginAsGuest();
            if (!context.mounted) return;
            context.go('/home');
          },
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ROTATING RADAR PAINTER
// ═════════════════════════════════════════════════════════════════════════════
class DashedCirclePainter extends CustomPainter {
  final Color color;
  DashedCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final radius = size.width / 2;
    const count = 12;
    const sweep = (math.pi * 2) / count;
    for (var i = 0; i < count; i += 2) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(radius, radius), radius: radius),
        i * sweep,
        sweep * 0.7,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
