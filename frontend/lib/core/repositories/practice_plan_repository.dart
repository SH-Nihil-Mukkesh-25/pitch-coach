import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/practice_drill.dart';
import '../services/api_client.dart';

/// Repository managing personalized practice plans and targeted drills.
class PracticePlanRepository {
  PracticePlanRepository._();
  static final PracticePlanRepository instance = PracticePlanRepository._();

  PracticePlan? _cachedPlan;
  PracticePlan? get cachedPlan => _cachedPlan;

  static final PracticePlan defaultFallbackPlan = PracticePlan(
    diagnosis: const MetricDiagnosis(
      weakestMetric: 'onboarding',
      avgWpm: 0,
      avgFillersPer100: 0,
      avgPauseCount: 0,
      sessionsAnalyzed: 0,
      scoreTrend: 'insufficient_data',
      diagnosticsSummary: 'Complete your first practice session to generate personalized drills.',
    ),
    drills: const [
      PracticeDrill(
        id: 'drill_default_zero_fillers',
        title: '30 Seconds, Zero Fillers',
        description: "Deliver a crisp introduction for at least 30 seconds without saying 'um', 'like', or 'uh'.",
        targetMetric: 'fillers',
        targetDurationSeconds: 30,
        successCriteria: {'max_filler_count': 0, 'min_duration_seconds': 25.0},
        reason: 'Mastering a clean 30-second start establishes immediate executive presence.',
      ),
      PracticeDrill(
        id: 'drill_default_pacing_metronome',
        title: 'Steady Cadence (120–160 WPM)',
        description: 'Practice speaking at an optimal conversational tempo between 120 and 160 words per minute for 60 seconds.',
        targetMetric: 'wpm',
        targetDurationSeconds: 60,
        successCriteria: {'min_wpm': 120.0, 'max_wpm': 160.0, 'min_duration_seconds': 45.0},
        reason: '120–160 WPM is the golden standard for clear comprehension and listener retention.',
      ),
      PracticeDrill(
        id: 'drill_default_controlled_pauses',
        title: 'Controlled Pauses Mastery',
        description: 'Speak for 45 seconds using deliberate breaths, ensuring no awkward pauses exceed 1.5 seconds.',
        targetMetric: 'pauses',
        targetDurationSeconds: 45,
        successCriteria: {'max_long_pauses': 1, 'min_duration_seconds': 35.0},
        reason: 'Deliberate pauses allow listeners to absorb your core value proposition.',
      ),
    ],
    generatedAt: DateTime.now(),
    isDefaultPlan: true,
  );

  final ValueNotifier<PracticePlan?> planNotifier =
      ValueNotifier<PracticePlan?>(null);

  /// Resets in-memory cached plan (useful for tests and user switches).
  void resetPlan() {
    _cachedPlan = null;
    planNotifier.value = null;
  }

  /// Fetches the latest practice plan from backend or returns cache / fallback.
  Future<PracticePlan> getPracticePlan({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedPlan != null) {
      planNotifier.value = _cachedPlan;
      return _cachedPlan!;
    }

    try {
      final response = await ApiClient.instance.get('/practice-plan');
      if (response != null && response is Map<String, dynamic>) {
        _cachedPlan = PracticePlan.fromJson(response);
        planNotifier.value = _cachedPlan;
        return _cachedPlan!;
      }
    } catch (e) {
      debugPrint('[PracticePlanRepository] Failed to fetch practice plan: $e');
    }

    _cachedPlan ??= defaultFallbackPlan;
    planNotifier.value = _cachedPlan;
    return _cachedPlan!;
  }

  /// Marks a drill as completed on backend and updates in-memory cache.
  Future<bool> completeDrill(
    String drillId, {
    String? sessionId,
    bool syncToBackend = true,
  }) async {
    // 1. Optimistically update local cache and notify listeners immediately
    _cachedPlan ??= defaultFallbackPlan;
    final updatedDrills = _cachedPlan!.drills.map((drill) {
      if (drill.id == drillId) {
        return drill.copyWith(
          isCompleted: true,
          completedAt: DateTime.now(),
        );
      }
      return drill;
    }).toList();

    _cachedPlan = PracticePlan(
      diagnosis: _cachedPlan!.diagnosis,
      drills: updatedDrills,
      generatedAt: _cachedPlan!.generatedAt,
      isDefaultPlan: _cachedPlan!.isDefaultPlan,
    );
    planNotifier.value = _cachedPlan;

    // 2. Persist to backend if requested
    if (syncToBackend) {
      try {
        final payload = <String, dynamic>{'drill_id': drillId};
        if (sessionId != null) {
          payload['session_id'] = sessionId;
        }
        await ApiClient.instance.post(
          '/practice-plan/complete',
          data: payload,
        );
      } catch (e) {
        debugPrint('[PracticePlanRepository] completeDrill background sync notice: $e');
      }
    }
    return true;
  }

  /// Checks if a session result satisfies any active drills and marks them complete.
  Future<List<String>> evaluateSessionAgainstDrills({
    required double durationSeconds,
    required double wpm,
    required int fillerCount,
    required int pauseCount,
    String? sessionId,
  }) async {
    final completedDrillIds = <String>[];
    final plan = _cachedPlan ?? defaultFallbackPlan;

    for (final drill in plan.drills) {
      if (drill.isCompleted) continue;
      final criteria = drill.successCriteria;
      bool passed = true;

      if (criteria.containsKey('min_duration_seconds')) {
        final minDur = (criteria['min_duration_seconds'] as num).toDouble();
        if (durationSeconds < minDur) passed = false;
      }
      if (criteria.containsKey('max_filler_count')) {
        final maxFillers = (criteria['max_filler_count'] as num).toInt();
        if (fillerCount > maxFillers) passed = false;
      }
      if (criteria.containsKey('min_wpm')) {
        final minWpm = (criteria['min_wpm'] as num).toDouble();
        if (wpm < minWpm) passed = false;
      }
      if (criteria.containsKey('max_wpm')) {
        final maxWpm = (criteria['max_wpm'] as num).toDouble();
        if (wpm > maxWpm) passed = false;
      }
      if (criteria.containsKey('max_long_pauses')) {
        final maxPauses = (criteria['max_long_pauses'] as num).toInt();
        if (pauseCount > maxPauses) passed = false;
      }

      if (passed) {
        completedDrillIds.add(drill.id);
        await completeDrill(drill.id, sessionId: sessionId);
      }
    }

    return completedDrillIds;
  }
}
