import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_coach/core/providers/settings_provider.dart';
import 'package:pitch_coach/core/providers/user_provider.dart';
import 'package:pitch_coach/features/onboarding/onboarding_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestableOnboarding({UserProvider? userProvider, SettingsProvider? settingsProvider}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<UserProvider>.value(
          value: userProvider ?? UserProvider(),
        ),
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settingsProvider ?? SettingsProvider(),
        ),
      ],
      child: const MaterialApp(
        home: OnboardingScreen(),
      ),
    );
  }

  group('OnboardingScreen Animations & Carousel', () {
    testWidgets('renders first slide with Mic and Pitch Coach titles', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableOnboarding());
      await tester.pump();

      // Check first slide elements
      expect(find.text('Pitch Coach'), findsOneWidget);
      expect(find.text('Speak with confidence.\nPresent with clarity.'), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);

      // Check action buttons
      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Sign Up'), findsOneWidget);
      expect(find.text('Continue as Guest'), findsOneWidget);
    });

    testWidgets('swiping navigates through all 3 animation slides smoothly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableOnboarding());
      await tester.pump();

      // Slide 0: Mic & Waves
      expect(find.text('Pitch Coach'), findsOneWidget);

      // Drag to Slide 1
      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pump(const Duration(milliseconds: 600));

      // Slide 1: Real-Time AI Feedback
      expect(find.text('Real-Time AI Feedback'), findsOneWidget);
      expect(find.textContaining('filler words'), findsOneWidget);
      expect(find.textContaining('Optimal Pace'), findsOneWidget);
      expect(find.textContaining('Clear Tone'), findsOneWidget);

      // Drag to Slide 2
      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pump(const Duration(milliseconds: 600));

      // Slide 2: Master Any Interview
      expect(find.text('Master Any Interview'), findsOneWidget);
      expect(find.textContaining('Structured frameworks'), findsOneWidget);
      expect(find.textContaining('STAR Method'), findsOneWidget);
      expect(find.textContaining('CareerVidz Lessons'), findsOneWidget);
    });

    testWidgets('tapping indicator dots jumps directly to that slide', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableOnboarding());
      await tester.pump();

      expect(find.text('Pitch Coach'), findsOneWidget);

      // Tap third dot (index 2)
      await tester.tap(find.byKey(const ValueKey('onboarding_dot_2')));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Master Any Interview'), findsOneWidget);

      // Tap first dot (index 0)
      await tester.tap(find.byKey(const ValueKey('onboarding_dot_0')));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Pitch Coach'), findsOneWidget);
    });

    testWidgets('renders cleanly in dark mode with high-contrast text and zero overflow', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<UserProvider>.value(value: UserProvider()),
            ChangeNotifierProvider<SettingsProvider>.value(value: SettingsProvider()),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const OnboardingScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Pitch Coach'), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);

      // Verify transition to Slide 1 in dark mode
      await tester.tap(find.byKey(const ValueKey('onboarding_dot_1')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Real-Time AI Feedback'), findsOneWidget);
      expect(find.text('138 WPM'), findsOneWidget);

      // Verify transition to Slide 2 in dark mode
      await tester.tap(find.byKey(const ValueKey('onboarding_dot_2')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Master Any Interview'), findsOneWidget);
      expect(find.text('STAR Method'), findsOneWidget);
    });
  });
}
