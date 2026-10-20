import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/gamification_models.dart';
import '../../../core/providers/gamification_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Privacy-preserving weekly leaderboard card with opt-in switch,
/// anonymous speaker pseudonyms, and top weekly speaker ranks.
class LeaderboardCard extends StatelessWidget {
  const LeaderboardCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GamificationProvider>();
    final board = provider.leaderboard;
    final entries = board.entries;
    final currentUserEntry = board.currentUserEntry;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accentTeal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.leaderboard_rounded,
                        color: AppColors.accentTeal,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Weekly Leaderboard',
                        style: AppTextStyles.headingMOf(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (board.weekId.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.borderOf(context).withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    board.weekId,
                    style: AppTextStyles.captionOf(context).copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Speaker rankings reset every Monday at 00:00 UTC.',
            style: AppTextStyles.captionOf(
              context,
            ).copyWith(color: AppColors.textSecondaryOf(context)),
          ),
          const SizedBox(height: 14),

          // Privacy opt-in toggle container
          _buildPrivacyBanner(context, provider),

          const SizedBox(height: 16),

          // Current user ranking pill / highlight
          _buildCurrentUserCard(context, currentUserEntry),

          const SizedBox(height: 16),

          if (provider.isLoading && entries.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.accentTeal,
                  ),
                ),
              ),
            )
          else if (entries.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No sessions recorded yet this week.',
                  style: AppTextStyles.bodyMOf(context),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: entries.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (ctx, index) {
                return _LeaderboardRowTile(entry: entries[index]);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPrivacyBanner(
    BuildContext context,
    GamificationProvider provider,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1930) : const Color(0xFFF7F7FC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.borderOf(context).withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.privacy_tip_outlined,
            size: 20,
            color: AppColors.accentTeal,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Opt-in to Public Rankings',
                  style: AppTextStyles.bodyBoldOf(
                    context,
                  ).copyWith(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  provider.isOptedIn
                      ? 'Displaying chosen public speaker alias.'
                      : 'Private mode: using anonymous speaker alias.',
                  style: AppTextStyles.captionOf(context).copyWith(
                    color: AppColors.textSecondaryOf(context),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            key: const Key('leaderboard_opt_in_switch'),
            value: provider.isOptedIn,
            activeThumbColor: AppColors.accentTeal,
            onChanged: (val) => provider.toggleLeaderboardOptIn(val),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentUserCard(
    BuildContext context,
    LeaderboardEntry currentUserEntry,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryPurple.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryPurple.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryPurple,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              currentUserEntry.rank != null
                  ? '#${currentUserEntry.rank}'
                  : 'Unranked',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Standing: ${currentUserEntry.displayName}',
                  style: AppTextStyles.bodyBoldOf(
                    context,
                  ).copyWith(fontWeight: FontWeight.w700, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${currentUserEntry.sessionsCount} sessions completed',
                  style: AppTextStyles.captionOf(context).copyWith(
                    color: AppColors.textSecondaryOf(context),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${currentUserEntry.score.toStringAsFixed(1)} pts',
                style: AppTextStyles.bodyBoldOf(context).copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryPurple,
                  fontSize: 14,
                ),
              ),
              Text(
                'Avg Score',
                style: AppTextStyles.captionOf(context).copyWith(
                  color: AppColors.textSecondaryOf(context),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LeaderboardRowTile extends StatelessWidget {
  final LeaderboardEntry entry;

  const _LeaderboardRowTile({required this.entry});

  Color _getRankBadgeColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFB800); // Gold
      case 2:
        return const Color(0xFF9E9E9E); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rank = entry.rank ?? 0;
    final isTop3 = rank >= 1 && rank <= 3;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: entry.isCurrentUser
            ? AppColors.primaryPurple.withValues(alpha: 0.08)
            : (isDark ? const Color(0xFF1B1930) : const Color(0xFFF7F7FC)),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: entry.isCurrentUser
              ? AppColors.primaryPurple.withValues(alpha: 0.4)
              : AppColors.borderOf(context).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isTop3
                  ? _getRankBadgeColor(rank).withValues(alpha: 0.18)
                  : Colors.transparent,
              border: isTop3
                  ? Border.all(color: _getRankBadgeColor(rank), width: 1.5)
                  : null,
            ),
            child: Text(
              '$rank',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: isTop3
                    ? _getRankBadgeColor(rank)
                    : AppColors.textSecondaryOf(context),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.displayName,
                        style: AppTextStyles.bodyBoldOf(context).copyWith(
                          fontWeight: entry.isCurrentUser
                              ? FontWeight.w700
                              : FontWeight.w600,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (entry.isCurrentUser) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryPurple.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'You',
                          style: TextStyle(
                            color: AppColors.primaryPurple,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  '${entry.sessionsCount} sessions',
                  style: AppTextStyles.captionOf(context).copyWith(
                    color: AppColors.textSecondaryOf(context),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${entry.score.toStringAsFixed(1)} pts',
            style: AppTextStyles.bodyBoldOf(context).copyWith(
              fontWeight: FontWeight.w700,
              color: isTop3
                  ? _getRankBadgeColor(rank)
                  : AppColors.textPrimaryOf(context),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
