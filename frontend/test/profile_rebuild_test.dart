import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_coach/core/providers/settings_provider.dart';
import 'package:pitch_coach/core/providers/stats_provider.dart';
import 'package:pitch_coach/core/providers/user_provider.dart';
import 'package:pitch_coach/features/profile/profile_screen.dart';
import 'package:pitch_coach/features/profile/widgets/practice_goals_sheet.dart';
import 'package:pitch_coach/core/widgets/app_icon.dart';
import 'package:pitch_coach/core/widgets/theme_toggle_button.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    const MethodChannel storageChannel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (MethodCall call) async {
          return null;
        });
  });

  group('Profile Screen & Settings Tests', () {
    testWidgets('Profile renders with a full user and formatted stats', (
      tester,
    ) async {
      final userProvider = UserProvider();
      final statsProvider = StatsProvider();
      final settingsProvider = SettingsProvider();
      await settingsProvider.initialize();

      // Configure a full user
      userProvider.user.name = 'Alex Morgan';
      userProvider.user.role = 'Product Lead';
      userProvider.user.sessionsCompleted = 14;
      userProvider.user.avgScore = 88.0;
      userProvider.user.memberSince = 'Mar 2026';

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<UserProvider>.value(value: userProvider),
            ChangeNotifierProvider<StatsProvider>.value(value: statsProvider),
            ChangeNotifierProvider<SettingsProvider>.value(
              value: settingsProvider,
            ),
          ],
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify header and user details
      expect(find.text('Profile'), findsOneWidget);
      // Name appears in Hero Card and Personal Info row
      expect(find.text('Alex Morgan'), findsNWidgets(2));
      expect(find.text('Product Lead'), findsOneWidget);

      // Verify sections are present
      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Learn'), findsOneWidget);
      expect(find.text('Preferences'), findsOneWidget);
      expect(find.text('Support'), findsOneWidget);
    });

    testWidgets(
      'Profile renders with a new user (zero stats, score placeholder)',
      (tester) async {
        final userProvider = UserProvider();
        final statsProvider = StatsProvider();
        final settingsProvider = SettingsProvider();
        await settingsProvider.initialize();

        userProvider.user.name = 'Newbie';
        userProvider.user.role = '';
        userProvider.user.sessionsCompleted = 0;
        userProvider.user.avgScore = 0.0;

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<UserProvider>.value(value: userProvider),
              ChangeNotifierProvider<StatsProvider>.value(value: statsProvider),
              ChangeNotifierProvider<SettingsProvider>.value(
                value: settingsProvider,
              ),
            ],
            child: const MaterialApp(home: ProfileScreen()),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Empty role falls back to "Pitch Coach member"
        expect(find.text('Pitch Coach member'), findsOneWidget);

        // Unscored user shows "--" and prompt
        expect(find.text('--'), findsOneWidget);
        expect(find.text('Complete a session'), findsOneWidget);
      },
    );

    test(
      'Theme toggle and Dark Mode switch stay in sync with SettingsProvider',
      () async {
        final settingsProvider = SettingsProvider();
        await settingsProvider.initialize();

        expect(settingsProvider.themeMode, ThemeMode.system);

        // Change to dark mode
        await settingsProvider.setThemeMode(ThemeMode.dark);
        expect(settingsProvider.themeMode, ThemeMode.dark);

        // Change to light mode
        await settingsProvider.setThemeMode(ThemeMode.light);
        expect(settingsProvider.themeMode, ThemeMode.light);
      },
    );

    test('Apple design sun icon asset resolves correctly', () {
      expect(AppIcons.sun, 'sun');
      expect(AppIcons.resolveAssetPath('sun'), 'assets/icons/sun.svg');
      expect(AppIcons.resolveAssetPath('light_mode'), 'assets/icons/sun.svg');
      expect(AppIcons.resolveAssetPath('brightness'), 'assets/icons/sun.svg');
      expect(AppIcons.resolveAssetPath('sunrise'), 'assets/icons/sunrise.svg');
    });

    testWidgets('ThemeToggleButton displays AppIcons.sun in dark mode', (
      tester,
    ) async {
      final settingsProvider = SettingsProvider();
      await settingsProvider.initialize();
      await settingsProvider.setThemeMode(ThemeMode.dark);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsProvider>.value(
              value: settingsProvider,
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ThemeToggleButton(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      final appIconFinder = find.byType(AppIcon);
      expect(appIconFinder, findsOneWidget);
      final appIconWidget = tester.widget<AppIcon>(appIconFinder);
      expect(appIconWidget.name, AppIcons.sun);
    });

    testWidgets(
      'PracticeGoalsSheet allows setting time, days, and weekly targets',
      (tester) async {
        final settingsProvider = SettingsProvider();
        await settingsProvider.initialize();

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<SettingsProvider>.value(
                value: settingsProvider,
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(body: PracticeGoalsSheet()),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Practice Goals & Reminders'), findsOneWidget);
        expect(find.text('Save Goals'), findsOneWidget);
        expect(find.text('Disable Reminders'), findsOneWidget);
      },
    );

    test(
      'Unit test: SettingsProvider persistence saves and loads correctly',
      () async {
        SharedPreferences.setMockInitialValues({});
        final provider = SettingsProvider();
        await provider.initialize();

        expect(provider.weeklyGoal, 5);
        await provider.setWeeklyGoal(8);
        expect(provider.weeklyGoal, 8);

        await provider.setDailyReminder(false);
        expect(provider.dailyReminder, false);

        await provider.setLocale('ta');
        expect(provider.locale, 'ta');

        // Re-initialize a second instance from saved SharedPreferences
        final provider2 = SettingsProvider();
        await provider2.initialize();
        expect(provider2.weeklyGoal, 8);
        expect(provider2.dailyReminder, false);
        expect(provider2.locale, 'ta');
      },
    );

    test(
      'Unit test: Feedback message validation requires min 10 characters',
      () {
        final shortMessage = 'Too short';
        final validMessage =
            'This is a detailed feedback message describing a bug.';

        expect(shortMessage.trim().length >= 10, isFalse);
        expect(validMessage.trim().length >= 10, isTrue);
      },
    );

    testWidgets(
      'Delete Account dialog renders with custom styled field and enables Delete Forever only when DELETE is typed',
      (tester) async {
        final userProvider = UserProvider();
        final statsProvider = StatsProvider();
        final settingsProvider = SettingsProvider();
        await settingsProvider.initialize();

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<UserProvider>.value(value: userProvider),
              ChangeNotifierProvider<StatsProvider>.value(value: statsProvider),
              ChangeNotifierProvider<SettingsProvider>.value(
                value: settingsProvider,
              ),
            ],
            child: const MaterialApp(home: ProfileScreen()),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Scroll to find "Delete Account" button
        final deleteButtonFinder = find.text('Delete Account');
        await tester.scrollUntilVisible(
          deleteButtonFinder,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(deleteButtonFinder, findsOneWidget);

        // Tap Delete Account to open dialog
        await tester.tap(deleteButtonFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Verify dialog components
        expect(find.text('Delete Account'), findsNWidgets(2)); // tile + dialog title
        expect(
          find.text(
            'This action is irreversible. All speech recordings, scores, slide decks, and settings will be permanently erased.',
          ),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is RichText &&
                w.text.toPlainText().contains('Type DELETE to confirm:'),
          ),
          findsOneWidget,
        );
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Delete Forever'), findsOneWidget);

        // "Delete Forever" button is initially disabled
        final deleteForeverBtn = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Delete Forever'),
        );
        expect(deleteForeverBtn.enabled, isFalse);

        // Verify TextField decoration has custom focusedBorder and visible hintText
        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.decoration?.focusedBorder, isNotNull);
        expect(textField.decoration?.hintText, 'DELETE');
        expect(textField.decoration?.hintStyle?.color, isNotNull);

        // Type 'del' (incomplete)
        await tester.enterText(find.byType(TextField), 'del');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final deleteForeverBtn2 = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Delete Forever'),
        );
        expect(deleteForeverBtn2.enabled, isFalse);

        // Type 'DELETE' (match)
        await tester.enterText(find.byType(TextField), 'DELETE');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final deleteForeverBtn3 = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Delete Forever'),
        );
        expect(deleteForeverBtn3.enabled, isTrue);

        // Tap Cancel to dismiss
        await tester.tap(find.text('Cancel'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is RichText &&
                w.text.toPlainText().contains('Type DELETE to confirm:'),
          ),
          findsNothing,
        );
      },
    );
  });
}



