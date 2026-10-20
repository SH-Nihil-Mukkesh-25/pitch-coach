import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_coach/core/models/lesson_model.dart';
import 'package:pitch_coach/core/providers/settings_provider.dart';
import 'package:pitch_coach/features/learn/lesson_practice_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('LessonPracticeScreen', () {
    final testLesson = LessonCatalog.all.first;

    testWidgets('renders dedicated coach prompt and recording workspace', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final settings = SettingsProvider();
      await settings.initialize();

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: MaterialApp(
            home: LessonPracticeScreen(lesson: testLesson),
          ),
        ),
      );
      await tester.pump();

      // Verify AI Practice Coach AppBar
      expect(find.text('AI Practice Coach'), findsOneWidget);

      // Verify Lesson title and prompt
      expect(find.text(testLesson.title), findsOneWidget);
      expect(find.text('COACHING PROMPT'), findsOneWidget);
      expect(find.text(testLesson.practiceExercise), findsOneWidget);

      // Verify Initial Recording Workspace
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.text('Tap microphone to start practicing'), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
    });

    testWidgets('recording, evaluating, and showing AI video recommendation', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final settings = SettingsProvider();
      await settings.initialize();

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: MaterialApp(
            home: LessonPracticeScreen(lesson: testLesson),
          ),
        ),
      );
      await tester.pump();

      // Tap to start recording
      await tester.tap(find.byIcon(Icons.mic_rounded));
      await tester.pump(const Duration(seconds: 2));

      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      expect(find.text('Tap square to finish & analyze'), findsOneWidget);

      // Tap stop & analyze
      await tester.tap(find.byIcon(Icons.stop_rounded));
      await tester.pump();

      // Should be in evaluating state
      expect(find.text('Analyzing Your Practice...'), findsOneWidget);

      // Fast forward past the 1600ms AI evaluation delay
      await tester.pump(const Duration(milliseconds: 1700));
      await tester.pumpAndSettle();

      // Verify Evaluation Results & AI Coach Video Feedback
      expect(find.text('Practice Evaluated!'), findsOneWidget);
      expect(find.text('AI COACH VIDEO FEEDBACK'), findsOneWidget);
      expect(find.text('Watch this part again to improve yourself'), findsOneWidget);
      expect(
        find.text('Target Segment: ${testLesson.keyVideoTimestamp} – ${testLesson.keyVideoTimestampEnd}'),
        findsOneWidget,
      );
      expect(find.text(testLesson.keyVideoTimestampTip), findsOneWidget);
    });
  });
}
