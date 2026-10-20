import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_coach/core/models/lesson_model.dart';
import 'package:pitch_coach/core/providers/settings_provider.dart';
import 'package:pitch_coach/features/learn/lessons_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('LessonsScreen with initialCategory', () {
    testWidgets('defaults to All when no category specified', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final settings = SettingsProvider();
      await settings.initialize();

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: const MaterialApp(
            home: LessonsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Learn'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Reduce Filler Words'), findsOneWidget);
      expect(find.text('Presentation Body Language'), findsOneWidget);
    });

    testWidgets('filters to Speaking when initialCategory is Speaking',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final settings = SettingsProvider();
      await settings.initialize();

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: const MaterialApp(
            home: LessonsScreen(initialCategory: 'Speaking'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Speaking'), findsAtLeastNWidgets(1));
      expect(find.text('Reduce Filler Words'), findsOneWidget);
      expect(find.text('Control Your Speaking Pace'), findsOneWidget);
      expect(find.text('Presentation Body Language'), findsNothing);
    });

    testWidgets(
        'filters to Presentation when initialCategory is Presentation',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final settings = SettingsProvider();
      await settings.initialize();

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: const MaterialApp(
            home: LessonsScreen(initialCategory: 'Presentation'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Presentation Body Language'), findsOneWidget);
      expect(find.text('Reduce Filler Words'), findsNothing);
    });

    testWidgets('filters to Interview when initialCategory is Interview',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final settings = SettingsProvider();
      await settings.initialize();

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: const MaterialApp(
            home: LessonsScreen(initialCategory: 'Interview'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Tell Me About Yourself'), findsOneWidget);
      expect(find.text('Reduce Filler Words'), findsNothing);
    });

    testWidgets('filters by difficulty level chip', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final settings = SettingsProvider();
      await settings.initialize();

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: const MaterialApp(
            home: LessonsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 'Intermediate' level filter chip
      await tester.tap(find.text('Intermediate'));
      await tester.pumpAndSettle();

      // Intermediate lessons should be visible
      expect(find.text('The STAR Method for Behavioral Questions'), findsOneWidget);
      // Beginner lessons should not be visible
      expect(find.text('Answer "Tell Me About Yourself"'), findsNothing);

      // Tap 'Advanced' level filter chip (inside horizontal scrollable)
      await tester.ensureVisible(find.text('Advanced'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Advanced'));
      await tester.pumpAndSettle();

      expect(find.text('Executive Presence in Case Interviews'), findsOneWidget);
      expect(find.text('The STAR Method for Behavioral Questions'), findsNothing);

      // Tap 'All Levels' to clear difficulty filter
      await tester.ensureVisible(find.text('All Levels'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All Levels'));
      await tester.pumpAndSettle();

      expect(find.text('Answer "Tell Me About Yourself"'), findsOneWidget);
    });
  });

  group('LessonCatalog validation', () {
    test('contains 27 total lessons (9 per category: 3 beginner, 3 intermediate, 3 advanced)', () {
      expect(LessonCatalog.all.length, 27);

      for (final cat in ['interview', 'presentation', 'speaking']) {
        final catLessons = LessonCatalog.byCategory(cat);
        expect(catLessons.length, 9, reason: 'Expected 9 lessons for $cat');

        final beginner = catLessons.where((l) => l.level == 'beginner').toList();
        final intermediate = catLessons.where((l) => l.level == 'intermediate').toList();
        final advanced = catLessons.where((l) => l.level == 'advanced').toList();

        expect(beginner.length, 3, reason: 'Expected 3 beginner lessons for $cat');
        expect(intermediate.length, 3, reason: 'Expected 3 intermediate lessons for $cat');
        expect(advanced.length, 3, reason: 'Expected 3 advanced lessons for $cat');
      }
    });

    test('every lesson has valid videoUrl and metadata', () {
      final ids = <String>{};
      for (final lesson in LessonCatalog.all) {
        expect(ids.add(lesson.id), isTrue, reason: 'Duplicate id: ${lesson.id}');
        expect(lesson.title.isNotEmpty, isTrue);
        expect(lesson.description.isNotEmpty, isTrue);
        expect(lesson.duration.isNotEmpty, isTrue);
        expect(lesson.takeaways.isNotEmpty, isTrue);
        expect(lesson.weakAreaTag.isNotEmpty, isTrue);
        expect(lesson.videoUrl.startsWith('https://'), isTrue);
        expect(lesson.videoUrl.contains('youtube.com/watch?v='), isTrue);
        expect(lesson.youtubeVideoId.isNotEmpty, isTrue);
        expect(lesson.thumbnailUrl.startsWith('https://img.youtube.com/vi/'), isTrue);
        expect(['beginner', 'intermediate', 'advanced'].contains(lesson.level), isTrue);
      }
    });
  });
}
