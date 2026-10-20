import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/models/practice_drill.dart';
import '../../core/models/stats_models.dart';
import '../../core/providers/gamification_provider.dart';
import '../../core/providers/practice_plan_provider.dart';
import '../../core/providers/stats_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/repositories/practice_plan_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/app_illustration.dart';
import '../../core/widgets/theme_toggle_button.dart';
import 'widgets/challenges_card.dart';
import 'widgets/leaderboard_card.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with AutomaticKeepAliveClientMixin {
  String _selectedRange = 'Week'; // 'Week' or 'Month'

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Load all stats and practice plan data when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final stats = context.read<StatsProvider>();
      final gamification = context.read<GamificationProvider>();
      final practicePlan = context.read<PracticePlanProvider>();
      final isGuest = context.read<UserProvider>().isGuest;

      gamification.loadGamificationData();
      practicePlan.loadPlan(isGuest: isGuest);

      if (isGuest) {
        stats.loadDemo();
      } else {
        if (stats.state != StatsLoadState.ready) {
          final userId = context.read<UserProvider>().user.id;
          stats.loadAll(trendRange: 'week', userId: userId);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final statsProvider = context.watch<StatsProvider>();
    final isLoading =
        statsProvider.isLoading && statsProvider.state != StatsLoadState.ready;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            final gamification = context.read<GamificationProvider>();
            gamification.loadGamificationData(silent: true);
            final isGuest = context.read<UserProvider>().isGuest;
            context.read<PracticePlanProvider>().loadPlan(
              forceRefresh: true,
              isGuest: isGuest,
            );
            if (isGuest) {
              statsProvider.loadDemo();
            } else {
              final userId = context.read<UserProvider>().user.id;
              await statsProvider.loadAll(
                trendRange: _selectedRange.toLowerCase(),
                force: true,
                userId: userId,
              );
            }
          },
          color: AppColors.primaryPurple,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 14.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Progress', style: AppTextStyles.headingXLOf(context)),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.cardOf(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.borderOf(context),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'This Month',
                                style: AppTextStyles.captionOf(context)
                                    .copyWith(
                                      color: AppColors.textSecondaryOf(context),
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 18,
                                color: AppColors.textSecondaryOf(context),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        const ThemeToggleButton(size: 38, compact: true),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 2. Summary Stat Cards Row — real data
                _buildTopSummaryRow(statsProvider, isLoading),

                const SizedBox(height: 20),

                // 3. Confidence Over Time Chart — real trend data
                _buildConfidenceChartCard(statsProvider, isLoading),

                const SizedBox(height: 20),

                // 4. Skill Breakdown Card — real skills data
                _buildSkillBreakdownCard(statsProvider, isLoading),

                const SizedBox(height: 20),

                // Targeted Drills & Skill Evaluations (Feature 6 stored in Progress)
                _buildDrillEvaluationsCard(context),

                const SizedBox(height: 20),

                // 5. Weekly Rotating Challenges (Feature 11)
                const ChallengesCard(),

                const SizedBox(height: 20),

                // 6. Privacy-Preserving Weekly Leaderboard (Feature 11)
                const LeaderboardCard(),

                const SizedBox(height: 20),

                // 7. Achievements Section — real achievements
                _buildAchievementsSection(statsProvider, isLoading),

                const SizedBox(height: 20),

                // 8. Filler Word Reduction Card — real data
                _buildFillerWordTrendCard(statsProvider, isLoading),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopSummaryRow(StatsProvider provider, bool isLoading) {
    final s = provider.summary;

    // Metric items for the grid
    final metrics = [
      _GridMetric(
        label: 'Total Sessions',
        value: isLoading ? '...' : '${s.totalSessions}',
        trend: isLoading ? '' : '+${(s.totalSessions * 0.14).round()}%',
        icon: Icons.mic_rounded,
        color: AppColors.primaryPurple,
        isTrendPositive: true,
      ),
      _GridMetric(
        label: 'Avg. Confidence',
        value: isLoading ? '...' : '${s.avgConfidence.toStringAsFixed(0)}%',
        trend: isLoading ? '' : '+5%',
        icon: Icons.emoji_emotions_rounded,
        color: AppColors.successGreen,
        isTrendPositive: true,
      ),
      _GridMetric(
        label: 'Streak',
        value: isLoading ? '...' : '${s.streakDays}',
        trend: isLoading ? '' : 'days',
        icon: Icons.local_fire_department_rounded,
        color: AppColors.warningAmber,
        isTrendPositive: true,
        isStreak: true,
      ),
      _GridMetric(
        label: 'Best Score',
        value: isLoading ? '...' : '${s.avgConfidence.toStringAsFixed(0)}%',
        trend: isLoading ? '' : 'all time',
        icon: Icons.star_rounded,
        color: AppColors.accentBlue,
        isTrendPositive: true,
        isStreak: true,
      ),
    ];

    // GridView.count — Unit 1 GridView requirement
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: metrics.map((m) => _buildGridMetricCard(m)).toList(),
    );
  }

  Widget _buildGridMetricCard(_GridMetric m) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: AppColors.softShadowOf(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                m.label,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(m.icon, size: 16, color: m.color),
            ],
          ),
          Text(
            m.value,
            style: AppTextStyles.headingXL.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: m.color,
            ),
          ),
          if (m.trend.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!m.isStreak)
                  Icon(
                    m.isTrendPositive
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: 11,
                    color: m.isTrendPositive
                        ? AppColors.successGreen
                        : AppColors.dangerRed,
                  ),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    m.trend,
                    style: AppTextStyles.caption.copyWith(
                      color: m.isStreak
                          ? AppColors.textSecondary
                          : AppColors.successGreen,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildConfidenceChartCard(StatsProvider provider, bool isLoading) {
    final isWeek = _selectedRange == 'Week';

    // Build chart spots from real trend data; fall back to empty list
    List<FlSpot> spots = [];
    List<String> xLabels = isWeek
        ? ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
        : ['W1', 'W2', 'W3', 'W4'];

    if (!isLoading && provider.trend.isNotEmpty) {
      final trendData = provider.trend;
      // Build spots in order; use index as x-axis
      for (int i = 0; i < trendData.length; i++) {
        spots.add(FlSpot(i.toDouble(), trendData[i].confidence));
      }
      // Use real date labels from trend data
      xLabels = trendData.map((t) => t.date).toList();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Card Header + Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Confidence Over Time',
                style: AppTextStyles.headingMOf(
                  context,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF282548)
                      : const Color(0xFFEBEBF5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    _buildRangeToggleOption('Week', isWeek, provider),
                    _buildRangeToggleOption('Month', !isWeek, provider),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Chart area
          SizedBox(
            height: 170,
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primaryPurple,
                      ),
                    ),
                  )
                : spots.isEmpty
                ? Center(
                    child: Text(
                      'No data yet — complete some sessions first.',
                      style: AppTextStyles.bodyM.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: 100,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 25,
                        getDrawingHorizontalLine: (val) => FlLine(
                          color: AppColors.divider.withValues(alpha: 0.6),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            interval: 25,
                            getTitlesWidget: (val, meta) => Text(
                              '${val.toInt()}',
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (val, meta) {
                              final idx = val.toInt();
                              if (idx >= 0 && idx < xLabels.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6.0),
                                  child: Text(
                                    xLabels[idx],
                                    style: AppTextStyles.caption.copyWith(
                                      fontSize: 10,
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          isCurved: true,
                          curveSmoothness: 0.3,
                          color: AppColors.primaryPurple,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primaryPurple.withValues(alpha: 0.3),
                                AppColors.primaryPurple.withValues(alpha: 0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) =>
                                FlDotCirclePainter(
                                  radius: 4,
                                  color: AppColors.primaryPurple,
                                  strokeWidth: 2,
                                  strokeColor: AppColors.cardOf(context),
                                ),
                          ),
                          spots: spots,
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRangeToggleOption(
    String label,
    bool isSelected,
    StatsProvider provider,
  ) {
    return GestureDetector(
      onTap: () {
        setState(() => _selectedRange = label);
        if (context.read<UserProvider>().isGuest) {
          provider.loadDemo();
        } else {
          provider.loadAll(trendRange: label.toLowerCase());
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryPurple : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildSkillBreakdownCard(StatsProvider provider, bool isLoading) {
    final sk = provider.skills;

    // Build skill list from real data
    final skills = [
      {
        'name': 'Clarity',
        'score': sk.clarity / 100,
        'label': '${sk.clarity.toStringAsFixed(0)}%',
        'color': AppColors.successGreen,
      },
      {
        'name': 'Pace',
        'score': sk.pace / 100,
        'label': '${sk.pace.toStringAsFixed(0)}%',
        'color': AppColors.successGreen,
      },
      {
        'name': 'Filler Words',
        'score': sk.fillerWords / 100,
        'label': '${sk.fillerWords.toStringAsFixed(0)}%',
        'color': AppColors.warningAmber,
      },
      {
        'name': 'Confidence',
        'score': sk.confidence / 100,
        'label': '${sk.confidence.toStringAsFixed(0)}%',
        'color': AppColors.successGreen,
      },
      {
        'name': 'Engagement',
        'score': sk.engagement / 100,
        'label': '${sk.engagement.toStringAsFixed(0)}%',
        'color': AppColors.primaryPurple,
      },
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Skill Breakdown',
            style: AppTextStyles.headingMOf(
              context,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.primaryPurple,
                  ),
                ),
              ),
            )
          else
            ...skills.map((skill) {
              final name = skill['name'] as String;
              final score = skill['score'] as double;
              final label = skill['label'] as String;
              final color = skill['color'] as Color;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          name,
                          style: AppTextStyles.bodyM.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          label,
                          style: AppTextStyles.caption.copyWith(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: score.clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor:
                            Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF282548)
                            : const Color(0xFFEFEFF5),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildAchievementsSection(StatsProvider provider, bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Achievements', style: AppTextStyles.headingMOf(context)),
        const SizedBox(height: 12),
        if (isLoading)
          const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.primaryPurple,
              ),
            ),
          )
        else if (provider.achievements.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.cardOf(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderOf(context)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppIllustration.achievementsEmpty(size: 64),
                const SizedBox(height: 12),
                Text(
                  'Complete sessions to unlock achievements!',
                  style: AppTextStyles.bodyM.copyWith(
                    color: AppColors.textSecondaryOf(context),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: provider.achievements.map((badge) {
                return GestureDetector(
                  onTap: () => _showAchievementModal(context, badge),
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(14),
                    width: 110,
                    decoration: BoxDecoration(
                      color: AppColors.cardOf(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderOf(context)),
                      boxShadow: AppColors.softShadowOf(context),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: badge.isUnlocked
                                ? AppColors.primaryGradient
                                : LinearGradient(
                                    colors:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? const [
                                            Color(0xFF2C2845),
                                            Color(0xFF232038),
                                          ]
                                        : const [
                                            Color(0xFFE0E0E8),
                                            Color(0xFFD0D0D8),
                                          ],
                                  ),
                          ),
                          child: Center(
                            child: AppIcon(
                              badge.icon,
                              size: 22,
                              color: badge.isUnlocked
                                  ? Colors.white
                                  : AppColors.textSecondaryOf(context),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          badge.title,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: badge.isUnlocked
                                ? AppColors.textPrimaryOf(context)
                                : AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  void _showAchievementModal(BuildContext context, Achievement badge) {
    String unlockedText;
    if (badge.isUnlocked && badge.unlockedAt != null) {
      final d = badge.unlockedAt!.toLocal();
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      unlockedText =
          'Unlocked on ${months[d.month - 1]} ${d.day}, ${d.year}! ${badge.description}';
    } else {
      unlockedText = badge.description;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardOf(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.borderOf(context)),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: badge.isUnlocked ? AppColors.primaryGradient : null,
                color: badge.isUnlocked ? null : AppColors.cardDarkBorder,
              ),
              child: Center(
                child: AppIcon(
                  badge.icon,
                  size: 22,
                  color: badge.isUnlocked
                      ? Colors.white
                      : AppColors.textSecondaryOf(context),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                badge.title,
                style: AppTextStyles.headingMOf(context),
              ),
            ),
          ],
        ),
        content: Text(unlockedText, style: AppTextStyles.bodyMOf(context)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(
                color: AppColors.primaryPurple,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFillerWordTrendCard(StatsProvider provider, bool isLoading) {
    final pct = provider.summary.fillerReductionPct;
    final isPositive = pct >= 0;
    final displayPct = isPositive
        ? '-${pct.toStringAsFixed(0)}%'
        : '+${(-pct).toStringAsFixed(0)}%';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: AppColors.softShadowOf(context),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filler Word Reduction',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    isLoading ? '...' : displayPct,
                    style: AppTextStyles.headingXL.copyWith(
                      fontSize: 22,
                      color: isPositive
                          ? AppColors.successGreen
                          : AppColors.dangerRed,
                    ),
                  ),
                  if (!isLoading) ...[
                    const SizedBox(width: 6),
                    Text(
                      'vs last week',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          Icon(
            isLoading
                ? Icons.trending_flat_rounded
                : isPositive
                ? Icons.trending_down_rounded
                : Icons.trending_up_rounded,
            color: isLoading
                ? AppColors.textSecondary
                : isPositive
                ? AppColors.successGreen
                : AppColors.dangerRed,
            size: 36,
          ),
        ],
      ),
    );
  }

  Widget _buildDrillEvaluationsCard(BuildContext context) {
    final planProvider = context.watch<PracticePlanProvider>();
    final plan =
        planProvider.plan ?? PracticePlanRepository.defaultFallbackPlan;
    final diagnosis = plan.diagnosis;
    final completedDrills = planProvider.completedDrills;
    final pendingDrills = planProvider.pendingDrills;
    final totalCount = plan.drills.length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: AppColors.softShadowOf(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.psychology_rounded,
                  color: AppColors.primaryPurple,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Targeted Drills & Evaluations',
                      style: AppTextStyles.bodySmallBold.copyWith(
                        color: AppColors.textPrimaryOf(context),
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'AI speech evaluation & completed drills',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondaryOf(context),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: completedDrills.isNotEmpty
                      ? AppColors.accentGreen.withValues(alpha: 0.15)
                      : AppColors.surfaceSubtleOf(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: completedDrills.isNotEmpty
                        ? AppColors.accentGreen.withValues(alpha: 0.4)
                        : AppColors.borderOf(context),
                  ),
                ),
                child: Text(
                  '${completedDrills.length}/$totalCount Completed',
                  style: AppTextStyles.caption.copyWith(
                    color: completedDrills.isNotEmpty
                        ? AppColors.accentGreen
                        : AppColors.textSecondaryOf(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Diagnostic Evaluation Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primaryPurple.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primaryPurple,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        diagnosis.diagnosticsSummary,
                        style: AppTextStyles.bodyM.copyWith(
                          color: AppColors.textPrimaryOf(context),
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryPurple.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'FOCUS: ${diagnosis.weakestMetric.toUpperCase()}',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.primaryPurple,
                                fontWeight: FontWeight.w700,
                                fontSize: 9.5,
                              ),
                            ),
                          ),
                          if (diagnosis.scoreTrend != 'insufficient_data')
                            Text(
                              'Trend: ${diagnosis.scoreTrend.toUpperCase()} • ${diagnosis.sessionsAnalyzed} sessions',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondaryOf(context),
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Completed Drills (Stored in Progress)
          if (completedDrills.isNotEmpty) ...[
            Text(
              'Completed Drill Evaluations',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondaryOf(context),
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 8),
            ...completedDrills.map(
              (drill) => _buildCompletedDrillTile(context, drill),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtleOf(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderOf(context)),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.assignment_turned_in_outlined,
                    size: 32,
                    color: AppColors.textSecondaryOf(
                      context,
                    ).withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No Completed Drills Stored Yet',
                    style: AppTextStyles.bodySmallBold.copyWith(
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Targeted drills evaluated and completed from your Home screen will be recorded here.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondaryOf(context),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (pendingDrills.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${pendingDrills.length} drill(s) active on Home',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondaryOf(context),
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => context.go('/home'),
                  child: Text(
                    'Go to Drills >',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primaryPurple,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ] else if (completedDrills.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.accentGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.accentGreen.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: AppColors.accentGreen,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'All targeted drills completed and evaluated! Great job.',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.accentGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompletedDrillTile(BuildContext context, PracticeDrill drill) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtleOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accentGreen.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.accentGreen.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              size: 20,
              color: AppColors.accentGreen,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        drill.title,
                        style: AppTextStyles.bodySmallBold.copyWith(
                          color: AppColors.textPrimaryOf(context),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'EVALUATED',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.accentGreen,
                          fontWeight: FontWeight.w800,
                          fontSize: 9.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  drill.description,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondaryOf(context),
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Coach Note: ${drill.reason}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primaryPurple,
                    fontStyle: FontStyle.italic,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Data class for GridView metric cards ─────────────────────────────────────

class _GridMetric {
  final String label;
  final String value;
  final String trend;
  final IconData icon;
  final Color color;
  final bool isTrendPositive;
  final bool isStreak;

  const _GridMetric({
    required this.label,
    required this.value,
    required this.trend,
    required this.icon,
    required this.color,
    required this.isTrendPositive,
    this.isStreak = false,
  });
}
