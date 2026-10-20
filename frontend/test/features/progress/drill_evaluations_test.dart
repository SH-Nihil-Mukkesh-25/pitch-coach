import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_coach/core/providers/practice_plan_provider.dart';
import 'package:pitch_coach/core/repositories/practice_plan_repository.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Progress Screen - Targeted Drills & Evaluations Stored', () {
    testWidgets('Displays empty state when no drills are completed yet', (tester) async {
      PracticePlanRepository.instance.resetPlan();
      final provider = PracticePlanProvider();
      await provider.loadPlan(isGuest: true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider.value(
              value: provider,
              child: Builder(
                builder: (context) {
                  final planProvider = context.watch<PracticePlanProvider>();
                  final plan = planProvider.plan!;
                  final completedDrills = planProvider.completedDrills;
                  return Column(
                    children: [
                      Text('Targeted Drills & Evaluations'),
                      Text('${completedDrills.length}/${plan.drills.length} Completed'),
                      if (completedDrills.isEmpty)
                        const Text('No Completed Drills Stored Yet')
                      else
                        ...completedDrills.map((d) => Text('Stored: ${d.title}')),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Targeted Drills & Evaluations'), findsOneWidget);
      expect(find.text('0/3 Completed'), findsOneWidget);
      expect(find.text('No Completed Drills Stored Yet'), findsOneWidget);

      provider.dispose();
    });

    testWidgets('Stores and displays evaluated completed drills in Progress', (tester) async {
      PracticePlanRepository.instance.resetPlan();
      final provider = PracticePlanProvider();
      await provider.loadPlan(isGuest: true);

      // Complete 2 drills
      await provider.completeDrill('drill_default_zero_fillers', syncToBackend: false);
      await provider.completeDrill('drill_default_pacing_metronome', syncToBackend: false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider.value(
              value: provider,
              child: Builder(
                builder: (context) {
                  final planProvider = context.watch<PracticePlanProvider>();
                  final plan = planProvider.plan!;
                  final completedDrills = planProvider.completedDrills;
                  return Column(
                    children: [
                      Text('Targeted Drills & Evaluations'),
                      Text('${completedDrills.length}/${plan.drills.length} Completed'),
                      ...completedDrills.map((d) => Column(
                            key: ValueKey(d.id),
                            children: [
                              Text('Evaluated: ${d.title}'),
                              Text('Coach Note: ${d.reason}'),
                            ],
                          )),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Targeted Drills & Evaluations'), findsOneWidget);
      expect(find.text('2/3 Completed'), findsOneWidget);
      expect(find.text('Evaluated: 30 Seconds, Zero Fillers'), findsOneWidget);
      expect(find.text('Evaluated: Steady Cadence (120–160 WPM)'), findsOneWidget);

      provider.dispose();
    });
  });
}
