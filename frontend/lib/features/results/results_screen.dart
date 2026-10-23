import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/models/practice_mode.dart';
import '../../core/models/session_result.dart';
import '../../core/providers/session_results_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/repositories/demo_repository.dart';
import '../../core/repositories/session_repository.dart';
import '../../core/services/api_client.dart';
import '../../core/services/report_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/bottom_nav_bar.dart';
import '../../core/widgets/circular_gauge_painter.dart';
import '../../core/widgets/theme_toggle_button.dart';

class ResultsScreen extends StatefulWidget {
  final String? sessionId;
  final SessionResult? initialResult;
  final SessionResult? initialParentResult;
  const ResultsScreen({
    super.key,
    this.sessionId,
    this.initialResult,
    this.initialParentResult,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _mainController;
  late Animation<double> _scoreGaugeAnimation;
  late Animation<double> _chartAnimation;

  // Staggered reveal animations
  late Animation<double> _card0Anim;
  late Animation<double> _card1Anim;
  late Animation<double> _card2Anim;
  late Animation<double> _card3Anim;

  int _navIndex = 0;

  // ── Attempt Comparison (Feature 2) ────────────────────────────────────
  SessionResult? _parentResult;
  bool _isLoadingParent = false;
  String? _loadedParentId;

  // ── Audio Playback (Unit 2) ────────────────────────────────────────────
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _audioDuration = Duration.zero;
  Duration _audioPosition = Duration.zero;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<void>? _playerCompleteSub;

  // ── Shareable Reports (Feature 10) ────────────────────────────────────
  bool _isExportingReport = false;

  Future<void> _exportPdfReport(SessionResult? result) async {
    if (result == null || _isExportingReport) return;
    setState(() => _isExportingReport = true);
    try {
      final success = await ReportService.instance.openOrShareSessionReport(result.id);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Report staged in local cache. Check downloads or network connection.',
            ),
            backgroundColor: AppColors.primaryPurple,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not generate report: $e'),
            backgroundColor: AppColors.dangerRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExportingReport = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();

    _parentResult = widget.initialParentResult;
    _loadedParentId = widget.initialParentResult?.id;

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Staggered entrance cards
    _card0Anim = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOutCubic),
    );
    _card1Anim = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.12, 0.47, curve: Curves.easeOutCubic),
    );
    _card2Anim = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.24, 0.60, curve: Curves.easeOutCubic),
    );
    _card3Anim = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.36, 0.72, curve: Curves.easeOutCubic),
    );

    // Score ring animation — target is real score once loaded, otherwise 0
    _scoreGaugeAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.1, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    // Chart draw animation
    _chartAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.3, 0.95, curve: Curves.easeOutCubic),
      ),
    );

    // Start polling or load from cache if we have a session_id
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sessionId = widget.sessionId;
      if (sessionId != null && sessionId.isNotEmpty) {
        final provider = context.read<SessionResultsProvider>();
        provider.addListener(_onResultsUpdate);
        provider.loadSession(sessionId);
        if (provider.state == ResultsLoadState.ready &&
            provider.result != null) {
          _onResultsUpdate();
        }
      } else {
        // No session id (e.g. navigated directly) — just run the animation
        _mainController.forward();
      }
    });

    // Audio player listeners
    _durationSub = _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _audioDuration = d);
    });
    _positionSub = _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _audioPosition = p);
    });
    _playerStateSub = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _playerCompleteSub = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _audioPosition = Duration.zero;
        });
      }
    });
  }

  Future<Source> _resolveAudioSource(String uri) async {
    final isRemote = uri.startsWith('http://') || uri.startsWith('https://');
    if (!isRemote) {
      return DeviceFileSource(uri);
    }
    final token = await ApiClient.getAccessToken();
    String finalUri = uri;
    if (token != null && token.isNotEmpty && !finalUri.contains('token=')) {
      final separator = finalUri.contains('?') ? '&' : '?';
      finalUri = '$finalUri${separator}token=$token';
    }
    return UrlSource(finalUri);
  }

  Future<void> _safePlaySource(Source source, {Duration? position}) async {
    try {
      if (position != null) {
        await _audioPlayer.play(source, position: position);
      } else {
        await _audioPlayer.play(source);
      }
    } catch (e) {
      debugPrint('[ResultsScreen] Audio playback error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to play audio recording.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _checkAndFetchParent(SessionResult currentResult) {
    final parentId = currentResult.parentSessionId;
    if (parentId == null ||
        parentId.isEmpty ||
        _loadedParentId == parentId ||
        _isLoadingParent) {
      return;
    }
    _isLoadingParent = true;
    _loadedParentId = parentId;
    SessionRepository.instance.getSession(parentId).then((parent) {
      if (mounted) {
        setState(() {
          _parentResult = parent;
          _isLoadingParent = false;
        });
      }
    }).catchError((e) {
      debugPrint('[ResultsScreen] Error fetching parent session $parentId: $e');
      if (mounted) {
        setState(() {
          _isLoadingParent = false;
        });
      }
    });
  }

  void _onResultsUpdate() {
    final provider = context.read<SessionResultsProvider>();
    if (provider.state == ResultsLoadState.ready && provider.result != null) {
      final res = provider.result!;
      final score = res.overallScore;
      _checkAndFetchParent(res);
      // Re-create the tween with the real score target and replay
      _scoreGaugeAnimation = Tween<double>(begin: 0.0, end: score).animate(
        CurvedAnimation(
          parent: _mainController,
          curve: const Interval(0.1, 0.85, curve: Curves.easeOutCubic),
        ),
      );
      _mainController.forward(from: 0);
      provider.removeListener(_onResultsUpdate);
    }
  }

  @override
  void dispose() {
    _durationSub?.cancel();
    _positionSub?.cancel();
    _playerStateSub?.cancel();
    _playerCompleteSub?.cancel();
    _mainController.dispose();
    _audioPlayer.dispose();
    // Release audio file from cache (actual delete deferred to next session start)
    if (widget.sessionId != null) {
      SessionRepository.instance.releaseAudioFile(widget.sessionId!);
    }
    // Remove listener if still attached
    try {
      context.read<SessionResultsProvider>().removeListener(_onResultsUpdate);
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultsProvider = context.watch<SessionResultsProvider>();
    final isGuest = context.watch<UserProvider>().isGuest;
    final result =
        widget.initialResult ??
        resultsProvider.result ??
        (isGuest && widget.sessionId == null
            ? DemoRepository.instance.result
            : null);
    if (result != null && result.parentSessionId != null) {
      _checkAndFetchParent(result);
    }
    final isAnalyzing =
        resultsProvider.state == ResultsLoadState.analyzing ||
        resultsProvider.state == ResultsLoadState.loading;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top App Bar
            _buildTopAppBar(context, result),

            // Analyzing banner
            if (isAnalyzing && widget.sessionId != null && result != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                color: AppColors.primaryPurple.withValues(alpha: 0.08),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryPurple,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Updating speech analysis in background…',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primaryPurple,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => context.go('/home'),
                      icon: const Icon(
                        Icons.downloading_rounded,
                        size: 16,
                        color: AppColors.primaryPurple,
                      ),
                      label: const Text(
                        'Minimize',
                        style: TextStyle(
                          color: AppColors.primaryPurple,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            // 2. Scrollable Body with Staggered Sections
            if (widget.sessionId != null &&
                (resultsProvider.state == ResultsLoadState.failed ||
                    resultsProvider.state == ResultsLoadState.error))
              Expanded(child: _buildFailureState(context, resultsProvider))
            else if (widget.sessionId != null && isAnalyzing && result == null)
              Expanded(
                child: _buildAnalyzingProgressCard(context, resultsProvider),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 12.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section 0: Overall Score Card
                      _buildAnimatedSection(
                        animation: _card0Anim,
                        child: _buildOverallScoreCard(result),
                      ),

                      // Section 0.1: Pitch Template Structure & Rubric Breakdown (Feature 5)
                      if (result != null &&
                          (result.templateId != null ||
                              result.structureScore != null)) ...[
                        const SizedBox(height: 20),
                        _buildAnimatedSection(
                          animation: _card0Anim,
                          child: _buildTemplateStructureCard(result),
                        ),
                      ],

                      // Section 0.25: Attempt Comparison Delta Card (Feature 2)
                      if (result != null && result.parentSessionId != null) ...[
                        const SizedBox(height: 20),
                        _buildAnimatedSection(
                          animation: _card0Anim,
                          child: _buildAttemptComparisonSection(result),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Section 0.5: Audio Playback Card (Unit 2)
                      _buildAnimatedSection(
                        animation: _card0Anim,
                        child: _buildAudioPlaybackCard(result),
                      ),

                      const SizedBox(height: 20),

                      // Section 0.75: Interactive Transcript Playback Card
                      _buildAnimatedSection(
                        animation: _card0Anim,
                        child: _buildInteractiveTranscriptCard(result),
                      ),

                      const SizedBox(height: 20),

                      // Section 1: Performance Summary Grid
                      _buildAnimatedSection(
                        animation: _card1Anim,
                        child: _buildPerformanceSummary(result),
                      ),

                      const SizedBox(height: 20),

                      // Section 1.5: Vocal Delivery & Energy Curve (Feature 7)
                      _buildAnimatedSection(
                        animation: _card1Anim,
                        child: _buildVocalDeliveryCard(result),
                      ),

                      const SizedBox(height: 20),

                      // Section 2: Session Comparison Line Chart
                      _buildAnimatedSection(
                        animation: _card2Anim,
                        child: _buildSessionComparison(),
                      ),

                      const SizedBox(height: 20),

                      // Section 3: Suggestions List
                      _buildAnimatedSection(
                        animation: _card3Anim,
                        child: _buildSuggestionsSection(result),
                      ),

                      const SizedBox(height: 24),

                      // Section 4: Primary Actions (Practice Again & Back to Home)
                      _buildAnimatedSection(
                        animation: _card3Anim,
                        child: Column(
                          children: [
                            ConstrainedBox(
                              constraints: const BoxConstraints(
                                minHeight: 52,
                                minWidth: double.infinity,
                              ),
                              child: Semantics(
                                button: true,
                                label: 'Practice again with this prompt',
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryPurple,
                                    foregroundColor: Colors.white,
                                    elevation: 4,
                                    shadowColor: AppColors.primaryPurple
                                        .withValues(alpha: 0.35),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: () {
                                    if (result == null) {
                                      context.push('/interview');
                                      return;
                                    }
                                    final mode = result.mode;
                                    final promptText = result.topicOrQuestion;
                                    final practiceMode =
                                        PracticeMode.fromId(mode);
                                    final matchedPrompt =
                                        practiceMode.prompts.firstWhere(
                                      (p) => p.text == promptText,
                                      orElse: () => PracticePrompt(
                                        id: 'retry-${result.id}',
                                        text: promptText,
                                        category: 'Practice Again',
                                        hint:
                                            'Focus on improving your pace and reducing fillers.',
                                        targetDurationSeconds:
                                            result.durationSeconds > 0
                                                ? result.durationSeconds.round()
                                                : 90,
                                      ),
                                    );
                                    context.push(
                                      '/interview',
                                      extra: PracticeSessionConfig(
                                        modeId: mode,
                                        prompt: matchedPrompt,
                                        parentSessionId: result.id,
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.mic_rounded, size: 20),
                                  label: Text(
                                    'Practice Again',
                                    style: AppTextStyles.bodyM.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ConstrainedBox(
                              constraints: const BoxConstraints(
                                minHeight: 48,
                                minWidth: double.infinity,
                              ),
                              child: Semantics(
                                button: true,
                                label: 'Export PDF Report and share',
                                child: OutlinedButton.icon(
                                  key: const Key('export_pdf_report_button'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primaryPurple,
                                    side: const BorderSide(
                                      color: AppColors.primaryPurple,
                                      width: 1.4,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: _isExportingReport || result == null
                                      ? null
                                      : () => _exportPdfReport(result),
                                  icon: _isExportingReport
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              AppColors.primaryPurple,
                                            ),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.picture_as_pdf_outlined,
                                          size: 20,
                                        ),
                                  label: Text(
                                    _isExportingReport
                                        ? 'Generating PDF Report...'
                                        : 'Export PDF Report',
                                    style: AppTextStyles.bodyMOf(context).copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryPurple,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ConstrainedBox(
                              constraints: const BoxConstraints(
                                minHeight: 48,
                                minWidth: double.infinity,
                              ),
                              child: Semantics(
                                button: true,
                                label: 'Navigate back to Home',
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.textPrimaryOf(
                                      context,
                                    ),
                                    side: BorderSide(
                                      color: AppColors.borderOf(context),
                                      width: 1.2,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: () => context.go('/home'),
                                  icon: const Icon(Icons.home_outlined, size: 20),
                                  label: Text(
                                    'Back to Home',
                                    style: AppTextStyles.bodyMOf(
                                      context,
                                    ).copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: BottomNavBar(
        currentIndex: _navIndex,
        onTap: (index) {
          setState(() => _navIndex = index);
          switch (index) {
            case 0:
              context.go('/home');
              break;
            case 1:
              context.go('/history');
              break;
            case 2:
              context.push('/interview');
              break;
            case 3:
              context.go('/progress');
              break;
            case 4:
              context.go('/profile');
              break;
          }
        },
        onMicTap: () => context.push('/interview'),
      ),
    );
  }

  Widget _buildFailureState(
    BuildContext context,
    SessionResultsProvider provider,
  ) {
    final timedOut = provider.state == ResultsLoadState.error;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: AppColors.warningAmber,
            ),
            const SizedBox(height: 16),
            Text(
              timedOut
                  ? 'Still waiting on your results'
                  : "We couldn't analyze this session",
              style: AppTextStyles.headingM.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              provider.errorMessage ??
                  (timedOut
                      ? 'The analysis is taking longer than expected.'
                      : 'Your recording is saved. Retry to run the AI analysis again.'),
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => provider.retry(widget.sessionId!),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(timedOut ? 'Check again' : 'Retry analysis'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyzingProgressCard(
    BuildContext context,
    SessionResultsProvider provider,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppColors.cardOf(context),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.borderOf(context)),
            boxShadow: AppColors.softShadowOf(context),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  const SizedBox(
                    width: 76,
                    height: 76,
                    child: CircularProgressIndicator(
                      strokeWidth: 5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primaryPurple,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.graphic_eq_rounded,
                    color: AppColors.primaryPurple,
                    size: 34,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                'AI Speech Analysis in Progress',
                style: AppTextStyles.headingMOf(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Transcribing audio, detecting filler words, calculating speech pacing, and evaluating answer clarity with AI...',
                style: AppTextStyles.bodyMOf(
                  context,
                ).copyWith(color: AppColors.textSecondaryOf(context)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => context.go('/home'),
                icon: const Icon(Icons.downloading_rounded, size: 18),
                label: const Text('Minimize & Run in Background'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryPurple,
                  side: BorderSide(
                    color: AppColors.primaryPurple.withValues(alpha: 0.4),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopAppBar(BuildContext context, SessionResult? result) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back Chevron Button
          GestureDetector(
            onTap: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
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

          // Title
          Text(
            'Session Results',
            style: AppTextStyles.headingMOf(
              context,
            ).copyWith(fontWeight: FontWeight.w700),
          ),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (result != null) ...[
                IconButton(
                  key: const Key('top_bar_share_report_button'),
                  tooltip: 'Export PDF Report',
                  icon: Icon(
                    Icons.share_outlined,
                    size: 20,
                    color: AppColors.textPrimaryOf(context),
                  ),
                  onPressed: _isExportingReport ? null : () => _exportPdfReport(result),
                ),
                const SizedBox(width: 4),
              ],
              const ThemeToggleButton(size: 38, compact: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAudioPlaybackCard(SessionResult? result) {
    // result.playableAudioUri provides either the cached local file or the server stream URL
    final audioUri = result?.playableAudioUri;
    final hasAudio = audioUri != null && audioUri.isNotEmpty;

    String fmtDuration(Duration d) {
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$m:$s';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: AppColors.softShadowOf(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.headphones_rounded,
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
                      'Listen to Your Recording',
                      style: AppTextStyles.headingMOf(
                        context,
                      ).copyWith(fontSize: 14),
                    ),
                    Text(
                      hasAudio
                          ? 'Tap play to review your speech'
                          : 'No recording available',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (hasAudio) ...[
            const SizedBox(height: 14),

            // Progress slider
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                activeTrackColor: AppColors.primaryPurple,
                inactiveTrackColor: AppColors.divider,
                thumbColor: AppColors.primaryPurple,
                overlayColor: AppColors.primaryPurple.withValues(alpha: 0.12),
              ),
              child: Slider(
                value: _audioDuration.inMilliseconds > 0
                    ? (_audioPosition.inMilliseconds /
                              _audioDuration.inMilliseconds)
                          .clamp(0.0, 1.0)
                    : 0.0,
                onChanged: (val) {
                  final seek = Duration(
                    milliseconds: (val * _audioDuration.inMilliseconds).toInt(),
                  );
                  _audioPlayer.seek(seek);
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Play / Pause Button
                  Semantics(
                    button: true,
                    label: _isPlaying ? 'Pause audio playback' : 'Play audio playback',
                    child: GestureDetector(
                      onTap: () async {
                        try {
                          if (_isPlaying) {
                            await _audioPlayer.pause();
                          } else {
                            if (_audioPosition >= _audioDuration &&
                                _audioDuration > Duration.zero) {
                              await _audioPlayer.seek(Duration.zero);
                              await _audioPlayer.resume();
                            } else if (_audioDuration == Duration.zero) {
                              final source = await _resolveAudioSource(audioUri);
                              await _safePlaySource(source);
                            } else {
                              await _audioPlayer.resume();
                            }
                          }
                        } catch (e) {
                          debugPrint('[ResultsScreen] Audio control error: $e');
                        }
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryPurple,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  // Time labels
                  Text(
                    '${fmtDuration(_audioPosition)} / ${fmtDuration(_audioDuration)}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
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

  // ── Interactive Transcript Playback (Feature 1) ──────────────────────────

  static const Set<String> _commonFillers = {
    'um',
    'uh',
    'like',
    'actually',
    'basically',
    'so',
    'right',
    'literally',
    'well',
    'okay',
    'enna',
    'paa',
    'ah',
    'you know',
    'i mean',
    'kind of',
    'sort of',
  };

  bool _isFillerWord(String rawWord, Map<String, int>? breakdown) {
    final clean = rawWord
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .trim();
    if (clean.isEmpty) return false;
    if (_commonFillers.contains(clean)) return true;
    if (breakdown != null && breakdown.containsKey(clean)) return true;
    return false;
  }

  Future<void> _seekAndPlay(double startSeconds, SessionResult? result) async {
    final offset = result?.audioOffsetSeconds ?? 0.0;
    // Spec: Tapping seeks the audio player to `word.start - 0.3s` (clamped to 0) and plays
    final rawTime = (startSeconds - offset) - 0.3;
    final maxSec = _audioDuration.inMilliseconds > 0
        ? _audioDuration.inMilliseconds / 1000.0
        : (result?.durationSeconds ?? 999.0);
    final clampedSeconds = rawTime.clamp(0.0, maxSec);
    final targetDuration =
        Duration(milliseconds: (clampedSeconds * 1000).round());

    final audioUri = result?.playableAudioUri;
    if (audioUri != null && audioUri.isNotEmpty) {
      try {
        if (_audioDuration == Duration.zero) {
          final source = await _resolveAudioSource(audioUri);
          await _safePlaySource(source, position: targetDuration);
        } else {
          await _audioPlayer.seek(targetDuration);
          if (!_isPlaying) {
            await _audioPlayer.resume();
          }
        }
      } catch (e) {
        debugPrint('[ResultsScreen] Seek audio playback error: $e');
      }
    } else {
      // Local / demo simulation without audio file
      setState(() {
        _audioPosition = targetDuration;
      });
    }
  }

  List<_TranscriptSentence> _parseSentences(
    String transcript,
    List<WordTimestamp> timestamps,
    double durationSeconds,
  ) {
    final List<WordTimestamp> words = timestamps.isNotEmpty
        ? timestamps
        : _synthesizeWordTimestamps(transcript, durationSeconds);

    if (words.isEmpty) return [];

    final List<_TranscriptSentence> sentences = [];
    List<WordTimestamp> currentSentenceWords = [];

    for (int i = 0; i < words.length; i++) {
      final w = words[i];
      currentSentenceWords.add(w);

      final isLast = i == words.length - 1;
      final endsWithPunct = w.word.contains('.') ||
          w.word.contains('?') ||
          w.word.contains('!') ||
          w.word.contains(';');

      if (endsWithPunct || isLast || currentSentenceWords.length >= 20) {
        final start = currentSentenceWords.first.start;
        final end = currentSentenceWords.last.end;
        sentences.add(_TranscriptSentence(
          index: sentences.length,
          startTime: start,
          endTime: end,
          words: List.from(currentSentenceWords),
        ));
        currentSentenceWords.clear();
      }
    }

    return sentences;
  }

  List<WordTimestamp> _synthesizeWordTimestamps(
    String transcript,
    double durationSeconds,
  ) {
    final tokens = transcript
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return [];
    final dur = durationSeconds > 0 ? durationSeconds : (tokens.length * 0.4);
    final wordDur = dur / tokens.length;
    return List.generate(tokens.length, (i) {
      final start = i * wordDur;
      final end = (i + 1) * wordDur;
      return WordTimestamp(word: tokens[i], start: start, end: end);
    });
  }

  Widget _buildInteractiveTranscriptCard(SessionResult? result) {
    final transcript = result?.transcript ?? '';
    final timestamps = result?.wordTimestamps ?? const [];
    final duration = result?.durationSeconds ?? 0.0;
    final offset = result?.audioOffsetSeconds ?? 0.0;
    final breakdown = result?.fillerWordBreakdown;

    final sentences = _parseSentences(transcript, timestamps, duration);
    final currentSec = (_audioPosition.inMilliseconds / 1000.0) + offset;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: AppColors.softShadowOf(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primaryPurple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.subtitles_rounded,
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
                            'Interactive Transcript',
                            style: AppTextStyles.headingMOf(context).copyWith(
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Tap any word or sentence to listen',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (result != null && result.fillerWordCount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warningAmber.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.warningAmber.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: minAxisSize(),
                    children: [
                      const Icon(
                        Icons.flag_rounded,
                        size: 12,
                        color: AppColors.warningAmber,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${result.fillerWordCount} Fillers',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.warningAmber,
                          fontWeight: FontWeight.w700,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Legend
          Row(
            children: [
              _buildLegendDot(AppColors.warningAmber, 'Filler word'),
              const SizedBox(width: 14),
              _buildLegendDot(AppColors.primaryPurple, 'Playing now'),
              const SizedBox(width: 14),
              Text(
                '• Jump -0.3s',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          if (sentences.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No transcript recorded for this session.',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sentences.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, idx) {
                final sentence = sentences[idx];
                final isSentenceActive = _isPlaying &&
                    currentSec >= (sentence.startTime - offset) &&
                    currentSec <= (sentence.endTime - offset + 0.15);

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSentenceActive
                        ? AppColors.primaryPurple.withValues(alpha: 0.08)
                        : Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.03)
                            : const Color(0xFFF9F9FC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSentenceActive
                          ? AppColors.primaryPurple.withValues(alpha: 0.5)
                          : AppColors.borderOf(context),
                      width: isSentenceActive ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sentence Seek / Play Button
                      Semantics(
                        button: true,
                        label: 'Play sentence from ${sentence.startTime.toStringAsFixed(1)} seconds: "${sentence.text}"',
                        child: GestureDetector(
                          onTap: () => _seekAndPlay(sentence.startTime, result),
                          child: Container(
                            width: 26,
                            height: 26,
                            margin: const EdgeInsets.only(top: 2, right: 8),
                            decoration: BoxDecoration(
                              color: isSentenceActive
                                  ? AppColors.primaryPurple
                                  : AppColors.primaryPurple
                                      .withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isSentenceActive && _isPlaying
                                  ? Icons.volume_up_rounded
                                  : Icons.play_arrow_rounded,
                              size: 15,
                              color: isSentenceActive
                                  ? Colors.white
                                  : AppColors.primaryPurple,
                            ),
                          ),
                        ),
                      ),
                      // Sentence Words Wrap
                      Expanded(
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 5,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: sentence.words.map((w) {
                            final isWordActive = _isPlaying &&
                                currentSec >= (w.start - offset) &&
                                currentSec <= (w.end - offset + 0.12);
                            final isFiller = _isFillerWord(w.word, breakdown);

                            return Semantics(
                              button: true,
                              label: isFiller
                                  ? 'Filler word: ${w.word}. Tap to seek audio.'
                                  : 'Word: ${w.word}. Tap to seek audio.',
                              child: InkWell(
                                onTap: () => _seekAndPlay(w.start, result),
                                borderRadius: BorderRadius.circular(5),
                                child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: EdgeInsets.symmetric(
                                  horizontal:
                                      (isWordActive || isFiller) ? 5 : 2,
                                  vertical: (isWordActive || isFiller) ? 2 : 1,
                                ),
                                decoration: BoxDecoration(
                                  color: isWordActive
                                      ? AppColors.primaryPurple
                                      : isFiller
                                          ? AppColors.warningAmber
                                              .withValues(alpha: 0.18)
                                          : Colors.transparent,
                                  borderRadius: BorderRadius.circular(5),
                                  border: isFiller && !isWordActive
                                      ? Border.all(
                                          color: AppColors.warningAmber
                                              .withValues(alpha: 0.45),
                                        )
                                      : null,
                                ),
                                child: Text(
                                  w.word,
                                  style: AppTextStyles.bodyMOf(context)
                                      .copyWith(
                                    fontSize: 13,
                                    height: 1.3,
                                    fontWeight: isWordActive || isFiller
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    color: isWordActive
                                        ? Colors.white
                                        : isFiller
                                            ? AppColors.warningAmber
                                            : AppColors.textPrimaryOf(
                                                context,
                                              ),
                                  ),
                                ),
                              ),
                            ),
                          );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ── Attempt Comparison Section (Feature 2) ─────────────────────────────

  Widget _buildAttemptComparisonSection(SessionResult current) {
    final parent = _parentResult;
    if (parent == null) {
      if (_isLoadingParent) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardOf(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderOf(context)),
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(
                'Loading previous attempt comparison...',
                style: AppTextStyles.captionOf(context),
              ),
            ],
          ),
        );
      }
      return const SizedBox.shrink();
    }

    // Only allow comparison between attempts of the same prompt, question or deck.
    final currentTopic = current.topicOrQuestion.trim().toLowerCase();
    final parentTopic = parent.topicOrQuestion.trim().toLowerCase();
    if (currentTopic != parentTopic) {
      return const SizedBox.shrink();
    }

    return _buildAttemptComparisonDeltaCard(current, parent);
  }

  Widget _buildAttemptComparisonDeltaCard(
    SessionResult current,
    SessionResult parent,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 1. Overall Score Delta
    final scoreDelta = current.overallScore - parent.overallScore;
    final isScoreSame = scoreDelta.abs() < 0.1;
    final isScoreBetter = scoreDelta > 0;
    final scoreDeltaStr = isScoreSame
        ? 'Same'
        : '${scoreDelta > 0 ? '+' : ''}${scoreDelta.toStringAsFixed(1)} pts';
    final scoreDeltaColor = isScoreSame
        ? AppColors.textSecondaryOf(context)
        : (isScoreBetter ? const Color(0xFF10B981) : const Color(0xFFEF4444));

    // 2. Fillers per 100 words (fewer is better)
    final currFillers = current.fillersPer100Words;
    final parentFillers = parent.fillersPer100Words;
    final fillersDelta = currFillers - parentFillers;
    final isFillersBetter = fillersDelta < -0.05;
    final isFillersWorse = fillersDelta > 0.05;
    final fillersDeltaStr = (isFillersBetter || isFillersWorse)
        ? '${fillersDelta > 0 ? '+' : ''}${fillersDelta.toStringAsFixed(1)} /100w'
        : 'Same';
    final fillersDeltaColor = isFillersBetter
        ? const Color(0xFF10B981)
        : (isFillersWorse
            ? const Color(0xFFF59E0B)
            : AppColors.textSecondaryOf(context));

    // 3. WPM relative to the 120-160 optimal band
    final currWpm = current.wpm;
    final parentWpm = parent.wpm;
    final currDist = SessionResult.wpmBandDistance(currWpm);
    final parentDist = SessionResult.wpmBandDistance(parentWpm);

    final bool currInBand = currDist == 0.0;
    final bool parentInBand = parentDist == 0.0;

    String pacingTitle;
    String pacingSub;
    Color pacingColor;

    if (currInBand && parentInBand) {
      pacingTitle = 'In Optimal Band';
      pacingSub = 'Maintained 120–160 WPM pace';
      pacingColor = const Color(0xFF10B981);
    } else if (currInBand && !parentInBand) {
      pacingTitle = 'Reached Optimal Band!';
      pacingSub = '+${parentDist.round()} WPM closer to target';
      pacingColor = const Color(0xFF10B981);
    } else if (!currInBand && currDist < parentDist) {
      final improvement = (parentDist - currDist).round();
      pacingTitle = currWpm < 120
          ? 'Slow (${currWpm.round()} WPM)'
          : 'Fast (${currWpm.round()} WPM)';
      pacingSub = '+$improvement WPM closer to band';
      pacingColor = const Color(0xFF10B981);
    } else if (!currInBand && currDist > parentDist) {
      final regression = (currDist - parentDist).round();
      pacingTitle = currWpm < 120
          ? 'Slow (${currWpm.round()} WPM)'
          : 'Fast (${currWpm.round()} WPM)';
      pacingSub = '-$regression WPM away from band';
      pacingColor = const Color(0xFFF59E0B);
    } else {
      pacingTitle = currWpm < 120
          ? 'Slow (${currWpm.round()} WPM)'
          : 'Fast (${currWpm.round()} WPM)';
      pacingSub = 'Pacing distance unchanged';
      pacingColor = AppColors.textSecondaryOf(context);
    }

    // 4. Pauses count
    final pauseDelta = current.pauseCount - parent.pauseCount;
    final isPauseFewer = pauseDelta < 0;
    final pauseDeltaStr = pauseDelta == 0
        ? 'Same (${current.pauseCount})'
        : '${pauseDelta > 0 ? '+' : ''}$pauseDelta pauses';
    final pauseColor = pauseDelta == 0
        ? AppColors.textSecondaryOf(context)
        : (isPauseFewer ? const Color(0xFF10B981) : const Color(0xFFF59E0B));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primaryPurple.withValues(alpha: isDark ? 0.4 : 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color:
                AppColors.primaryPurple.withValues(alpha: isDark ? 0.15 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.compare_arrows_rounded,
                  color: AppColors.primaryPurple,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attempt Comparison',
                      style: AppTextStyles.headingMOf(context).copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Comparing against your previous run',
                      style: AppTextStyles.captionOf(context),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primaryPurple.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.repeat_rounded,
                      size: 13,
                      color: AppColors.primaryPurple,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Linked Attempt',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryPurple,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // 2x2 Delta Metrics Grid
          Row(
            children: [
              // Overall Score
              Expanded(
                child: _buildAttemptDeltaItem(
                  context,
                  title: 'Overall Score',
                  currentValue: '${current.overallScore.round()}',
                  parentValue: 'was ${parent.overallScore.round()}',
                  deltaBadge: scoreDeltaStr,
                  deltaColor: scoreDeltaColor,
                  icon: Icons.emoji_events_outlined,
                  isPositive: isScoreBetter,
                  isNeutral: isScoreSame,
                ),
              ),
              const SizedBox(width: 12),
              // Fillers per 100 words
              Expanded(
                child: _buildAttemptDeltaItem(
                  context,
                  title: 'Fillers / 100w',
                  currentValue: currFillers.toStringAsFixed(1),
                  parentValue: 'was ${parentFillers.toStringAsFixed(1)}',
                  deltaBadge: fillersDeltaStr,
                  deltaColor: fillersDeltaColor,
                  icon: Icons.chat_bubble_outline_rounded,
                  isPositive: isFillersBetter,
                  isNeutral: !isFillersBetter && !isFillersWorse,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              // Pacing (Relative to 120-160 WPM Band)
              Expanded(
                child: _buildAttemptDeltaItem(
                  context,
                  title: 'Pacing (120–160 Band)',
                  currentValue: '${currWpm.round()} WPM',
                  parentValue: pacingTitle,
                  deltaBadge: pacingSub,
                  deltaColor: pacingColor,
                  icon: Icons.speed_rounded,
                  isPositive: currInBand || currDist < parentDist,
                  isNeutral: currDist == parentDist,
                ),
              ),
              const SizedBox(width: 12),
              // Pauses
              Expanded(
                child: _buildAttemptDeltaItem(
                  context,
                  title: 'Pauses (>1.5s)',
                  currentValue: '${current.pauseCount}',
                  parentValue: 'was ${parent.pauseCount}',
                  deltaBadge: pauseDeltaStr,
                  deltaColor: pauseColor,
                  icon: Icons.pause_circle_outline_rounded,
                  isPositive: isPauseFewer,
                  isNeutral: pauseDelta == 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttemptDeltaItem(
    BuildContext context, {
    required String title,
    required String currentValue,
    required String parentValue,
    required String deltaBadge,
    required Color deltaColor,
    required IconData icon,
    required bool isPositive,
    required bool isNeutral,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : const Color(0xFFF8F9FD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.borderOf(context).withValues(alpha: 0.8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.textSecondaryOf(context)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.captionOf(context).copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                currentValue,
                style: AppTextStyles.headingLOf(context).copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  parentValue,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.captionOf(context).copyWith(
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: deltaColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isNeutral)
                  Icon(
                    isPositive
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: 11,
                    color: deltaColor,
                  ),
                if (!isNeutral) const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    deltaBadge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: deltaColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateStructureCard(SessionResult result) {
    final structureScore = result.structureScore ?? 0.0;
    final detected = result.templateSectionsDetected;
    final missing = result.templateSectionsMissing;
    final templateTitle = result.templateId != null
        ? result.templateId!
            .replaceAll('_', ' ')
            .split(' ')
            .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
            .join(' ')
        : 'Pitch Template';

    return Container(
      key: const Key('template_structure_results_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.primaryPurple.withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: AppColors.softShadowOf(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.architecture_rounded,
                      color: AppColors.primaryPurple,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        templateTitle,
                        style: AppTextStyles.headingMOf(context).copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Structure Rubric Adherence',
                        style: AppTextStyles.captionOf(context).copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (structureScore >= 70
                          ? const Color(0xFF10B981)
                          : const Color(0xFFF59E0B))
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (structureScore >= 70
                            ? const Color(0xFF10B981)
                            : const Color(0xFFF59E0B))
                        .withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  '${structureScore.round()}% Structure',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: structureScore >= 70
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF59E0B),
                  ),
                ),
              ),
            ],
          ),
          if (detected.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Covered Sections (${detected.length})',
              style: AppTextStyles.captionOf(context).copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF10B981),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: detected.map((name) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 13,
                        color: Color(0xFF10B981),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        name,
                        style: AppTextStyles.captionOf(context).copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Missing Sections (${missing.length})',
              style: AppTextStyles.captionOf(context).copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFFF59E0B),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: missing.map((name) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 13,
                        color: Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        name,
                        style: AppTextStyles.captionOf(context).copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  MainAxisSize minAxisSize() => MainAxisSize.min;

  Widget _buildAnimatedSection({
    required Animation<double> animation,
    required Widget child,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final slideY = (1.0 - animation.value) * 16.0;
        return Transform.translate(
          offset: Offset(0, slideY),
          child: Opacity(
            opacity: animation.value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildOverallScoreCard(SessionResult? result) {
    final score = result?.overallScore ?? 0.0;
    final headline = score >= 80
        ? 'Great Job!'
        : score >= 60
        ? 'Good Effort!'
        : 'Keep Practicing!';
    final summary = result != null
        ? '${result.wpm.round()} WPM · ${result.fillerWordCount} fillers · ${result.pauseCount} pauses'
        : 'You spoke clearly and confidently. Keep practicing to get even better.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: AppColors.softShadowOf(context),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Overall Score',
                style: AppTextStyles.bodySmallBold.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Gauge Ring with 0 -> 82% Animation
                  AnimatedBuilder(
                    animation: _scoreGaugeAnimation,
                    builder: (context, child) {
                      return CircularGauge(
                        value: _scoreGaugeAnimation.value,
                        size: 92,
                        strokeWidth: 9,
                        centerBigText: '${_scoreGaugeAnimation.value.round()}%',
                        trackColor:
                            Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF282548)
                            : const Color(0xFFEDEDF5),
                        gradientColors: const [
                          AppColors.primaryPurpleLight,
                          AppColors.primaryPurple,
                        ],
                      );
                    },
                  ),
                  const SizedBox(width: 16),

                  // Text Information
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          headline,
                          style: AppTextStyles.headingM.copyWith(
                            color: score >= 70
                                ? AppColors.successGreen
                                : AppColors.warningAmber,
                            fontWeight: FontWeight.w700,
                            fontSize: 19,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          summary,
                          style: AppTextStyles.bodyM.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (result?.structureScore != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryPurple
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Structure: ${result!.structureScore!.round()}% (Template Rubric)',
                                  style: AppTextStyles.captionOf(context)
                                      .copyWith(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryPurple,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Celebration Vector Icon (Top-Right)
          if (score >= 70)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.successGreen.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const AppIcon(
                  AppIcons.celebration,
                  size: 20,
                  color: AppColors.successGreen,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPerformanceSummary(SessionResult? result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Performance Summary', style: AppTextStyles.headingMOf(context)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildCountUpStatCard(
                label: 'Filler Words',
                targetValue: result?.fillerWordCount ?? 5,
                suffix: '',
                status: (result?.fillerWordCount ?? 5) <= 5
                    ? 'Great'
                    : 'Needs Work',
                delayMs: 0,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCountUpStatCard(
                label: 'Speaking Speed',
                targetValue: result?.wpm.round() ?? 118,
                suffix: ' WPM',
                status: (() {
                  final w = result?.wpm ?? 118;
                  return w >= 120 && w <= 160 ? 'Optimal' : 'Adjust';
                })(),
                delayMs: 100,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildCountUpStatCard(
                label: 'Pauses',
                targetValue: result?.pauseCount ?? 6,
                suffix: '',
                status: 'Good',
                delayMs: 200,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCountUpStatCard(
                label: 'Clarity',
                targetValue: result?.clarityScore.round() ?? 85,
                suffix: '%',
                status: (result?.clarityScore ?? 85) >= 80 ? 'Great' : 'Good',
                delayMs: 300,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCountUpStatCard({
    required String label,
    required int targetValue,
    required String suffix,
    required String status,
    required int delayMs,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderOf(context), width: 1),
        boxShadow: AppColors.softShadowOf(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: targetValue.toDouble()),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, val, child) {
              return Text(
                '${val.round()}$suffix',
                style: AppTextStyles.headingXLOf(
                  context,
                ).copyWith(fontSize: 22, fontWeight: FontWeight.w700),
              );
            },
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.successGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.successGreen,
                fontWeight: FontWeight.w700,
                fontSize: 10.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVocalDeliveryCard(SessionResult? result) {
    final energyData = (result?.energyCurve.isNotEmpty ?? false)
        ? result!.energyCurve
        : [0.35, 0.42, 0.65, 0.78, 0.82, 0.70, 0.55, 0.60, 0.75, 0.88, 0.80, 0.65, 0.45, 0.52, 0.68, 0.75, 0.80, 0.85, 0.72, 0.60, 0.50, 0.58, 0.64, 0.70, 0.78, 0.82, 0.75, 0.60, 0.45, 0.35];

    final pitchScore = result?.pitchVariationScore ?? 65.0;
    final isMonotone = pitchScore < 45.0;
    final isExpressive = pitchScore >= 70.0;
    final volScore = (result?.volumeConsistencyScore ?? 78.0).round();

    final Color badgeColor;
    final String badgeLabel;
    final IconData badgeIcon;

    if (isMonotone) {
      badgeColor = AppColors.warningAmber;
      badgeLabel = 'Monotone Tone';
      badgeIcon = Icons.warning_amber_rounded;
    } else if (isExpressive) {
      badgeColor = AppColors.accentGreen;
      badgeLabel = 'Expressive Pitch';
      badgeIcon = Icons.auto_awesome_rounded;
    } else {
      badgeColor = AppColors.primaryPurple;
      badgeLabel = 'Balanced Pitch';
      badgeIcon = Icons.graphic_eq_rounded;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  const Icon(
                    Icons.graphic_eq_rounded,
                    size: 20,
                    color: AppColors.primaryPurple,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Vocal Delivery & Dynamics',
                      style: AppTextStyles.headingMOf(context),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(badgeIcon, size: 13, color: badgeColor),
                  const SizedBox(width: 4),
                  Text(
                    badgeLabel,
                    style: AppTextStyles.caption.copyWith(
                      color: badgeColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardOf(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderOf(context), width: 1),
            boxShadow: AppColors.softShadowOf(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pitch Variation',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${pitchScore.round()} / 100',
                        style: AppTextStyles.headingMOf(context).copyWith(
                          fontWeight: FontWeight.w700,
                          color: badgeColor,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Volume Stability',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$volScore%',
                        style: AppTextStyles.headingMOf(context).copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Vocal Energy Contour (Timeline)',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 130,
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: (energyData.length - 1).toDouble(),
                    minY: 0,
                    maxY: 1.05,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 0.25,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: AppColors.dividerOf(context).withValues(alpha: 0.5),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          interval: 0.5,
                          getTitlesWidget: (val, meta) {
                            if (val == 0.0) return const SizedBox.shrink();
                            return Text(
                              '${(val * 100).toInt()}%',
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 9,
                                color: AppColors.textSecondary,
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 18,
                          interval: ((energyData.length - 1) / 4.0).clamp(1.0, 30.0),
                          getTitlesWidget: (val, meta) {
                            final pct = ((val / (energyData.length - 1)) * 100).round();
                            return Text(
                              '$pct%',
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 9,
                                color: AppColors.textSecondary,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: List.generate(
                          energyData.length,
                          (i) => FlSpot(i.toDouble(), energyData[i]),
                        ),
                        isCurved: true,
                        curveSmoothness: 0.35,
                        color: AppColors.primaryPurple,
                        barWidth: 2.5,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primaryPurple.withValues(alpha: 0.30),
                              AppColors.primaryPurple.withValues(alpha: 0.02),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
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
      ],
    );
  }

  Widget _buildSessionComparison() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Session Comparison',
              style: AppTextStyles.headingMOf(context),
            ),
            Row(
              children: [
                Text(
                  'This Week',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // fl_chart LineChart Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardOf(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderOf(context), width: 1),
            boxShadow: AppColors.softShadowOf(context),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 160,
                child: AnimatedBuilder(
                  animation: _chartAnimation,
                  builder: (context, child) {
                    final progress = _chartAnimation.value;

                    // Data points: Mon..Sun
                    final youData = [65.0, 72.0, 78.0, 75.0, 80.0, 82.0, 85.0];
                    final lastWeekData = [
                      58.0,
                      62.0,
                      68.0,
                      66.0,
                      70.0,
                      72.0,
                      75.0,
                    ];

                    return LineChart(
                      LineChartData(
                        minY: 0,
                        maxY: 100,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 25,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: AppColors.dividerOf(
                              context,
                            ).withValues(alpha: 0.7),
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
                              getTitlesWidget: (val, meta) {
                                return Text(
                                  '${val.toInt()}',
                                  style: AppTextStyles.caption.copyWith(
                                    fontSize: 10,
                                    color: AppColors.textSecondary,
                                  ),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 1.0,
                              getTitlesWidget: (val, meta) {
                                final rounded = val.round();
                                if ((val - rounded).abs() > 0.01) {
                                  return const SizedBox.shrink();
                                }
                                const days = [
                                  'Mon',
                                  'Tue',
                                  'Wed',
                                  'Thu',
                                  'Fri',
                                  'Sat',
                                  'Sun',
                                ];
                                final idx = rounded;
                                if (idx >= 0 && idx < days.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6.0),
                                    child: Text(
                                      days[idx],
                                      style: AppTextStyles.caption.copyWith(
                                        fontSize: 10,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          // Line 1: "You"
                          LineChartBarData(
                            isCurved: true,
                            curveSmoothness: 0.25,
                            color: AppColors.primaryPurple,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) =>
                                  FlDotCirclePainter(
                                    radius: 4,
                                    color: AppColors.primaryPurple,
                                    strokeWidth: 1.5,
                                    strokeColor: AppColors.cardOf(context),
                                  ),
                            ),
                            spots: List.generate(youData.length, (i) {
                              return FlSpot(
                                i.toDouble(),
                                youData[i] * progress,
                              );
                            }),
                          ),

                          // Line 2: "Last Week" (Dashed Muted Gray)
                          LineChartBarData(
                            isCurved: true,
                            curveSmoothness: 0.25,
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.45,
                            ),
                            barWidth: 2,
                            dashArray: [5, 5],
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) =>
                                  FlDotCirclePainter(
                                    radius: 3,
                                    color: AppColors.textSecondary.withValues(
                                      alpha: 0.6,
                                    ),
                                    strokeWidth: 1,
                                    strokeColor: AppColors.cardOf(context),
                                  ),
                            ),
                            spots: List.generate(lastWeekData.length, (i) {
                              return FlSpot(
                                i.toDouble(),
                                lastWeekData[i] * progress,
                              );
                            }),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // Legend
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegendItem('You', AppColors.primaryPurple),
                  const SizedBox(width: 24),
                  _buildLegendItem(
                    'Last Week',
                    AppColors.textSecondary.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionsSection(SessionResult? result) {
    // Use AI feedback if available, otherwise fall back to static suggestions
    final hasRealFeedback = result != null && result.aiFeedback.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Suggestions', style: AppTextStyles.headingMOf(context)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardOf(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderOf(context), width: 1),
            boxShadow: AppColors.softShadowOf(context),
          ),
          child: Column(
            children: hasRealFeedback
                ? result.aiFeedback.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final item = entry.value;
                    return Column(
                      children: [
                        if (idx > 0) const Divider(height: 1),
                        _buildSuggestionRow(
                          icon: _iconForCategory(item.category),
                          iconColor: _colorForSeverity(item.severity),
                          text: item.example != null
                              ? '${item.message}  "${item.example!}"'
                              : item.message,
                        ),
                      ],
                    );
                  }).toList()
                : [
                    _buildSuggestionRow(
                      icon: Icons.lightbulb_outline_rounded,
                      iconColor: AppColors.warningAmber,
                      text: 'Try reducing filler words like "um", "like".',
                    ),
                    const Divider(height: 1),
                    _buildSuggestionRow(
                      icon: Icons.access_time_rounded,
                      iconColor: AppColors.accentBlue,
                      text: 'Pause a bit more for emphasis.',
                    ),
                    const Divider(height: 1),
                    _buildSuggestionRow(
                      icon: Icons.check_circle_outline_rounded,
                      iconColor: AppColors.successGreen,
                      text: 'Great pace! Maintain consistency.',
                    ),
                  ],
          ),
        ),
      ],
    );
  }

  IconData _iconForCategory(String category) {
    switch (category) {
      case 'filler_words':
        return Icons.record_voice_over_rounded;
      case 'pacing':
        return Icons.speed_rounded;
      case 'structure':
        return Icons.list_alt_rounded;
      case 'confidence':
        return Icons.emoji_emotions_rounded;
      default:
        return Icons.lightbulb_outline_rounded;
    }
  }

  Color _colorForSeverity(String severity) {
    switch (severity) {
      case 'positive':
        return AppColors.successGreen;
      case 'warning':
        return AppColors.warningAmber;
      default:
        return AppColors.accentBlue;
    }
  }

  Widget _buildSuggestionRow({
    required IconData icon,
    required Color iconColor,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyMOf(
                context,
              ).copyWith(fontWeight: FontWeight.w500, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _TranscriptSentence {
  final int index;
  final double startTime;
  final double endTime;
  final List<WordTimestamp> words;

  const _TranscriptSentence({
    required this.index,
    required this.startTime,
    required this.endTime,
    required this.words,
  });

  String get text => words.map((w) => w.word).join(' ');
}
