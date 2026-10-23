import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_coach/core/models/slide_coach_models.dart';
import 'package:pitch_coach/core/providers/settings_provider.dart';
import 'package:pitch_coach/core/providers/slide_coach_provider.dart';
import 'package:pitch_coach/features/slide_coach/screens/deck_review_screen.dart';
import 'package:provider/provider.dart';

void main() {
  group('Feature 8: Slide Coach Upgrades Models', () {
    test('DeckSummaryModel parses story-arc pillars and flags missing Ask', () {
      final json = {
        'story_arc': 'Strong problem and solution, but no closing ask.',
        'missing_sections': ['Ask'],
        'overall_score': 74,
        'top_3_fixes': ['Add a clear investment ask'],
        'has_problem': true,
        'has_solution': true,
        'has_traction': true,
        'has_ask': false,
        'missing_pillars': ['Ask'],
        'story_arc_warnings': [
          'Missing Ask Slide: Decks must close with a clear call-to-action or funding ask.'
        ],
      };

      final summary = DeckSummaryModel.fromJson(json);
      expect(summary.hasProblem, isTrue);
      expect(summary.hasSolution, isTrue);
      expect(summary.hasTraction, isTrue);
      expect(summary.hasAsk, isFalse);
      expect(summary.missingPillars, contains('Ask'));
      expect(summary.storyArcWarnings.first, contains('Missing Ask Slide'));

      final serialized = summary.toJson();
      expect(serialized['has_ask'], isFalse);
      expect(serialized['has_problem'], isTrue);
    });

    test('SlideCoachingModel parses design critique and visual hierarchy', () {
      final json = {
        'slide_number': 1,
        'slide_title': 'Overview',
        'target_duration_seconds': 30,
        'key_takeaway': 'Introductory slide',
        'talking_points': ['Welcome everyone'],
        'transition_to_next': 'Move to problem',
        'slide_critique': ['Reduce bullets'],
        'readability_issues': [],
        'too_much_text': true,
        'weak_title': true,
        'missing_cta': true,
        'visual_hierarchy_rating': 'poor',
        'design_critique': [
          'Title Overview lacks punch',
          'Exceeds 6 bullet lines without hierarchy',
        ],
      };

      final slide = SlideCoachingModel.fromJson(json);
      expect(slide.tooMuchText, isTrue);
      expect(slide.weakTitle, isTrue);
      expect(slide.missingCta, isTrue);
      expect(slide.visualHierarchyRating, 'poor');
      expect(slide.designCritique.length, 2);

      final serialized = slide.toJson();
      expect(serialized['too_much_text'], isTrue);
      expect(serialized['visual_hierarchy_rating'], 'poor');
    });
  });

  group('Feature 8: DeckReviewScreen UI Integration', () {
    testWidgets('Renders story-arc pillars, missing Ask warning, and design critique chips', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final mockDeck = SlideDeckModel(
        id: 'test-deck-8',
        filename: 'my_startup_pitch.pptx',
        audience: 'investors',
        timeLimitSeconds: 180,
        goal: 'Seed funding',
        status: 'done',
        stage: 'ready',
        progress: 100,
        pageCount: 1,
        deckSummary: const DeckSummaryModel(
          storyArc: 'Promising technology seeking partner validation.',
          missingSections: ['Ask'],
          overallScore: 78,
          top3Fixes: ['Include call-to-action ask'],
          hasProblem: true,
          hasSolution: true,
          hasTraction: true,
          hasAsk: false,
          missingPillars: ['Ask'],
          storyArcWarnings: [
            'Missing Ask Slide: Decks must close with a clear call-to-action or funding ask.'
          ],
        ),
        slides: [
          SlideCoachingModel(
            slideNumber: 1,
            slideTitle: 'Autonomous Logistics',
            targetDurationSeconds: 45,
            keyTakeaway: 'Drones eliminate last-mile delays',
            talkingPoints: ['Highlight flight speed', 'Fleet economics'],
            transitionToNext: 'Now let us review pilot data',
            slideCritique: ['Clean visual graph'],
            readabilityIssues: const [],
            tooMuchText: true,
            weakTitle: false,
            missingCta: true,
            visualHierarchyRating: 'fair',
            designCritique: const ['Increase contrast on footer caption'],
          ),
        ],
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );

      final provider = SlideCoachProvider();
      provider.setDeckForTesting(mockDeck);
      final settingsProvider = SettingsProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SlideCoachProvider>.value(value: provider),
            ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
          ],
          child: const MaterialApp(
            home: DeckReviewScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify Core Narrative Pillars
      expect(find.text('Core Narrative Pillars:'), findsOneWidget);
      expect(find.text('Problem'), findsOneWidget);
      expect(find.text('Solution'), findsOneWidget);
      expect(find.text('Traction'), findsOneWidget);
      expect(find.text('Ask'), findsWidgets); // In pillars and missing pitch elements

      // 2. Verify Missing Ask Warning Alert
      expect(
        find.textContaining('Missing Ask Slide: Decks must close with a clear call-to-action'),
        findsOneWidget,
      );

      // 3. Verify Design Critique Chips and Visual Hierarchy
      expect(find.text('Too Much Text'), findsOneWidget);
      expect(find.text('Missing CTA'), findsOneWidget);
      expect(find.text('Hierarchy: FAIR'), findsOneWidget);
      expect(find.text('Increase contrast on footer caption'), findsOneWidget);
    });

    testWidgets('Adapts presentation for Hackathon Judges audience with speech-ready talking points and audience intel', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final hackathonDeck = SlideDeckModel(
        id: 'hackathon-stm32-deck',
        filename: 'STM32F411CEU6_DataVault.pdf',
        audience: 'hackathon_judges',
        timeLimitSeconds: 180,
        goal: 'Win hackathon grand finale & convince judges',
        status: 'done',
        stage: 'ready',
        progress: 100,
        pageCount: 5,
        deckSummary: const DeckSummaryModel(
          storyArc: 'Technical walkthrough of bare-metal storage architecture with real-time FAT32 benchmarks.',
          missingSections: [],
          overallScore: 88,
          top3Fixes: ['Highlight live demo failover test'],
          hasProblem: true,
          hasSolution: true,
          hasTraction: true,
          hasAsk: true,
          missingPillars: [],
          storyArcWarnings: [],
          audience: 'hackathon_judges',
        ),
        slides: [
          SlideCoachingModel(
            slideNumber: 1,
            slideTitle: 'DataVault System Architecture',
            targetDurationSeconds: 38,
            keyTakeaway: 'Decoupled ESP8266 and STM32 architecture delivers zero HAL latency',
            talkingPoints: [
              'Direct judges to the dual-bus block diagram showing UART-to-SPI bridging',
              'Explain why bare-metal registers were chosen over standard HAL drivers to conserve SRAM',
            ],
            transitionToNext: 'Now let us step through the UART handshake sequence',
            slideCritique: ['Clear bus routing visualization'],
            readabilityIssues: const [],
            audienceTip: 'Judges will test whether the ESP8266 bottleneck was benchmarked under concurrent HTTP loads.',
            whatToEmphasize: 'Point directly to the 115,200 baud UART bridge and RAM isolation',
            whatToAvoid: 'Do not dive into trivial pin configurations; focus on throughput',
            deliveryPacing: 'Brisk, confident technical delivery (38s)',
          ),
        ],
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );

      final provider = SlideCoachProvider();
      provider.setDeckForTesting(hackathonDeck);
      final settingsProvider = SettingsProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SlideCoachProvider>.value(value: provider),
            ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
          ],
          child: const MaterialApp(
            home: DeckReviewScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify Audience evaluation badge & Hackathon Pillars
      expect(find.text('Evaluated for: Hackathon Judges'), findsOneWidget);
      expect(find.text('Architecture'), findsOneWidget);
      expect(find.text('Prototype'), findsOneWidget);
      expect(find.text('Roadmap'), findsOneWidget);

      // 2. Verify No False "Missing Ask Slide" for Hackathon Judges
      expect(
        find.textContaining('Missing Ask Slide'),
        findsNothing,
      );

      // 3. Verify Audience Presentation Intelligence
      expect(find.text('Audience Intelligence (Hackathon Judges)'), findsOneWidget);
      expect(find.textContaining('Judges will test whether the ESP8266 bottleneck'), findsOneWidget);
      expect(find.text('Emphasize'), findsOneWidget);
      expect(find.textContaining('Point directly to the 115,200 baud UART bridge'), findsOneWidget);
      expect(find.text('Avoid'), findsOneWidget);
      expect(find.textContaining('Do not dive into trivial pin configurations'), findsOneWidget);
      expect(find.textContaining('Pacing: Brisk, confident technical delivery'), findsOneWidget);

      // 4. Verify Talking Points (What to Speak)
      expect(find.text('Talking Points (What to Speak)'), findsOneWidget);
      expect(find.textContaining('Direct judges to the dual-bus block diagram'), findsOneWidget);
      expect(find.textContaining('Explain why bare-metal registers were chosen'), findsOneWidget);
      expect(find.text('Add Talking Point'), findsOneWidget);
    });
  });
}
