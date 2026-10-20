import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/gamification_models.dart';
import '../../../core/providers/gamification_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Weekly rotating challenges card with progress bars, claims, and XP rewards.
class ChallengesCard extends StatelessWidget {
  const ChallengesCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GamificationProvider>();
    final challenges = provider.challenges;
    final earnedPoints = provider.earnedPoints;

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
                        color: AppColors.primaryPurple.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.flag_rounded,
                        color: AppColors.primaryPurple,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Weekly Challenges',
                        style: AppTextStyles.headingMOf(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accentTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.accentTeal.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.stars_rounded,
                      color: AppColors.accentTeal,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$earnedPoints XP',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.accentTeal,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (provider.isLoading && challenges.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.primaryPurple,
                  ),
                ),
              ),
            )
          else if (challenges.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No active challenges this week.',
                  style: AppTextStyles.bodyMOf(context),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: challenges.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (ctx, index) {
                return _ChallengeItemTile(challenge: challenges[index]);
              },
            ),
        ],
      ),
    );
  }
}

class _ChallengeItemTile extends StatelessWidget {
  final WeeklyChallenge challenge;

  const _ChallengeItemTile({required this.challenge});

  IconData _getIconData(String iconKey) {
    switch (iconKey) {
      case 'shield-check':
        return Icons.verified_user_rounded;
      case 'speed':
        return Icons.speed_rounded;
      case 'calendar-check':
        return Icons.event_available_rounded;
      default:
        return Icons.stars_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<GamificationProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progressFraction = challenge.target > 0
        ? (challenge.currentProgress / challenge.target).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1930) : const Color(0xFFF7F7FC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: challenge.isCompleted
              ? AppColors.primaryPurple.withValues(alpha: 0.3)
              : AppColors.borderOf(context).withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: challenge.isCompleted
                      ? AppColors.primaryPurple.withValues(alpha: 0.15)
                      : (isDark
                            ? const Color(0xFF282548)
                            : const Color(0xFFE8E8F0)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getIconData(challenge.icon),
                  size: 20,
                  color: challenge.isCompleted
                      ? AppColors.primaryPurple
                      : AppColors.textSecondaryOf(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      challenge.title,
                      style: AppTextStyles.bodyBoldOf(
                        context,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      challenge.description,
                      style: AppTextStyles.captionOf(
                        context,
                      ).copyWith(color: AppColors.textSecondaryOf(context)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (challenge.isClaimed)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.successGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.successGreen,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Claimed',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.successGreen,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                )
              else if (challenge.isCompleted)
                ElevatedButton(
                  key: Key('claim_button_${challenge.id}'),
                  onPressed: provider.isClaiming
                      ? null
                      : () => provider.claimChallenge(challenge.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Claim +${challenge.rewardPoints} XP',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF282548)
                        : const Color(0xFFE8E8F0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+${challenge.rewardPoints} XP',
                    style: AppTextStyles.captionOf(context).copyWith(
                      color: AppColors.textSecondaryOf(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress: ${challenge.currentProgress} / ${challenge.target}',
                style: AppTextStyles.captionOf(context).copyWith(
                  fontWeight: FontWeight.w600,
                  color: challenge.isCompleted
                      ? AppColors.primaryPurple
                      : AppColors.textSecondaryOf(context),
                ),
              ),
              Text(
                '${(progressFraction * 100).toInt()}%',
                style: AppTextStyles.captionOf(context).copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressFraction,
              minHeight: 6,
              backgroundColor: isDark
                  ? const Color(0xFF282548)
                  : const Color(0xFFE8E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                challenge.isCompleted
                    ? AppColors.primaryPurple
                    : AppColors.accentTeal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
