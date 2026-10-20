import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_coach/core/models/practice_drill.dart';
import 'package:pitch_coach/core/providers/practice_plan_provider.dart';
import 'package:pitch_coach/core/repositories/practice_plan_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Practice Plan Models', () {
    test('PracticeDrill deserialization and copyWith', () {
      final json = {
        'id': 'drill_zero_fillers',
        'title': '30s Zero Fillers',
        'description': 'Deliver speech without fillers.',
        'target_metric': 'fillers',
        'target_duration_seconds': 30,
        'success_criteria': {'max_filler_count': 0, 'min_duration_seconds': 25.0},
        'is_completed': false,
        'reason': 'High filler words detected in early speech.',
      };

      final drill = PracticeDrill.fromJson(json);
      expect(drill.id, 'drill_zero_fillers');
      expect(drill.title, '30s Zero Fillers');
      expect(drill.targetMetric, 'fillers');
      expect(drill.targetDurationSeconds, 30);
      expect(drill.isCompleted, isFalse);

      final completed = drill.copyWith(isCompleted: true);
      expect(completed.isCompleted, isTrue);
      expect(completed.title, drill.title);
    });

    test('MetricDiagnosis deserialization', () {
      final json = {
        'weakest_metric': 'wpm',
        'avg_wpm': 98.5,
        'avg_fillers_per_100': 1.2,
        'avg_pause_count': 2.0,
        'sessions_analyzed': 4,
        'score_trend': 'improving',
        'diagnostics_summary': 'Pacing is slightly below the 120-160 optimal band.',
      };

      final diag = MetricDiagnosis.fromJson(json);
      expect(diag.weakestMetric, 'wpm');
      expect(diag.avgWpm, 98.5);
      expect(diag.sessionsAnalyzed, 4);
      expect(diag.scoreTrend, 'improving');
    });

    test('PracticePlan full JSON round-trip', () {
      final plan = PracticePlanRepository.defaultFallbackPlan;
      final json = plan.toJson();
      final parsed = PracticePlan.fromJson(json);

      expect(parsed.isDefaultPlan, isTrue);
      expect(parsed.drills.length, 3);
      expect(parsed.drills.first.id, 'drill_default_zero_fillers');
    });
  });

  group('PracticePlanRepository Criteria Evaluation', () {
    test('evaluateSessionAgainstDrills passes when criteria are met', () async {
      final repo = PracticePlanRepository.instance;
      // Default plan has drill_default_zero_fillers with max_filler_count = 0, min_duration = 25
      // Evaluate matching session: 30s, 130 WPM, 0 fillers, 1 pause
      final completed = await repo.evaluateSessionAgainstDrills(
        durationSeconds: 30.0,
        wpm: 130.0,
        fillerCount: 0,
        pauseCount: 1,
        sessionId: 'test-sess-1',
      );

      expect(completed.contains('drill_default_zero_fillers'), isTrue);
    });

    test('evaluateSessionAgainstDrills fails when criteria are violated', () async {
      final repo = PracticePlanRepository.instance;
      // Evaluate non-matching session: 10s (too short), 5 fillers
      final completed = await repo.evaluateSessionAgainstDrills(
        durationSeconds: 10.0,
        wpm: 130.0,
        fillerCount: 5,
        pauseCount: 4,
        sessionId: 'test-sess-2',
      );

      expect(completed.contains('drill_default_zero_fillers'), isFalse);
    });
  });

  group('Practice Drill UI Widgets', () {
    testWidgets('Drill card displays title, duration, and Start Drill button', (tester) async {
      const drill = PracticeDrill(
        id: 'test_drill',
        title: '30 Seconds, Zero Fillers',
        description: 'Deliver clean introduction without fillers.',
        targetMetric: 'fillers',
        targetDurationSeconds: 30,
        successCriteria: {'max_filler_count': 0},
        reason: 'Mastering start presence.',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Column(
                  children: [
                    Text(drill.title),
                    Text('${drill.targetDurationSeconds}s'),
                    Text('Why: ${drill.reason}'),
                    ElevatedButton(
                      onPressed: () {},
                      child: const Text('Start Drill'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('30 Seconds, Zero Fillers'), findsOneWidget);
      expect(find.text('30s'), findsOneWidget);
      expect(find.text('Why: Mastering start presence.'), findsOneWidget);
      expect(find.text('Start Drill'), findsOneWidget);
    });
  });

  group('PracticePlanProvider & Dropdown Disappearance', () {
    test('PracticePlanProvider manages pending and completed drills', () async {
      PracticePlanRepository.instance.resetPlan();
      final provider = PracticePlanProvider();
      await provider.loadPlan(isGuest: true);

      expect(provider.allDrills.length, 3);
      expect(provider.pendingDrills.length, 3);
      expect(provider.completedDrills.length, 0);
      expect(provider.allCompleted, isFalse);
      expect(provider.isCollapsed, isFalse);

      // Toggle dropdown
      provider.toggleCollapsed();
      expect(provider.isCollapsed, isTrue);
      provider.toggleCollapsed();
      expect(provider.isCollapsed, isFalse);

      // Complete 1st drill
      final firstId = provider.pendingDrills.first.id;
      await provider.completeDrill(firstId, syncToBackend: false);

      expect(provider.pendingDrills.length, 2);
      expect(provider.completedDrills.length, 1);
      expect(provider.completedDrills.first.id, firstId);
      expect(provider.hasPendingDrills, isTrue);
      expect(provider.allCompleted, isFalse);

      // Complete 2nd and 3rd drills
      for (final drill in List.of(provider.pendingDrills)) {
        await provider.completeDrill(drill.id, syncToBackend: false);
      }

      expect(provider.pendingDrills.length, 0);
      expect(provider.completedDrills.length, 3);
      expect(provider.hasPendingDrills, isFalse);
      expect(provider.allCompleted, isTrue);

      provider.dispose();
    });

    testWidgets('Dropdown collapses and expands, and completed drill disappears', (tester) async {
      PracticePlanRepository.instance.resetPlan();
      final provider = PracticePlanProvider();
      await provider.loadPlan(isGuest: true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: provider,
              builder: (context, _) {
                if (!provider.hasPendingDrills) {
                  return const Text('All Drills Completed - Section Disappeared');
                }

                return Column(
                  children: [
                    InkWell(
                      onTap: () => provider.toggleCollapsed(),
                      child: Text('Targeted Drills (${provider.pendingDrills.length} left)'),
                    ),
                    if (!provider.isCollapsed)
                      ...provider.pendingDrills.map((drill) => Row(
                            key: ValueKey(drill.id),
                            children: [
                              Expanded(child: Text(drill.title)),
                              ElevatedButton(
                                onPressed: () => provider.completeDrill(drill.id, syncToBackend: false),
                                child: Text('Complete ${drill.id}'),
                              ),
                            ],
                          )),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // Initially expanded
      expect(find.text('Targeted Drills (3 left)'), findsOneWidget);
      expect(find.text('30 Seconds, Zero Fillers'), findsOneWidget);

      // Collapse dropdown
      await tester.tap(find.text('Targeted Drills (3 left)'));
      await tester.pumpAndSettle();
      expect(provider.isCollapsed, isTrue);
      expect(find.text('30 Seconds, Zero Fillers'), findsNothing);

      // Re-expand dropdown
      await tester.tap(find.text('Targeted Drills (3 left)'));
      await tester.pumpAndSettle();
      expect(provider.isCollapsed, isFalse);
      expect(find.text('30 Seconds, Zero Fillers'), findsOneWidget);

      // Complete 1st drill -> that specific drill disappears!
      await tester.tap(find.text('Complete drill_default_zero_fillers'));
      await tester.pumpAndSettle();

      expect(find.text('Targeted Drills (2 left)'), findsOneWidget);
      expect(find.text('30 Seconds, Zero Fillers'), findsNothing);
      expect(find.text('Steady Cadence (120–160 WPM)'), findsOneWidget);

      // Complete remaining drills -> entire section disappears!
      await tester.tap(find.text('Complete drill_default_pacing_metronome'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Complete drill_default_controlled_pauses'));
      await tester.pumpAndSettle();

      expect(find.text('All Drills Completed - Section Disappeared'), findsOneWidget);
      expect(find.text('Targeted Drills (0 left)'), findsNothing);

      provider.dispose();
    });
  });
}

