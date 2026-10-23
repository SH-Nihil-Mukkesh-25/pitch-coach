import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/models/slide_coach_models.dart';
import '../../../core/providers/slide_coach_provider.dart';
import '../../../core/repositories/slide_coach_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/theme_toggle_button.dart';

class DeckReviewScreen extends StatefulWidget {
  const DeckReviewScreen({super.key});

  @override
  State<DeckReviewScreen> createState() => _DeckReviewScreenState();
}

class _DeckReviewScreenState extends State<DeckReviewScreen> {
  final TextEditingController _scriptController = TextEditingController();
  final ScrollController _carouselController = ScrollController();
  int _lastSyncedSlideNumber = -1;

  @override
  void initState() {
    super.initState();
    _scriptController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _scriptController.dispose();
    _carouselController.dispose();
    super.dispose();
  }

  void _syncScriptController(SlideCoachingModel? slide) {
    if (slide != null && slide.slideNumber != _lastSyncedSlideNumber) {
      _lastSyncedSlideNumber = slide.slideNumber;
      _scriptController.text = slide.suggestedScript ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SlideCoachProvider>();
    final deck = provider.deck;
    final currentSlide = provider.currentSlide;
    _syncScriptController(currentSlide);

    if (deck == null) {
      return Scaffold(
        backgroundColor: AppColors.scaffoldOf(context),
        appBar: AppBar(title: const Text('Deck Review')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final summary = deck.deckSummary;

    return Scaffold(
      backgroundColor: AppColors.scaffoldOf(context),
      appBar: AppBar(
        title: Text(deck.filename, style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.mic, color: AppColors.primaryPurple),
            tooltip: 'Start Rehearsal',
            onPressed: () => context.push('/slide-coach/rehearsal'),
          ),
          IconButton(
            icon: const Icon(
              Icons.question_answer_outlined,
              color: AppColors.auroraCyan,
            ),
            tooltip: 'Q&A Prep',
            onPressed: () => context.push('/slide-coach/qa'),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: ThemeToggleButton(size: 38, compact: true),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Deck Summary Header Card ──
            if (summary != null) _buildSummaryHeader(context, summary, deck),

            const SizedBox(height: 18),

            // ── 2. Horizontal Slide Carousel ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Slides (${provider.currentSlideIndex + 1}/${deck.slides.length})',
                    style: AppTextStyles.sectionHeaderOf(context),
                  ),
                  Text(
                    'Total limit: ${deck.timeLimitSeconds}s',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primaryPurple,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _buildSlideCarousel(context, provider, deck),

            const SizedBox(height: 20),

            // ── 3. Current Slide Cue Cards ──
            if (currentSlide != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Slide Headline & Timing Bar
                    _buildSlideHeaderCard(context, currentSlide, provider),

                    const SizedBox(height: 14),

                    // Audience Presentation Intelligence Card
                    _buildSlideIntelCard(context, currentSlide, deck.audience),

                    const SizedBox(height: 14),

                    // Key Takeaway Card
                    _buildKeyTakeawayCard(context, currentSlide),

                    const SizedBox(height: 14),

                    // Talking Points (What to Speak)
                    _buildTalkingPointsCard(
                      context,
                      currentSlide,
                      provider,
                      deck.audience,
                    ),

                    const SizedBox(height: 14),

                    // Suggested Script Accordion (Expandable & Editable)
                    _buildScriptCard(context, currentSlide, provider),

                    const SizedBox(height: 14),

                    // Transition Hook
                    _buildTransitionCard(context, currentSlide),

                    const SizedBox(height: 14),

                    // Visuals & Slide Critique
                    _buildCritiqueCard(context, currentSlide),
                  ],
                ),
              ),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardOf(context),
          boxShadow: AppColors.softShadowOf(context),
          border: Border(top: BorderSide(color: AppColors.borderOf(context))),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push('/slide-coach/qa'),
                icon: const Icon(Icons.help_outline, size: 18),
                label: const Text('Q&A Prep'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryPurple,
                  side: const BorderSide(color: AppColors.primaryPurple),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/slide-coach/rehearsal'),
                icon: const Icon(Icons.play_circle_fill, size: 20),
                label: const Text('Rehearse Presentation'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getAudienceLabel(String? audience) {
    final aud = (audience ?? 'investors').toLowerCase();
    if (aud.contains('judge') || aud.contains('hackathon')) {
      return 'Hackathon Judges';
    } else if (aud.contains('class') || aud.contains('academic')) {
      return 'Class / Academic';
    } else if (aud.contains('client') || aud.contains('customer')) {
      return 'Potential Clients';
    } else if (aud.contains('other') || aud.contains('general')) {
      return 'General Audience';
    }
    return 'Investors / VCs';
  }

  Widget _buildSummaryHeader(
    BuildContext context,
    DeckSummaryModel summary,
    SlideDeckModel deck,
  ) {
    final pillars = summary.getPillars(deck.audience);
    final audienceName = _getAudienceLabel(deck.audience);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: AppColors.softShadowOf(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Score: ${summary.overallScore}/100',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.auto_stories,
                color: AppColors.primaryPurple,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text('Story Arc', style: AppTextStyles.bodyBoldOf(context)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.psychology_outlined,
                  size: 14,
                  color: AppColors.primaryPurple,
                ),
                const SizedBox(width: 4),
                Text(
                  'Evaluated for: $audienceName',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryPurple,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(summary.storyArc, style: AppTextStyles.bodyTextOf(context)),
          const SizedBox(height: 12),
          Text(
            'Core Narrative Pillars:',
            style: AppTextStyles.captionOf(
              context,
            ).copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (int i = 0; i < pillars.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                _buildPillarBadge(
                  context,
                  pillars[i].label,
                  pillars[i].isPresent,
                  pillars[i].icon,
                ),
              ],
            ],
          ),
          if (summary.storyArcWarnings.isNotEmpty) ...[
            for (final warn in summary.storyArcWarnings) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.dangerRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.dangerRed.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.dangerRed,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        warn,
                        style: AppTextStyles.captionOf(context).copyWith(
                          color: AppColors.dangerRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ] else if (!summary.hasAsk &&
              (deck.audience.toLowerCase().contains('invest') ||
                  deck.audience.isEmpty)) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: AppColors.dangerRed.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.dangerRed.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.dangerRed,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Missing Ask Slide: Decks must close with a clear call-to-action or funding ask.',
                      style: AppTextStyles.captionOf(context).copyWith(
                        color: AppColors.dangerRed,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (summary.missingSections.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Missing Pitch Elements:',
              style: AppTextStyles.captionOf(
                context,
              ).copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: summary.missingSections
                  .map(
                    (sec) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.dangerRed.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.dangerRed.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        sec,
                        style: const TextStyle(
                          color: AppColors.dangerRed,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (summary.top3Fixes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Top 3 Fixes:',
              style: AppTextStyles.captionOf(
                context,
              ).copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            ...summary.top3Fixes.map(
              (fix) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '• ',
                      style: TextStyle(
                        color: AppColors.primaryPurple,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        fix,
                        style: AppTextStyles.bodyTextOf(
                          context,
                        ).copyWith(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSlideCarousel(
    BuildContext context,
    SlideCoachProvider provider,
    SlideDeckModel deck,
  ) {
    return SizedBox(
      height: 130,
      child: ListView.builder(
        controller: _carouselController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: deck.slides.length,
        itemBuilder: (context, i) {
          final s = deck.slides[i];
          final isSelected = i == provider.currentSlideIndex;
          final imgUrl = SlideCoachRepository.instance.getSlideImageUrl(
            deck.id,
            s.slideNumber,
          );

          return GestureDetector(
            onTap: () => provider.selectSlide(i),
            child: Container(
              width: 170,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primaryPurple
                      : AppColors.borderOf(context),
                  width: isSelected ? 2.5 : 1,
                ),
                color: AppColors.cardOf(context),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      imgUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.black12,
                        child: Center(child: Text('Slide ${s.slideNumber}')),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        color: Colors.black.withValues(alpha: 0.65),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Slide ${s.slideNumber}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${s.targetDurationSeconds}s',
                              style: const TextStyle(
                                color: AppColors.auroraCyan,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSlideHeaderCard(
    BuildContext context,
    SlideCoachingModel slide,
    SlideCoachProvider provider,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Slide ${slide.slideNumber}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primaryPurple,
                  ),
                ),
                Text(
                  slide.slideTitle,
                  style: AppTextStyles.bodyBoldOf(context),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.timer_outlined,
                  size: 16,
                  color: AppColors.primaryPurple,
                ),
                const SizedBox(width: 4),
                Text(
                  '${slide.targetDurationSeconds}s target',
                  style: const TextStyle(
                    color: AppColors.primaryPurple,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyTakeawayCard(BuildContext context, SlideCoachingModel slide) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lightbulb_outline,
            color: AppColors.warningAmber,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Key Audience Takeaway',
                  style: AppTextStyles.captionOf(
                    context,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  slide.keyTakeaway,
                  style: AppTextStyles.bodyTextOf(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlideIntelCard(
    BuildContext context,
    SlideCoachingModel slide,
    String audience,
  ) {
    final audienceName = _getAudienceLabel(audience);
    final hasTip =
        slide.audienceTip != null && slide.audienceTip!.trim().isNotEmpty;
    final hasEmphasize =
        slide.whatToEmphasize != null &&
        slide.whatToEmphasize!.trim().isNotEmpty;
    final hasAvoid =
        slide.whatToAvoid != null && slide.whatToAvoid!.trim().isNotEmpty;
    final hasPacing =
        slide.deliveryPacing != null && slide.deliveryPacing!.trim().isNotEmpty;

    if (!hasTip && !hasEmphasize && !hasAvoid && !hasPacing) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryPurple.withValues(alpha: 0.3),
        ),
        boxShadow: AppColors.softShadowOf(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.psychology_outlined,
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
                      'Audience Intelligence ($audienceName)',
                      style: AppTextStyles.bodyBoldOf(context),
                    ),
                    Text(
                      'How to position Slide ${slide.slideNumber} for maximum impact',
                      style: AppTextStyles.captionOf(
                        context,
                      ).copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasTip) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.primaryPurple.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.tips_and_updates_outlined,
                    color: AppColors.primaryPurple,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      slide.audienceTip!,
                      style: AppTextStyles.bodyTextOf(context).copyWith(
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (hasEmphasize || hasAvoid) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasEmphasize)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.successGreen.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.successGreen.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.check_circle_outline,
                                color: AppColors.successGreen,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Emphasize',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.successGreen,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            slide.whatToEmphasize!,
                            style: AppTextStyles.bodyTextOf(context).copyWith(
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (hasEmphasize && hasAvoid) const SizedBox(width: 8),
                if (hasAvoid)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.warningAmber.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.warningAmber.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.block_outlined,
                                color: AppColors.warningAmber,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Avoid',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.warningAmber,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            slide.whatToAvoid!,
                            style: AppTextStyles.bodyTextOf(context).copyWith(
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (hasPacing) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.speed_outlined,
                  size: 15,
                  color: AppColors.auroraCyan,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Pacing: ${slide.deliveryPacing}',
                    style: AppTextStyles.captionOf(context).copyWith(
                      color: AppColors.auroraCyan,
                      fontWeight: FontWeight.w600,
                      fontSize: 11.5,
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

  Widget _buildTalkingPointsCard(
    BuildContext context,
    SlideCoachingModel slide,
    SlideCoachProvider provider,
    String audience,
  ) {
    final audienceName = _getAudienceLabel(audience);
    return Container(
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
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.speaker_notes_outlined,
                  color: AppColors.primaryPurple,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Talking Points (What to Speak)',
                      style: AppTextStyles.bodyBoldOf(context),
                    ),
                    Text(
                      'Targeted for $audienceName · ${slide.targetDurationSeconds}s target',
                      style: AppTextStyles.captionOf(context).copyWith(
                        color: AppColors.primaryPurple,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18),
                tooltip: 'Copy all talking points',
                color: AppColors.textSecondaryOf(context),
                onPressed: () {
                  final text = slide.talkingPoints
                      .asMap()
                      .entries
                      .map((e) => '${e.key + 1}. ${e.value}')
                      .join('\n');
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Talking points copied to clipboard'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.successGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.successGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Auto-saved',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.successGreen,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Deliver these speech cues to highlight key details without reading verbatim:',
            style: AppTextStyles.captionOf(context).copyWith(
              color: AppColors.textSecondaryOf(context),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          ...slide.talkingPoints.asMap().entries.map((entry) {
            final idx = entry.key;
            final pt = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.scaffoldOf(context).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.borderOf(context).withValues(alpha: 0.6),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${idx + 1}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryPurple,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      key: ValueKey('tp_${slide.slideNumber}_$idx'),
                      initialValue: pt,
                      minLines: 1,
                      maxLines: 5,
                      keyboardType: TextInputType.multiline,
                      style: AppTextStyles.bodyTextOf(context).copyWith(
                        fontSize: 13.5,
                        height: 1.4,
                        color: AppColors.textPrimaryOf(context),
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 2),
                        border: InputBorder.none,
                        hintText: 'Actionable point to speak...',
                        hintStyle: TextStyle(
                          color: AppColors.textSecondaryOf(
                            context,
                          ).withValues(alpha: 0.5),
                        ),
                      ),
                      onChanged: (newVal) {
                        final updated = List<String>.from(slide.talkingPoints);
                        updated[idx] = newVal;
                        provider.updateCurrentSlideTalkingPoints(updated);
                      },
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      final updated = List<String>.from(slide.talkingPoints)
                        ..removeAt(idx);
                      provider.updateCurrentSlideTalkingPoints(updated);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: AppColors.textSecondaryOf(
                          context,
                        ).withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: () {
              final updated = List<String>.from(slide.talkingPoints)..add('');
              provider.updateCurrentSlideTalkingPoints(updated);
            },
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text(
              'Add Talking Point',
              style: TextStyle(fontSize: 12),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryPurple,
              side: BorderSide(
                color: AppColors.primaryPurple.withValues(alpha: 0.4),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScriptCard(
    BuildContext context,
    SlideCoachingModel slide,
    SlideCoachProvider provider,
  ) {
    final scriptText = _scriptController.text.trim();
    final words =
        scriptText.isEmpty ? 0 : scriptText.split(RegExp(r'\s+')).length;
    final estimatedSeconds = (words / 2.3).round(); // ~140 words/min
    final isOverTarget =
        estimatedSeconds > (slide.targetDurationSeconds * 1.25);

    return ExpansionTile(
      collapsedBackgroundColor: AppColors.cardOf(context),
      backgroundColor: AppColors.cardOf(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.borderOf(context)),
      ),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.borderOf(context)),
      ),
      leading: const Icon(
        Icons.record_voice_over,
        color: AppColors.primaryPurple,
        size: 20,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              'Word-for-Word Pitch Script',
              style: AppTextStyles.bodyBoldOf(context),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 16),
            tooltip: 'Copy script',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _scriptController.text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Script copied to clipboard'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      subtitle: Row(
        children: [
          Text(
            '$words words (~${estimatedSeconds}s spoken)',
            style: AppTextStyles.captionOf(context).copyWith(
              fontSize: 11,
              color: isOverTarget
                  ? AppColors.warningAmber
                  : AppColors.primaryPurple,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (isOverTarget) ...[
            const SizedBox(width: 4),
            const Text(
              '· May exceed target',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.warningAmber,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
      childrenPadding: const EdgeInsets.all(14),
      children: [
        TextField(
          controller: _scriptController,
          maxLines: 6,
          style: AppTextStyles.bodyTextOf(context).copyWith(
            fontSize: 14,
            height: 1.45,
            color: AppColors.textPrimaryOf(context),
          ),
          decoration: InputDecoration(
            hintText: 'Suggested word-for-word spoken speech...',
            hintStyle: TextStyle(
              color: AppColors.textSecondaryOf(context).withValues(alpha: 0.6),
            ),
            filled: true,
            fillColor: AppColors.scaffoldOf(context),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.borderOf(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.borderOf(context)),
            ),
          ),
          onChanged: (newScript) =>
              provider.updateCurrentSlideScript(newScript),
        ),
      ],
    );
  }

  Widget _buildTransitionCard(BuildContext context, SlideCoachingModel slide) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.compare_arrows,
            color: AppColors.auroraCyan,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Slide Transition Hook',
                      style: AppTextStyles.captionOf(
                        context,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(text: slide.transitionToNext),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Transition copied to clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.copy_rounded,
                          size: 14,
                          color: AppColors.auroraCyan,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '"${slide.transitionToNext}"',
                  style: AppTextStyles.bodyTextOf(
                    context,
                  ).copyWith(fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCritiqueCard(BuildContext context, SlideCoachingModel slide) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.analytics_outlined,
                color: AppColors.primaryPurple,
                size: 20,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Visual Layout & Critique',
                  style: AppTextStyles.bodyBoldOf(context),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Hierarchy: ${slide.visualHierarchyRating.toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryPurple,
                  ),
                ),
              ),
            ],
          ),
          if (slide.textDensity != null) ...[
            const SizedBox(height: 8),
            Text(
              'Density: ${slide.textDensity}',
              style: AppTextStyles.captionOf(context),
            ),
          ],
          if (slide.tooMuchText || slide.weakTitle || slide.missingCta) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (slide.tooMuchText)
                  _buildCritiqueChip(
                    context,
                    Icons.text_fields_rounded,
                    'Too Much Text',
                    AppColors.dangerRed,
                  ),
                if (slide.weakTitle)
                  _buildCritiqueChip(
                    context,
                    Icons.title_rounded,
                    'Weak Title',
                    AppColors.warningAmber,
                  ),
                if (slide.missingCta)
                  _buildCritiqueChip(
                    context,
                    Icons.flag_outlined,
                    'Missing CTA',
                    AppColors.warningAmber,
                  ),
              ],
            ),
          ],
          if (slide.visuals != null && slide.visuals!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Visuals Detected: ${slide.visuals}',
              style: AppTextStyles.bodyTextOf(context).copyWith(fontSize: 12),
            ),
          ],
          if (slide.designCritique.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...slide.designCritique.map(
              (crit) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.format_paint_outlined,
                      size: 14,
                      color: AppColors.primaryPurple,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        crit,
                        style: AppTextStyles.captionOf(context).copyWith(
                          color: AppColors.textPrimaryOf(context),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (slide.slideCritique.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...slide.slideCritique.map(
              (crit) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '• $crit',
                  style: AppTextStyles.captionOf(
                    context,
                  ).copyWith(color: AppColors.warningAmber, fontSize: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPillarBadge(
    BuildContext context,
    String label,
    bool covered, [
    IconData? categoryIcon,
  ]) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: covered
              ? AppColors.successGreen.withValues(alpha: 0.12)
              : AppColors.dangerRed.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: covered
                ? AppColors.successGreen.withValues(alpha: 0.4)
                : AppColors.dangerRed.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (categoryIcon != null) ...[
                  Icon(
                    categoryIcon,
                    size: 13,
                    color: covered
                        ? AppColors.successGreen
                        : AppColors.dangerRed,
                  ),
                  const SizedBox(width: 3),
                ],
                Icon(
                  covered ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: covered ? AppColors.successGreen : AppColors.dangerRed,
                  size: 13,
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: covered ? AppColors.successGreen : AppColors.dangerRed,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCritiqueChip(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
