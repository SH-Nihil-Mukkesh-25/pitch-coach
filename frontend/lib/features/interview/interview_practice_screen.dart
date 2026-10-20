import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/models/practice_mode.dart';
import '../../core/providers/session_results_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/repositories/session_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_atmosphere.dart';
import '../../core/widgets/theme_toggle_button.dart';
import 'bloc/practice_session_bloc.dart';
import 'widgets/resume_interview_modal.dart';
export 'controllers/interview_session_controller.dart';
import 'controllers/interview_session_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen UI
// ─────────────────────────────────────────────────────────────────────────────

class InterviewPracticeScreen extends StatelessWidget {
  final PracticeSessionConfig? initialConfig;
  final InterviewSessionController? controller;

  const InterviewPracticeScreen({
    super.key,
    this.initialConfig,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    if (controller != null) {
      return ChangeNotifierProvider<InterviewSessionController>.value(
        value: controller!,
        child: Builder(
          builder: (context) {
            final ctrl = context.read<InterviewSessionController>();
            return BlocProvider<PracticeSessionBloc>.value(
              value: ctrl.bloc,
              child: const _InterviewPracticeContent(),
            );
          },
        ),
      );
    }

    return ChangeNotifierProvider(
      create: (context) => InterviewSessionController(
        isGuest: context.read<UserProvider>().isGuest,
        initialConfig: initialConfig,
      ),
      child: Builder(
        builder: (context) {
          final ctrl = context.read<InterviewSessionController>();
          return BlocProvider<PracticeSessionBloc>.value(
            value: ctrl.bloc,
            child: const _InterviewPracticeContent(),
          );
        },
      ),
    );
  }
}

class _InterviewPracticeContent extends StatefulWidget {
  const _InterviewPracticeContent();

  @override
  State<_InterviewPracticeContent> createState() =>
      __InterviewPracticeContentState();
}

class __InterviewPracticeContentState extends State<_InterviewPracticeContent>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 0.35).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctrl = context.read<InterviewSessionController>();
      ctrl.onAutoStop = (sessionId) {
        if (!mounted) return;
        if (sessionId != null) {
          context.read<SessionResultsProvider>().startBackgroundProcessing(
            sessionId: sessionId,
            topic: ctrl.currentPrompt.text,
            mode: ctrl.currentMode.id,
          );
          context.push('/results', extra: sessionId);
        } else {
          context.push('/results');
        }
      };
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Interruption handling for phone calls or switching away mid-recording
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      final ctrl = context.read<InterviewSessionController>();
      if (ctrl.isRecording) {
        ctrl.handleAppInterruption();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    super.dispose();
  }

  Future<bool> _confirmLeaveMidRecording(
    InterviewSessionController ctrl,
  ) async {
    if (!ctrl.isRecording) return true;

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardOf(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.borderOf(context)),
        ),
        title: Text(
          'Discard Recording?',
          style: AppTextStyles.headingMOf(context),
        ),
        content: Text(
          'Leaving now will cancel your active recording. Are you sure you want to discard this take?',
          style: AppTextStyles.bodyMOf(
            context,
          ).copyWith(color: AppColors.textSecondaryOf(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Keep Recording',
              style: TextStyle(color: AppColors.primaryPurpleLight),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard & Leave'),
          ),
        ],
      ),
    );

    if (shouldLeave == true) {
      await ctrl.cancelRecording();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<InterviewSessionController>();

    return PopScope(
      canPop: !ctrl.isRecording,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final allow = await _confirmLeaveMidRecording(ctrl);
        if (allow && context.mounted) {
          context.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: AppAtmosphere(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 12.0,
              ),
              child: Column(
                children: [
                  // 1. Top bar with Mode Title, Back button, and Timer / Target pill
                  _buildTopAppBar(context, ctrl),
                  _buildLiveCaptionBanner(ctrl),

                  // 2. Middle Scrollable Area: Mode tabs, Templates, Question Card, Central Stage
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),

                          // Mode selection tabs (only visible when idle)
                          if (!ctrl.isRecording && !ctrl.isUploading) ...[
                            _buildModeTabs(ctrl),
                            const SizedBox(height: 10),
                            _buildTemplateSelector(ctrl),
                            const SizedBox(height: 12),
                          ],

                          // Question Prompt Card (with real Question Bank navigation & follow-up)
                          _buildQuestionCard(ctrl),

                          if (!ctrl.isRecording &&
                              !ctrl.isUploading &&
                              ctrl.currentFollowUp == null)
                            const SizedBox(height: 12),

                          // Central Stage: Live Waveform, Instructions, or Error Recovery
                          _buildCentralStage(context, ctrl),

                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // 3. Pinned Bottom Controls (Record, Stop, Cancel, Retry, Finish)
                  _buildBottomControls(context, ctrl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopAppBar(
    BuildContext context,
    InterviewSessionController ctrl,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Semantics(
          button: true,
          label: 'Go back to previous screen',
          child: GestureDetector(
            onTap: () async {
              if (ctrl.isRecording) {
                final allow = await _confirmLeaveMidRecording(ctrl);
                if (allow && context.mounted) context.pop();
              } else {
                context.pop();
              }
            },
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
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              ctrl.currentMode.title,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.headingMOf(
                context,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        Builder(
          builder: (ctx) {
            final settings = ctx.watch<SettingsProvider>();
            final showLiveCue = ctrl.isRecording && settings.ambientLiveCues;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: const Key('caption_toggle_button'),
                  tooltip: ctrl.showCaptions
                      ? 'Captions: ON'
                      : 'Captions: OFF',
                  icon: Icon(
                    ctrl.showCaptions
                        ? Icons.closed_caption_rounded
                        : Icons.closed_caption_disabled_rounded,
                    size: 20,
                    color: ctrl.showCaptions
                        ? AppColors.primaryPurple
                        : AppColors.textSecondary,
                  ),
                  onPressed: ctrl.toggleCaptions,
                ),
                IconButton(
                  key: const Key('tts_toggle_button'),
                  tooltip: ctrl.isTtsEnabled
                      ? 'Interviewer Voice: ON'
                      : 'Interviewer Voice: OFF',
                  icon: Icon(
                    ctrl.isTtsEnabled
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    size: 20,
                    color: ctrl.isTtsEnabled
                        ? AppColors.primaryPurple
                        : AppColors.textSecondary,
                  ),
                  onPressed: ctrl.toggleTts,
                ),
                const SizedBox(width: 4),
                Semantics(
                  label: 'Pacing timer: ${ctrl.formattedTime}',
                  child: _TimerPill(
                    time: ctrl.isRecording
                        ? ctrl.formattedTime
                        : '${ctrl.currentPrompt.targetDurationSeconds}s target',
                    isActive: ctrl.isRecording,
                    indicatorColor: showLiveCue ? ctrl.pacingColor : null,
                  ),
                ),
                const SizedBox(width: 8),
                const ThemeToggleButton(size: 38, compact: true),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildLiveCaptionBanner(InterviewSessionController ctrl) {
    final caption = ctrl.currentCaption;
    if (!ctrl.showCaptions || caption == null || caption.isEmpty) {
      return const SizedBox.shrink();
    }
    return Semantics(
      liveRegion: true,
      label: 'Interviewer says: $caption',
      child: Container(
        key: const Key('interview_live_caption_banner'),
        margin: const EdgeInsets.only(top: 10, bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.cardOf(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.primaryPurple.withValues(alpha: 0.4),
          ),
          boxShadow: AppColors.softShadowOf(context),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              ctrl.isTtsSpeaking
                  ? Icons.record_voice_over_rounded
                  : Icons.closed_caption_rounded,
              size: 20,
              color: AppColors.primaryPurple,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                caption,
                style: AppTextStyles.bodyMOf(context).copyWith(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Dismiss caption',
              icon: const Icon(Icons.close_rounded, size: 16),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: ctrl.toggleCaptions,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeTabs(InterviewSessionController ctrl) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          ...PracticeMode.allModes.map((mode) {
            final isSelected =
                mode.id == ctrl.currentMode.id &&
                ctrl.currentMode.title != 'Resume Interview';
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => ctrl.switchMode(mode.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryPurple.withValues(alpha: 0.18)
                        : AppColors.cardOf(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primaryPurple
                          : AppColors.borderOf(context),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        mode.icon,
                        size: 16,
                        color: isSelected
                            ? AppColors.primaryPurple
                            : AppColors.textSecondaryOf(context),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        mode.title.replaceAll(' Practice', ''),
                        style: AppTextStyles.captionOf(context).copyWith(
                          color: isSelected
                              ? AppColors.primaryPurple
                              : AppColors.textSecondaryOf(context),
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          // Feature 3: Resume Interview button
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: ctrl.isRecording || ctrl.isUploading
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final questions =
                          await ResumeInterviewModal.show(context);
                      if (questions != null) {
                        ctrl.loadResumeQuestions(questions);
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Loaded ${questions.allQuestions.length} tailored interview questions from your resume!',
                              ),
                              backgroundColor: const Color(0xFF10B981),
                            ),
                          );
                        }
                      }
                    },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: ctrl.currentMode.title == 'Resume Interview'
                      ? AppColors.primaryPurple.withValues(alpha: 0.22)
                      : Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                          : const Color(0xFF10B981).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: ctrl.currentMode.title == 'Resume Interview'
                        ? AppColors.primaryPurple
                        : const Color(0xFF10B981).withValues(alpha: 0.45),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.badge_outlined,
                      size: 16,
                      color: Color(0xFF10B981),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Resume Interview',
                      style: AppTextStyles.captionOf(context).copyWith(
                        color: const Color(0xFF10B981),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateSelector(InterviewSessionController ctrl) {
    final templates = ctrl.availableTemplates;
    if (templates.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_stories_outlined,
                  size: 14,
                  color: AppColors.primaryPurple,
                ),
                const SizedBox(width: 5),
                Text(
                  'Pitch Templates & Rubrics',
                  style: AppTextStyles.captionOf(context).copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
              ],
            ),
            if (ctrl.selectedTemplate != null)
              GestureDetector(
                onTap: () => ctrl.selectTemplate(null),
                child: Text(
                  'Clear Template',
                  style: AppTextStyles.captionOf(context).copyWith(
                    color: AppColors.textSecondaryOf(context),
                    fontSize: 11,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: templates.map((tmpl) {
              final isSelected = ctrl.selectedTemplate?.id == tmpl.id;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: InkWell(
                  key: Key('template_chip_${tmpl.id}'),
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    if (isSelected) {
                      ctrl.selectTemplate(null);
                    } else {
                      ctrl.selectTemplate(tmpl);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryPurple.withValues(alpha: 0.20)
                          : AppColors.cardOf(context),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primaryPurple
                            : AppColors.borderOf(context),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tmpl.title,
                          style: AppTextStyles.captionOf(context).copyWith(
                            color: isSelected
                                ? AppColors.primaryPurple
                                : AppColors.textPrimaryOf(context),
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primaryPurple.withValues(alpha: 0.3)
                                : AppColors.chipBgOf(context),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${tmpl.targetDurationSeconds}s',
                            style: AppTextStyles.captionOf(context).copyWith(
                              fontSize: 10,
                              color: isSelected
                                  ? AppColors.primaryPurple
                                  : AppColors.textSecondaryOf(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(InterviewSessionController ctrl) {
    final prompt = ctrl.currentPrompt;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: AppColors.softShadowOf(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Category Pill + Question Index ("Question X of Y")
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  prompt.category,
                  style: AppTextStyles.captionOf(context).copyWith(
                    color: AppColors.primaryPurple,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              Text(
                'Question ${ctrl.promptIndex + 1} of ${ctrl.totalPrompts}',
                style: AppTextStyles.captionOf(context).copyWith(
                  color: AppColors.textSecondaryOf(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Question Prompt Text
          Text(
            prompt.text,
            style: AppTextStyles.headingMOf(
              context,
            ).copyWith(fontWeight: FontWeight.w700, fontSize: 18, height: 1.35),
          ),

          if (prompt.hint.isNotEmpty && ctrl.currentFollowUp == null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtleOf(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 16,
                    color: AppColors.warningAmber,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      prompt.hint,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Pitch Template Target Sections Roadmap
          if (ctrl.selectedTemplate != null) ...[
            const SizedBox(height: 12),
            Container(
              key: const Key('template_roadmap_card'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryPurple.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.checklist_rtl_rounded,
                        size: 16,
                        color: AppColors.primaryPurple,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Target Sections (${ctrl.selectedTemplate!.sections.length})',
                        style: AppTextStyles.captionOf(context).copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryPurple,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Goal: ${ctrl.selectedTemplate!.targetDurationSeconds}s',
                        style: AppTextStyles.captionOf(context).copyWith(
                          fontSize: 11,
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: ctrl.selectedTemplate!.sections.map((sec) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.cardOf(context),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.borderOf(context),
                          ),
                        ),
                        child: Text(
                          '${sec.name} (${sec.weight.toInt()}%)',
                          style: AppTextStyles.captionOf(context).copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Coach Focus: ${ctrl.selectedTemplate!.coachingFocus}',
                    style: AppTextStyles.captionOf(context).copyWith(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Multi-Turn Follow-Up Question Card
          if (ctrl.currentFollowUp != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primaryPurple.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.psychology_rounded,
                            size: 18,
                            color: AppColors.primaryPurple,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'AI FOLLOW-UP ${ctrl.followUpCount}/2',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.primaryPurple,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      if (ctrl.lastTurnLatencyMs != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.bolt_rounded,
                              size: 14,
                              color: AppColors.primaryPurple,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${(ctrl.lastTurnLatencyMs! / 1000).toStringAsFixed(1)}s',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ctrl.currentFollowUp!,
                    style: AppTextStyles.bodyMOf(context).copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryOf(context),
                      height: 1.35,
                    ),
                  ),
                  if (ctrl.interviewerReason != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Why: ${ctrl.interviewerReason!}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Question Switcher (when not actively recording)
          if (!ctrl.isRecording && !ctrl.isUploading) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed:
                      ctrl.hasPreviousPrompt ? ctrl.previousPrompt : null,
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: const Text('Previous'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    disabledForegroundColor:
                        AppColors.textSecondary.withValues(alpha: 0.35),
                    padding: EdgeInsets.zero,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: ctrl.hasNextPrompt ? ctrl.nextPrompt : null,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('Next Prompt'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryPurpleLight,
                    disabledForegroundColor:
                        AppColors.textSecondary.withValues(alpha: 0.35),
                    side: BorderSide(
                      color: ctrl.hasNextPrompt
                          ? AppColors.primaryPurpleLight.withValues(
                              alpha: 0.4,
                            )
                          : AppColors.borderOf(context).withValues(alpha: 0.3),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCentralStage(
    BuildContext context,
    InterviewSessionController ctrl,
  ) {
    if (ctrl.isPermissionDenied) {
      return _buildPermissionDeniedCard(ctrl);
    }

    if (ctrl.turnEvaluationFailed) {
      return _buildTurnEvaluationFailedRecoveryCard(context, ctrl);
    }

    if (ctrl.isFailed) {
      return _buildUploadFailedRecoveryCard(context, ctrl);
    }

    if (ctrl.isThinking) {
      return _buildThinkingCard();
    }

    if (ctrl.isUploading) {
      return _buildUploadingCard();
    }

    if (ctrl.isRecording) {
      return _buildActiveRecordingCard(ctrl);
    }

    // Idle: Preparation State (hidden when actively responding to an AI follow-up)
    if (ctrl.currentFollowUp != null) {
      return const SizedBox.shrink();
    }
    return _buildIdlePreparationCard(ctrl);
  }

  Widget _buildIdlePreparationCard(InterviewSessionController ctrl) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: AppColors.softShadowOf(context),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mic_none_rounded,
              color: AppColors.primaryPurple,
              size: 38,
            ),
          ),
          const SizedBox(height: 14),
          Text('Ready to Rehearse', style: AppTextStyles.headingMOf(context)),
          const SizedBox(height: 8),
          Text(
            'Take a breath, organize your key points, and tap the record button below when ready.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMOf(
              context,
            ).copyWith(color: AppColors.textSecondaryOf(context), height: 1.35),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtleOf(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.timer_outlined,
                  size: 16,
                  color: AppColors.primaryPurple,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Recommended: ${ctrl.currentPrompt.targetDurationSeconds}s • Min: 5s • Max: 5m',
                    style: AppTextStyles.captionOf(
                      context,
                    ).copyWith(color: AppColors.textSecondaryOf(context)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRecordingCard(InterviewSessionController ctrl) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: ctrl.durationWarning != null
              ? AppColors.warningAmber.withValues(alpha: 0.4)
              : AppColors.primaryPurple.withValues(alpha: 0.3),
        ),
        boxShadow: AppColors.softShadowOf(context),
      ),
      child: Column(
        children: [
          // Header: Live Recording Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeTransition(
                opacity: _pulseAnimation,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.dangerRed,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'RECORDING IN PROGRESS',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.dangerRed,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Elapsed timer display with ambient live pacing indicator
          Builder(
            builder: (ctx) {
              final settings = ctx.watch<SettingsProvider>();
              final showPacingCue = ctrl.isRecording && settings.ambientLiveCues;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtleOf(context),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: showPacingCue
                        ? ctrl.pacingColor
                        : AppColors.borderOf(context),
                    width: showPacingCue ? 2.5 : 1.0,
                  ),
                  boxShadow: showPacingCue
                      ? [
                          BoxShadow(
                            color: ctrl.pacingColor.withValues(alpha: 0.30),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  ctrl.formattedTime,
                  style: AppTextStyles.headingXLOf(context).copyWith(
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [const FontFeature.tabularFigures()],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 18),

          // Real-time audio waveform strip
          _AudioWaveformVisualizer(level: ctrl.audioLevel),

          const SizedBox(height: 16),

          // Duration warning (if too short or approaching 5m)
          if (ctrl.durationWarning != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warningAmber.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.warningAmber.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppColors.warningAmber,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ctrl.durationWarning!,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.warningAmber,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              'Speak clearly. Your audio will be sent to the AI pipeline upon stop.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyM.copyWith(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUploadingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: AppColors.softShadowOf(context),
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              strokeWidth: 3.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.primaryPurple,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Uploading & Analyzing...',
            style: AppTextStyles.headingMOf(context),
          ),
          const SizedBox(height: 8),
          Text(
            'Transferring audio to server. Deep speech analysis will begin immediately.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMOf(
              context,
            ).copyWith(color: AppColors.textSecondaryOf(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionDeniedCard(InterviewSessionController ctrl) {
    final isPermanent =
        ctrl.micPermissionState == MicPermissionState.permanentlyDenied;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.dangerRed.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.dangerRed.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mic_off_rounded,
              color: AppColors.dangerRed,
              size: 36,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Microphone Access Required',
            style: AppTextStyles.headingM.copyWith(color: AppColors.textOnDark),
          ),
          const SizedBox(height: 8),
          Text(
            ctrl.errorMessage ??
                'Pitch Coach needs microphone permission to record your rehearsal and calculate confidence metrics.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyM.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isPermanent)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                  ),
                  onPressed: ctrl.openSettings,
                  icon: const Icon(Icons.settings_rounded, size: 18),
                  label: const Text('Open Settings'),
                ),
              const SizedBox(width: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textOnDark,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
                onPressed: ctrl.startRecording,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUploadFailedRecoveryCard(
    BuildContext context,
    InterviewSessionController ctrl,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.warningAmber.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warningAmber.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              color: AppColors.warningAmber,
              size: 36,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Upload Interrupted',
            style: AppTextStyles.headingM.copyWith(color: AppColors.textOnDark),
          ),
          const SizedBox(height: 8),
          Text(
            ctrl.errorMessage ??
                'Network dropped during upload. Don\'t worry—your audio take is preserved safely on your phone.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyM.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onPressed: () => ctrl.retryUpload((sessionId) {
                  if (sessionId != null && context.mounted) {
                    context
                        .read<SessionResultsProvider>()
                        .startBackgroundProcessing(
                          sessionId: sessionId,
                          topic: ctrl.currentPrompt.text,
                          mode: ctrl.currentMode.id,
                        );
                    context.push('/results', extra: sessionId);
                  } else if (context.mounted) {
                    context.push('/results');
                  }
                }),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry Upload'),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.dangerRed,
                  side: BorderSide(
                    color: AppColors.dangerRed.withValues(alpha: 0.4),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                onPressed: ctrl.discardFailedRecording,
                child: const Text('Discard Take'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThinkingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.primaryPurple.withValues(alpha: 0.3),
        ),
        boxShadow: AppColors.softShadowOf(context),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.psychology_rounded,
              color: AppColors.primaryPurple,
              size: 40,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Interviewer is thinking...',
            style: AppTextStyles.headingMOf(context),
          ),
          const SizedBox(height: 8),
          Text(
            'Evaluating your response for root cause, technical specifics, and measurable outcomes.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMOf(
              context,
            ).copyWith(color: AppColors.textSecondaryOf(context), height: 1.35),
          ),
          const SizedBox(height: 18),
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3.0,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.primaryPurple,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTurnEvaluationFailedRecoveryCard(
    BuildContext context,
    InterviewSessionController ctrl,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.warningAmber.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warningAmber.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.wifi_off_rounded,
              color: AppColors.warningAmber,
              size: 36,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Evaluation Interrupted',
            style: AppTextStyles.headingM.copyWith(color: AppColors.textOnDark),
          ),
          const SizedBox(height: 8),
          Text(
            ctrl.errorMessage ??
                'Network dropped during answer analysis. Your spoken answer is safely preserved.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyM.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onPressed: () => ctrl.retryTurnEvaluation((sessionId) {
                  if (sessionId != null && context.mounted) {
                    context
                        .read<SessionResultsProvider>()
                        .startBackgroundProcessing(
                          sessionId: sessionId,
                          topic: ctrl.currentPrompt.text,
                          mode: ctrl.currentMode.id,
                        );
                    context.push('/results', extra: sessionId);
                  } else if (context.mounted) {
                    context.push('/results');
                  }
                }),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry Evaluation'),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.dangerRed,
                  side: BorderSide(
                    color: AppColors.dangerRed.withValues(alpha: 0.4),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                onPressed: ctrl.discardFailedRecording,
                child: const Text('Discard Take'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(
    BuildContext context,
    InterviewSessionController ctrl,
  ) {
    if (ctrl.isUploading || ctrl.isThinking) {
      return const SizedBox(height: 80);
    }

    if (ctrl.isRecording) {
      return Column(
        children: [
          // Stop Button
          Semantics(
            button: true,
            label: 'Stop recording interview answer',
            child: GestureDetector(
              onTap: () => ctrl.stopRecording((sessionId) {
                if (sessionId != null && context.mounted) {
                  context
                      .read<SessionResultsProvider>()
                      .startBackgroundProcessing(
                        sessionId: sessionId,
                        topic: ctrl.currentPrompt.text,
                        mode: ctrl.currentMode.id,
                      );
                  context.push('/results', extra: sessionId);
                } else if (context.mounted) {
                  context.push('/results');
                }
              }),
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppColors.dangerRed,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.dangerRed.withValues(alpha: 0.45),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () async {
              final allow = await _confirmLeaveMidRecording(ctrl);
              if (allow && context.mounted) {
                // Recording cancelled and reset
              }
            },
            child: Text(
              'Cancel take',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      );
    }

    // Idle: Big Record Button + optional Finish Early if in follow-up
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: 'Start recording interview answer',
          child: GestureDetector(
            onTap: ctrl.startRecording,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryPurple.withValues(alpha: 0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.mic_rounded, color: Colors.white, size: 36),
              ),
            ),
          ),
        ),
        if (ctrl.currentFollowUp != null) ...[
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => ctrl.skipFollowUpAndFinish((sessionId) {
              if (sessionId != null && context.mounted) {
                context
                    .read<SessionResultsProvider>()
                    .startBackgroundProcessing(
                      sessionId: sessionId,
                      topic: ctrl.currentPrompt.text,
                      mode: ctrl.currentMode.id,
                    );
                context.push('/results', extra: sessionId);
              } else if (context.mounted) {
                context.push('/results');
              }
            }),
            icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
            label: const Text('Finish & Score Exchange'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryPurpleLight,
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Isolated UI Components
// ─────────────────────────────────────────────────────────────────────────────

class _TimerPill extends StatelessWidget {
  final String time;
  final bool isActive;
  final Color? indicatorColor;

  const _TimerPill({
    required this.time,
    required this.isActive,
    this.indicatorColor,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = indicatorColor ?? AppColors.primaryPurple;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive
            ? activeColor.withValues(alpha: 0.18)
            : AppColors.surfaceSubtleOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? activeColor : AppColors.borderOf(context),
          width: isActive ? 1.5 : 1.0,
        ),
      ),
      child: Text(
        time,
        style: AppTextStyles.bodySmallBoldOf(context).copyWith(
          color: isActive
              ? activeColor
              : AppColors.textSecondaryOf(context),
          fontWeight: FontWeight.w700,
          fontFeatures: [const FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _AudioWaveformVisualizer extends StatelessWidget {
  final double level;

  const _AudioWaveformVisualizer({required this.level});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(28, (index) {
          final distance = (index - 13.5).abs() / 13.5;
          final barLevel = (level * (1 - distance * 0.5)).clamp(0.05, 1.0);
          return AnimatedContainer(
            duration: const Duration(milliseconds: 75),
            width: 3.5,
            height: 6 + 40 * barLevel,
            decoration: BoxDecoration(
              color: AppColors.primaryPurpleLight.withValues(
                alpha: (0.3 + 0.7 * barLevel).clamp(0.0, 1.0),
              ),
              borderRadius: BorderRadius.circular(2.5),
            ),
          );
        }),
      ),
    );
  }
}
