import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../../core/models/lesson_model.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/theme_toggle_button.dart';

class LessonDetailScreen extends StatefulWidget {
  final Lesson lesson;

  const LessonDetailScreen({super.key, required this.lesson});

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  late final YoutubePlayerController _ytController;

  @override
  void initState() {
    super.initState();
    _ytController = YoutubePlayerController.fromVideoId(
      videoId: widget.lesson.youtubeVideoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        mute: false,
        showVideoAnnotations: false,
        loop: false,
        enableCaption: true,
        playsInline: true,
      ),
    );
  }

  @override
  void dispose() {
    _ytController.close();
    super.dispose();
  }



  Color get _categoryColor {
    switch (widget.lesson.category) {
      case 'interview':
        return AppColors.primaryPurple;
      case 'presentation':
        return AppColors.accentBlue;
      default:
        return AppColors.accentGreen;
    }
  }

  Color get _levelColor {
    switch (widget.lesson.level) {
      case 'beginner':
        return AppColors.accentGreen;
      case 'intermediate':
        return AppColors.accentBlue;
      case 'advanced':
        return AppColors.primaryPurple;
      default:
        return AppColors.accentGreen;
    }
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.iconButtonBgOf(context),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.borderOf(context)),
                      ),
                      child: Icon(
                        Icons.chevron_left_rounded,
                        size: 26,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                  ),
                  Text(
                    'Lesson',
                    style: AppTextStyles.headingMOf(
                      context,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                  const ThemeToggleButton(size: 38, compact: true),
                ],
              ),
            ),

            // Scrollable Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── DEDICATED YOUTUBE VIDEO PLAYER ───────────────────
                    _buildVideoPlayer(),

                    const SizedBox(height: 20),

                    // ── Lesson Title ─────────────────────────────────────
                    Text(
                      widget.lesson.title,
                      style: AppTextStyles.headingXLOf(
                        context,
                      ).copyWith(fontSize: 22),
                    ),

                    const SizedBox(height: 8),

                    // Category + Level + Duration row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _categoryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _capitalize(widget.lesson.category),
                            style: AppTextStyles.caption.copyWith(
                              color: _categoryColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _levelColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                              color: _levelColor.withValues(alpha: 0.28),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            widget.lesson.levelLabel,
                            style: AppTextStyles.caption.copyWith(
                              color: _levelColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.lesson.duration,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ── Description ──────────────────────────────────────
                    Text(
                      widget.lesson.description,
                      style: AppTextStyles.bodyM.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Key Takeaways ─────────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.cardOf(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderOf(context)),
                        boxShadow: AppColors.softShadowOf(context),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.lightbulb_rounded,
                                color: AppColors.warningAmber,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Key Takeaways',
                                style: AppTextStyles.headingMOf(
                                  context,
                                ).copyWith(fontSize: 15),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...widget.lesson.takeaways.map(
                            (t) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    size: 16,
                                    color: AppColors.successGreen,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      t,
                                      style: AppTextStyles.bodyMOf(context)
                                          .copyWith(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 13.5,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Practice This Skill Button ────────────────────────
                    GradientButton(
                      text: 'Practice This Skill',
                      icon: Icons.mic_rounded,
                      onPressed: () => context.push(
                        AppRouter.lessonPractice,
                        extra: widget.lesson,
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: YoutubePlayer(
        controller: _ytController,
        aspectRatio: 16 / 9,
        backgroundColor: Colors.black,
        thumbnailFormat: ThumbnailFormat.jpeg,
        thumbnailQuality: ThumbnailQuality.high,
        controlsBuilder: (context, isFullscreen) {
          return YoutubeValueBuilder(
            controller: _ytController,
            builder: (context, value) {
              if (value.playerState == PlayerState.playing) {
                return const SizedBox.shrink();
              }
              return GestureDetector(
                onTap: () => _ytController.playVideo(),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  color: Colors.transparent,
                  alignment: Alignment.center,
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white38, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
