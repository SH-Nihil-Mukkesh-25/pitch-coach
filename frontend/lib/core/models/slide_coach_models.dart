// Typed Dart models for the Slide Coach feature.
import 'package:flutter/material.dart';

class NarrativePillarDisplay {
  final String label;
  final bool isPresent;
  final IconData icon;
  const NarrativePillarDisplay(this.label, this.isPresent, this.icon);
}

class DeckSummaryModel {
  final String storyArc;
  final List<String> missingSections;
  final int overallScore;
  final List<String> top3Fixes;
  final bool hasProblem;
  final bool hasSolution;
  final bool hasTraction;
  final bool hasAsk;
  final List<String> missingPillars;
  final List<String> storyArcWarnings;
  final String? audience;

  const DeckSummaryModel({
    required this.storyArc,
    required this.missingSections,
    required this.overallScore,
    required this.top3Fixes,
    this.hasProblem = false,
    this.hasSolution = false,
    this.hasTraction = false,
    this.hasAsk = false,
    this.missingPillars = const [],
    this.storyArcWarnings = const [],
    this.audience,
  });

  List<NarrativePillarDisplay> getPillars(String? fallbackAudience) {
    final aud = (audience ?? fallbackAudience ?? 'investors').toLowerCase();
    if (aud.contains('judge') || aud.contains('hackathon')) {
      return [
        NarrativePillarDisplay('Problem', hasProblem, Icons.report_problem_outlined),
        NarrativePillarDisplay('Architecture', hasSolution, Icons.account_tree_outlined),
        NarrativePillarDisplay('Prototype', hasTraction, Icons.precision_manufacturing_outlined),
        NarrativePillarDisplay('Roadmap', hasAsk, Icons.alt_route_outlined),
      ];
    } else if (aud.contains('class') || aud.contains('academic')) {
      return [
        NarrativePillarDisplay('Context', hasProblem, Icons.menu_book_outlined),
        NarrativePillarDisplay('Methodology', hasSolution, Icons.biotech_outlined),
        NarrativePillarDisplay('Results', hasTraction, Icons.bar_chart_outlined),
        NarrativePillarDisplay('Conclusion', hasAsk, Icons.fact_check_outlined),
      ];
    } else if (aud.contains('client') || aud.contains('customer')) {
      return [
        NarrativePillarDisplay('Pain Point', hasProblem, Icons.sentiment_dissatisfied_outlined),
        NarrativePillarDisplay('Value Prop', hasSolution, Icons.verified_outlined),
        NarrativePillarDisplay('Proof', hasTraction, Icons.shield_outlined),
        NarrativePillarDisplay('Next Steps', hasAsk, Icons.touch_app_outlined),
      ];
    } else if (aud.contains('other') || aud.contains('general')) {
      return [
        NarrativePillarDisplay('Hook', hasProblem, Icons.wb_incandescent_outlined),
        NarrativePillarDisplay('Core Story', hasSolution, Icons.auto_stories_outlined),
        NarrativePillarDisplay('Impact', hasTraction, Icons.public_outlined),
        NarrativePillarDisplay('Takeaway', hasAsk, Icons.flag_outlined),
      ];
    } else {
      return [
        NarrativePillarDisplay('Problem', hasProblem, Icons.error_outline),
        NarrativePillarDisplay('Solution', hasSolution, Icons.lightbulb_outline),
        NarrativePillarDisplay('Traction', hasTraction, Icons.trending_up),
        NarrativePillarDisplay('Ask', hasAsk, Icons.handshake_outlined),
      ];
    }
  }

  factory DeckSummaryModel.fromJson(Map<String, dynamic> json) {
    return DeckSummaryModel(
      storyArc: json['story_arc'] as String? ?? '',
      missingSections:
          (json['missing_sections'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      overallScore: (json['overall_score'] as num?)?.toInt() ?? 0,
      top3Fixes:
          (json['top_3_fixes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      hasProblem: json['has_problem'] as bool? ?? false,
      hasSolution: json['has_solution'] as bool? ?? false,
      hasTraction: json['has_traction'] as bool? ?? false,
      hasAsk: json['has_ask'] as bool? ?? false,
      missingPillars:
          (json['missing_pillars'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      storyArcWarnings:
          (json['story_arc_warnings'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      audience: json['audience'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'story_arc': storyArc,
    'missing_sections': missingSections,
    'overall_score': overallScore,
    'top_3_fixes': top3Fixes,
    'has_problem': hasProblem,
    'has_solution': hasSolution,
    'has_traction': hasTraction,
    'has_ask': hasAsk,
    'missing_pillars': missingPillars,
    'story_arc_warnings': storyArcWarnings,
    'audience': audience,
  };
}

class SlideCoachingModel {
  final int slideNumber;
  String slideTitle;
  int targetDurationSeconds;
  final String keyTakeaway;
  List<String> talkingPoints;
  String? suggestedScript;
  final String transitionToNext;
  final List<String> slideCritique;
  final String? imageUrl;
  final String? visuals;
  final String? textDensity;
  final List<String> readabilityIssues;
  final bool tooMuchText;
  final bool weakTitle;
  final bool missingCta;
  final String visualHierarchyRating;
  final List<String> designCritique;
  final String? audienceTip;
  final String? whatToEmphasize;
  final String? whatToAvoid;
  final String? deliveryPacing;

  SlideCoachingModel({
    required this.slideNumber,
    required this.slideTitle,
    required this.targetDurationSeconds,
    required this.keyTakeaway,
    required this.talkingPoints,
    this.suggestedScript,
    required this.transitionToNext,
    required this.slideCritique,
    this.imageUrl,
    this.visuals,
    this.textDensity,
    required this.readabilityIssues,
    this.tooMuchText = false,
    this.weakTitle = false,
    this.missingCta = false,
    this.visualHierarchyRating = 'good',
    this.designCritique = const [],
    this.audienceTip,
    this.whatToEmphasize,
    this.whatToAvoid,
    this.deliveryPacing,
  });

  factory SlideCoachingModel.fromJson(Map<String, dynamic> json) {
    return SlideCoachingModel(
      slideNumber: (json['slide_number'] as num?)?.toInt() ?? 1,
      slideTitle: json['slide_title'] as String? ?? 'Slide',
      targetDurationSeconds:
          (json['target_duration_seconds'] as num?)?.toInt() ?? 30,
      keyTakeaway: json['key_takeaway'] as String? ?? '',
      talkingPoints:
          (json['talking_points'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      suggestedScript: json['suggested_script'] as String?,
      transitionToNext: json['transition_to_next'] as String? ?? '',
      slideCritique:
          (json['slide_critique'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      imageUrl: json['image_url'] as String?,
      visuals: json['visuals'] as String?,
      textDensity: json['text_density'] as String?,
      readabilityIssues:
          (json['readability_issues'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      tooMuchText: json['too_much_text'] as bool? ?? false,
      weakTitle: json['weak_title'] as bool? ?? false,
      missingCta: json['missing_cta'] as bool? ?? false,
      visualHierarchyRating:
          json['visual_hierarchy_rating'] as String? ?? 'good',
      designCritique:
          (json['design_critique'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      audienceTip: json['audience_tip'] as String?,
      whatToEmphasize: json['what_to_emphasize'] as String?,
      whatToAvoid: json['what_to_avoid'] as String?,
      deliveryPacing: json['delivery_pacing'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'slide_number': slideNumber,
    'slide_title': slideTitle,
    'target_duration_seconds': targetDurationSeconds,
    'key_takeaway': keyTakeaway,
    'talking_points': talkingPoints,
    'suggested_script': suggestedScript,
    'transition_to_next': transitionToNext,
    'slide_critique': slideCritique,
    'image_url': imageUrl,
    'visuals': visuals,
    'text_density': textDensity,
    'readability_issues': readabilityIssues,
    'too_much_text': tooMuchText,
    'weak_title': weakTitle,
    'missing_cta': missingCta,
    'visual_hierarchy_rating': visualHierarchyRating,
    'design_critique': designCritique,
    'audience_tip': audienceTip,
    'what_to_emphasize': whatToEmphasize,
    'what_to_avoid': whatToAvoid,
    'delivery_pacing': deliveryPacing,
  };
}

class SlideDeckModel {
  final String id;
  final String filename;
  final String audience;
  final int timeLimitSeconds;
  final String goal;
  final String status; // processing | done | failed
  final String stage; // rendering | reading_slides | writing_coaching
  final int progress;
  final int pageCount;
  final DeckSummaryModel? deckSummary;
  final List<SlideCoachingModel> slides;
  final String createdAt;
  final String updatedAt;

  const SlideDeckModel({
    required this.id,
    required this.filename,
    required this.audience,
    required this.timeLimitSeconds,
    required this.goal,
    required this.status,
    required this.stage,
    required this.progress,
    required this.pageCount,
    this.deckSummary,
    required this.slides,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SlideDeckModel.fromJson(Map<String, dynamic> json) {
    return SlideDeckModel(
      id: json['id'] as String? ?? '',
      filename: json['filename'] as String? ?? 'deck.pdf',
      audience: json['audience'] as String? ?? 'investors',
      timeLimitSeconds: (json['time_limit_seconds'] as num?)?.toInt() ?? 180,
      goal: json['goal'] as String? ?? '',
      status: json['status'] as String? ?? 'processing',
      stage: json['stage'] as String? ?? 'rendering',
      progress: (json['progress'] as num?)?.toInt() ?? 0,
      pageCount: (json['page_count'] as num?)?.toInt() ?? 0,
      deckSummary: json['deck_summary'] != null
          ? DeckSummaryModel.fromJson(
              json['deck_summary'] as Map<String, dynamic>,
            )
          : null,
      slides:
          (json['slides'] as List<dynamic>?)
              ?.map(
                (e) => SlideCoachingModel.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'filename': filename,
    'audience': audience,
    'time_limit_seconds': timeLimitSeconds,
    'goal': goal,
    'status': status,
    'stage': stage,
    'progress': progress,
    'page_count': pageCount,
    'deck_summary': deckSummary?.toJson(),
    'slides': slides.map((s) => s.toJson()).toList(),
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  String get fileName => filename;
  int get targetTotalDurationSeconds => timeLimitSeconds;

  DateTime? get createdDateTime => DateTime.tryParse(createdAt)?.toLocal();

  String get dateFormatted {
    final d = createdDateTime;
    if (d == null) return '';
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
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }

  String get timeFormatted {
    final d = createdDateTime;
    if (d == null) return '';
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class SlideDeckStatusModel {
  final String deckId;
  final String status; // processing | done | failed
  final String stage; // rendering | reading_slides | writing_coaching
  final int progress;
  final String? error;

  const SlideDeckStatusModel({
    required this.deckId,
    required this.status,
    required this.stage,
    required this.progress,
    this.error,
  });

  bool get isProcessing => status == 'processing';

  factory SlideDeckStatusModel.fromJson(Map<String, dynamic> json) {
    return SlideDeckStatusModel(
      deckId: json['deck_id'] as String? ?? '',
      status: json['status'] as String? ?? 'processing',
      stage: json['stage'] as String? ?? 'rendering',
      progress: (json['progress'] as num?)?.toInt() ?? 0,
      error: json['error'] as String?,
    );
  }

  String get stageLabel {
    switch (stage) {
      case 'rendering':
        return 'Rendering slides';
      case 'reading_slides':
        return 'Scanning slide visuals';
      case 'writing_coaching':
        return 'Synthesizing speech & timing';
      default:
        return 'Analyzing presentation';
    }
  }
}

// ── Rehearsal Models ──────────────────────────────────────────────────────────

class SlideTalkingPointCoverageModel {
  final String point;
  final bool covered;
  final String? evidence;

  const SlideTalkingPointCoverageModel({
    required this.point,
    required this.covered,
    this.evidence,
  });

  factory SlideTalkingPointCoverageModel.fromJson(Map<String, dynamic> json) {
    return SlideTalkingPointCoverageModel(
      point: json['point'] as String? ?? '',
      covered: json['covered'] as bool? ?? false,
      evidence: json['evidence'] as String?,
    );
  }
}

class SlideRehearsalReportModel {
  final int slideNumber;
  final String slideTitle;
  final int targetDurationSeconds;
  final double actualDurationSeconds;
  final double wpm;
  final int fillerCount;
  final Map<String, int> fillerBreakdown;
  final String transcript;
  final List<SlideTalkingPointCoverageModel> talkingPointsCoverage;
  final double coveragePercentage;
  final List<Map<String, dynamic>> aiFeedback;

  const SlideRehearsalReportModel({
    required this.slideNumber,
    required this.slideTitle,
    required this.targetDurationSeconds,
    required this.actualDurationSeconds,
    required this.wpm,
    required this.fillerCount,
    required this.fillerBreakdown,
    required this.transcript,
    required this.talkingPointsCoverage,
    required this.coveragePercentage,
    required this.aiFeedback,
  });

  factory SlideRehearsalReportModel.fromJson(Map<String, dynamic> json) {
    return SlideRehearsalReportModel(
      slideNumber: (json['slide_number'] as num?)?.toInt() ?? 1,
      slideTitle: json['slide_title'] as String? ?? '',
      targetDurationSeconds:
          (json['target_duration_seconds'] as num?)?.toInt() ?? 30,
      actualDurationSeconds:
          (json['actual_duration_seconds'] as num?)?.toDouble() ?? 0.0,
      wpm: (json['wpm'] as num?)?.toDouble() ?? 0.0,
      fillerCount: (json['filler_count'] as num?)?.toInt() ?? 0,
      fillerBreakdown:
          (json['filler_breakdown'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toInt()),
          ) ??
          {},
      transcript: json['transcript'] as String? ?? '',
      talkingPointsCoverage:
          (json['talking_points_coverage'] as List<dynamic>?)
              ?.map(
                (e) => SlideTalkingPointCoverageModel.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList() ??
          [],
      coveragePercentage:
          (json['coverage_percentage'] as num?)?.toDouble() ?? 0.0,
      aiFeedback:
          (json['ai_feedback'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
    );
  }
}

class DeckRehearsalResponseModel {
  final String rehearsalId;
  final String deckId;
  final double totalDurationSeconds;
  final int timeLimitSeconds;
  final double overallWpm;
  final int overallFillerCount;
  final double overallCoveragePercentage;
  final List<String> overallFeedback;
  final List<SlideRehearsalReportModel> slideReports;
  final String createdAt;

  const DeckRehearsalResponseModel({
    required this.rehearsalId,
    required this.deckId,
    required this.totalDurationSeconds,
    required this.timeLimitSeconds,
    required this.overallWpm,
    required this.overallFillerCount,
    required this.overallCoveragePercentage,
    required this.overallFeedback,
    required this.slideReports,
    required this.createdAt,
  });

  factory DeckRehearsalResponseModel.fromJson(Map<String, dynamic> json) {
    return DeckRehearsalResponseModel(
      rehearsalId: json['rehearsal_id'] as String? ?? '',
      deckId: json['deck_id'] as String? ?? '',
      totalDurationSeconds:
          (json['total_duration_seconds'] as num?)?.toDouble() ?? 0.0,
      timeLimitSeconds: (json['time_limit_seconds'] as num?)?.toInt() ?? 180,
      overallWpm: (json['overall_wpm'] as num?)?.toDouble() ?? 0.0,
      overallFillerCount: (json['overall_filler_count'] as num?)?.toInt() ?? 0,
      overallCoveragePercentage:
          (json['overall_coverage_percentage'] as num?)?.toDouble() ?? 0.0,
      overallFeedback:
          (json['overall_feedback'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      slideReports:
          (json['slide_reports'] as List<dynamic>?)
              ?.map(
                (e) => SlideRehearsalReportModel.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList() ??
          [],
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

// ── Q&A Models ────────────────────────────────────────────────────────────────

class QaQuestionModel {
  final String id;
  final String question;
  final String whyTheyAsk;
  final int? targetedSlideNumber;

  const QaQuestionModel({
    required this.id,
    required this.question,
    required this.whyTheyAsk,
    this.targetedSlideNumber,
  });

  factory QaQuestionModel.fromJson(Map<String, dynamic> json) {
    return QaQuestionModel(
      id: json['id'] as String? ?? '',
      question: json['question'] as String? ?? '',
      whyTheyAsk: json['why_they_ask'] as String? ?? '',
      targetedSlideNumber: (json['targeted_slide_number'] as num?)?.toInt(),
    );
  }
}

class QaEvaluationModel {
  final String questionId;
  final String question;
  final String spokenTranscript;
  final int clarityScore;
  final int directnessScore;
  final int evidenceScore;
  final int confidenceScore;
  final int overallScore;
  final String critique;
  final String sampleBetterAnswer;

  const QaEvaluationModel({
    required this.questionId,
    required this.question,
    required this.spokenTranscript,
    required this.clarityScore,
    required this.directnessScore,
    required this.evidenceScore,
    required this.confidenceScore,
    required this.overallScore,
    required this.critique,
    required this.sampleBetterAnswer,
  });

  factory QaEvaluationModel.fromJson(Map<String, dynamic> json) {
    return QaEvaluationModel(
      questionId: json['question_id'] as String? ?? '',
      question: json['question'] as String? ?? '',
      spokenTranscript: json['spoken_transcript'] as String? ?? '',
      clarityScore: (json['clarity_score'] as num?)?.toInt() ?? 0,
      directnessScore: (json['directness_score'] as num?)?.toInt() ?? 0,
      evidenceScore: (json['evidence_score'] as num?)?.toInt() ?? 0,
      confidenceScore: (json['confidence_score'] as num?)?.toInt() ?? 0,
      overallScore: (json['overall_score'] as num?)?.toInt() ?? 0,
      critique: json['critique'] as String? ?? '',
      sampleBetterAnswer: json['sample_better_answer'] as String? ?? '',
    );
  }
}
