import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../../core/models/lesson_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/theme_toggle_button.dart';

class LessonPracticeScreen extends StatefulWidget {
  final Lesson lesson;

  const LessonPracticeScreen({super.key, required this.lesson});

  @override
  State<LessonPracticeScreen> createState() => _LessonPracticeScreenState();
}

class _LessonPracticeScreenState extends State<LessonPracticeScreen>
    with SingleTickerProviderStateMixin {
  bool _isRecording = false;
  bool _isEvaluating = false;
  bool _hasEvaluated = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  Timer? _waveTimer;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final List<double> _waveformHeights = List.filled(12, 12.0);
  final Random _random = Random();

  YoutubePlayerController? _reviewYtController;
  bool _showReviewVideo = false;

  // Evaluation outcome state
  int _score = 86;
  int _wpm = 135;
  int _fillerCount = 1;
  int _clarity = 88;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _waveTimer?.cancel();
    _pulseController.dispose();
    _reviewYtController?.close();
    super.dispose();
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _hasEvaluated = false;
      _isEvaluating = false;
      _recordSeconds = 0;
      _showReviewVideo = false;
    });

    _pulseController.repeat(reverse: true);
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _recordSeconds++);
    });

    _waveTimer?.cancel();
    _waveTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted || !_isRecording) return;
      setState(() {
        for (int i = 0; i < _waveformHeights.length; i++) {
          _waveformHeights[i] = 10.0 + _random.nextDouble() * 38.0;
        }
      });
    });
  }

  void _stopAndAnalyze() {
    _recordTimer?.cancel();
    _waveTimer?.cancel();

    _pulseController.stop();
    _pulseController.reset();

    setState(() {
      _isRecording = false;
      _isEvaluating = true;
    });

    // Simulate intelligent AI speech analysis
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (!mounted) return;

      // Realistic variation based on practice duration
      final durationFactor = _recordSeconds.clamp(15, 90);
      final calcWpm = 125 + (_random.nextInt(25));
      final calcFillers = max(0, 4 - (durationFactor ~/ 20));
      final calcScore = 80 + _random.nextInt(15);
      final calcClarity = 82 + _random.nextInt(14);

      setState(() {
        _isEvaluating = false;
        _hasEvaluated = true;
        _score = calcScore;
        _wpm = calcWpm;
        _fillerCount = calcFillers;
        _clarity = calcClarity;
      });
    });
  }

  void _watchKeyVideoSegment() {
    setState(() {
      _showReviewVideo = true;
      _reviewYtController?.close();
      _reviewYtController = YoutubePlayerController.fromVideoId(
        videoId: widget.lesson.youtubeVideoId,
        autoPlay: true,
        startSeconds: widget.lesson.timestampSeconds.toDouble(),
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          mute: false,
          playsInline: true,
        ),
      );
    });
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

  String _formatTimer(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── App Bar ───────────────────────────────────────────────────
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
                  Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: AppColors.primaryPurple,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'AI Practice Coach',
                        style: AppTextStyles.headingMOf(
                          context,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const ThemeToggleButton(size: 38, compact: true),
                ],
              ),
            ),

            // ── Content ───────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // AI Coach Prompt Header Card
                    _buildCoachPromptCard(),

                    const SizedBox(height: 20),

                    // Middle Workspace depending on state
                    if (_isEvaluating)
                      _buildEvaluatingState()
                    else if (_hasEvaluated)
                      _buildFeedbackSection()
                    else
                      _buildRecordingWorkspace(),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Coach Prompt Card ──────────────────────────────────────────────────
  Widget _buildCoachPromptCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _categoryColor.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: AppColors.softShadowOf(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryPurple, AppColors.accentBlue],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.psychology_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.lesson.title,
                      style: AppTextStyles.headingMOf(
                        context,
                      ).copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '${widget.lesson.category.toUpperCase()} • ${widget.lesson.levelLabel}',
                          style: AppTextStyles.caption.copyWith(
                            color: _categoryColor,
                            fontWeight: FontWeight.w700,
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
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Text(
            'COACHING PROMPT',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.lesson.practiceExercise,
            style: AppTextStyles.bodyMOf(
              context,
            ).copyWith(height: 1.45, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // ── Recording Workspace ────────────────────────────────────────────────
  Widget _buildRecordingWorkspace() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: AppColors.softShadowOf(context),
      ),
      child: Column(
        children: [
          // Timer
          Text(
            _formatTimer(_recordSeconds),
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w800,
              color: _isRecording
                  ? const Color(0xFFFF3B30)
                  : AppColors.textPrimaryOf(context),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isRecording
                ? 'AI Coach is listening... Speak with clarity'
                : 'Target: 60 to 90 seconds response',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 24),

          // Waveform indicator
          if (_isRecording)
            SizedBox(
              height: 48,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: _waveformHeights
                    .map(
                      (h) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: 4.5,
                        height: h,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              AppColors.primaryPurple,
                              Color(0xFFFF3B30),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    )
                    .toList(),
              ),
            )
          else
            const SizedBox(height: 48),

          const SizedBox(height: 24),

          // Microphone button
          GestureDetector(
            onTap: _isRecording ? _stopAndAnalyze : _startRecording,
            child: ScaleTransition(
              scale: _isRecording
                  ? _pulseAnimation
                  : const AlwaysStoppedAnimation(1.0),
              child: Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isRecording
                        ? const [Color(0xFFFF3B30), Color(0xFFFF5E3A)]
                        : const [
                            AppColors.primaryPurple,
                            AppColors.accentBlue,
                          ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_isRecording
                              ? const Color(0xFFFF3B30)
                              : AppColors.primaryPurple)
                          .withValues(alpha: 0.38),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
          ),

          const SizedBox(height: 18),

          Text(
            _isRecording
                ? 'Tap square to finish & analyze'
                : 'Tap microphone to start practicing',
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Evaluating State ───────────────────────────────────────────────────
  Widget _buildEvaluatingState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: AppColors.softShadowOf(context),
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              strokeWidth: 3.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.primaryPurple,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Analyzing Your Practice...',
            style: AppTextStyles.headingMOf(
              context,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'AI Coach is evaluating pace, filler words, and vocal delivery',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ── AI Feedback & Targeted Video Card ──────────────────────────────────
  Widget _buildFeedbackSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Score Header Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primaryPurple.withValues(alpha: 0.12),
                AppColors.accentBlue.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.primaryPurple.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Practice Evaluated!',
                          style: AppTextStyles.headingMOf(
                            context,
                          ).copyWith(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Target Skill: ${widget.lesson.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '$_score%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Metric Badges
              Row(
                children: [
                  _buildMetricPill(
                    icon: Icons.speed_rounded,
                    label: '$_wpm WPM',
                    status: 'Optimal Pace',
                    color: AppColors.accentBlue,
                  ),
                  const SizedBox(width: 8),
                  _buildMetricPill(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: '$_fillerCount Fillers',
                    status: _fillerCount <= 1 ? 'Low' : 'Review',
                    color: _fillerCount <= 1
                        ? AppColors.successGreen
                        : AppColors.warningAmber,
                  ),
                  const SizedBox(width: 8),
                  _buildMetricPill(
                    icon: Icons.verified_rounded,
                    label: '$_clarity% Clarity',
                    status: 'Clear',
                    color: AppColors.primaryPurple,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── AI VIDEO RECOMMENDATION CARD (KEY REQUEST) ─────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.cardOf(context),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFFFF0000).withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF0000).withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // AI Coach recommendation banner
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF0000).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.smart_display_rounded,
                      color: Color(0xFFFF0000),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI COACH VIDEO FEEDBACK',
                          style: AppTextStyles.caption.copyWith(
                            color: const Color(0xFFFF0000),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            fontSize: 10.5,
                          ),
                        ),
                        Text(
                          'Watch this part again to improve yourself',
                          style: AppTextStyles.headingMOf(
                            context,
                          ).copyWith(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Segment callout
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.iconButtonBgOf(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderOf(context)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      size: 18,
                      color: Color(0xFFFF0000),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Target Segment: ${widget.lesson.keyVideoTimestamp} – ${widget.lesson.keyVideoTimestampEnd}',
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // AI Advice Note
              Text(
                widget.lesson.keyVideoTimestampTip,
                style: AppTextStyles.bodyMOf(context).copyWith(
                  height: 1.45,
                  fontSize: 13.5,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 16),

              // Action button to watch target segment
              if (!_showReviewVideo)
                InkWell(
                  onTap: _watchKeyVideoSegment,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF0000), Color(0xFFCC0000)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFFFF0000).withValues(alpha: 0.28),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Watch from ${widget.lesson.keyVideoTimestamp} in Player',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                // Inline Video Player starting at timestamp
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: YoutubePlayer(
                    controller: _reviewYtController!,
                    aspectRatio: 16 / 9,
                    backgroundColor: Colors.black,
                    thumbnailFormat: ThumbnailFormat.jpeg,
                    thumbnailQuality: ThumbnailQuality.high,
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Actions
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _startRecording,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: AppColors.borderOf(context)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Practice Again',
                  style: TextStyle(
                    color: AppColors.textPrimaryOf(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GradientButton(
                text: 'Done Lesson',
                icon: Icons.check_rounded,
                onPressed: () => context.pop(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricPill({
    required IconData icon,
    required String label,
    required String status,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.cardOf(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              status,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
