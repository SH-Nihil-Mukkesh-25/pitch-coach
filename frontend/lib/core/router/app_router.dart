import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/lesson_model.dart';
import '../../core/models/practice_mode.dart';
import '../../features/auth/login_screen.dart';
import '../../features/demo/design_system_demo_page.dart';
import '../../features/history/history_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/interview/interview_practice_screen.dart';
import '../../features/learn/lesson_detail_screen.dart';
import '../../features/learn/lesson_practice_screen.dart';
import '../../features/learn/lessons_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/profile_setup_screen.dart';
import '../../features/profile/screens/notification_preferences_screen.dart';
import '../../features/profile/screens/pro_upgrade_screen.dart';
import '../../features/profile/screens/help_center_screen.dart';
import '../../features/profile/screens/send_feedback_screen.dart';
import '../../features/progress/progress_screen.dart';
import '../../features/results/results_screen.dart';
import '../../features/slide_coach/screens/slide_upload_screen.dart';
import '../../features/slide_coach/screens/slide_processing_screen.dart';
import '../../features/slide_coach/screens/deck_review_screen.dart';
import '../../features/slide_coach/screens/slide_rehearsal_screen.dart';
import '../../features/slide_coach/screens/slide_qa_screen.dart';
import '../widgets/main_shell_scaffold.dart';

abstract class AppRouter {
  static const String onboarding = '/';
  static const String login = '/login';
  static const String profileSetup = '/profile-setup';
  static const String home = '/home';
  static const String history = '/history';
  static const String interview = '/interview';
  static const String results = '/results';
  static const String progress = '/progress';
  static const String profile = '/profile';
  static const String profileNotifications = '/profile/notifications';
  static const String profilePro = '/profile/pro';
  static const String profileHelp = '/profile/help';
  static const String profileFeedback = '/profile/feedback';
  static const String demo = '/demo';
  static const String lessons = '/lessons';
  static const String lessonDetail = '/lessons/detail';
  static const String lessonPractice = '/lessons/practice';

  // ── Slide Coach ───────────────────────────────────────────────────────────
  static const String slideCoachUpload = '/slide-coach';
  static const String slideCoachProcessing = '/slide-coach/processing';
  static const String slideCoachReview = '/slide-coach/review';
  static const String slideCoachRehearsal = '/slide-coach/rehearsal';
  static const String slideCoachQa = '/slide-coach/qa';

  /// Bottom-tab destinations — no transition so phone nav stays responsive.
  static const Set<String> _tabPaths = {home, history, progress, profile};

  static Page<T> _buildPage<T>({
    required BuildContext context,
    required GoRouterState state,
    required Widget child,
  }) {
    if (_tabPaths.contains(state.matchedLocation) ||
        _tabPaths.contains(state.uri.path)) {
      return NoTransitionPage<T>(key: state.pageKey, child: child);
    }

    // Lightweight fade only — avoid undisposed CurvedAnimations and
    // expensive slide+fade stacks on every push.
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 160),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fade = animation.drive(CurveTween(curve: Curves.easeOut));
        return FadeTransition(opacity: fade, child: child);
      },
    );
  }

  static final GoRouter router = GoRouter(
    initialLocation: onboarding,
    routes: [
      GoRoute(
        path: onboarding,
        pageBuilder: (context, state) => _buildPage(
          context: context,
          state: state,
          child: const OnboardingScreen(),
        ),
      ),
      GoRoute(
        path: login,
        pageBuilder: (context, state) {
          final isSignUp = state.extra as bool? ?? false;
          return _buildPage(
            context: context,
            state: state,
            child: LoginScreen(isSignUpInitial: isSignUp),
          );
        },
      ),
      GoRoute(
        path: profileSetup,
        pageBuilder: (context, state) => _buildPage(
          context: context,
          state: state,
          child: const ProfileSetupScreen(),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShellScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: home,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: HomeScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: history,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: HistoryScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: progress,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: ProgressScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: profile,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: ProfileScreen()),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: interview,
        pageBuilder: (context, state) {
          PracticeSessionConfig? config;
          if (state.extra is PracticeSessionConfig) {
            config = state.extra as PracticeSessionConfig;
          } else if (state.extra is String) {
            config = PracticeSessionConfig.defaultFor(state.extra as String);
          } else if (state.extra is Map<String, dynamic>) {
            final map = state.extra as Map<String, dynamic>;
            config = PracticeSessionConfig.defaultFor(map['mode'] as String?);
          }
          return _buildPage(
            context: context,
            state: state,
            child: InterviewPracticeScreen(initialConfig: config),
          );
        },
      ),
      GoRoute(
        path: results,
        pageBuilder: (context, state) {
          String? sessionId;
          if (state.extra is String) {
            sessionId = state.extra as String;
          } else if (state.extra is Map<String, dynamic>) {
            final map = state.extra as Map<String, dynamic>;
            sessionId =
                (map['session_id'] as String?) ?? (map['id'] as String?);
          }
          sessionId ??= state.uri.queryParameters['session_id'];
          return _buildPage(
            context: context,
            state: state,
            child: ResultsScreen(sessionId: sessionId),
          );
        },
      ),
      if (kDebugMode)
        GoRoute(
          path: demo,
          pageBuilder: (context, state) => _buildPage(
            context: context,
            state: state,
            child: const DesignSystemDemoPage(),
          ),
        ),
      GoRoute(
        path: lessons,
        pageBuilder: (context, state) => _buildPage(
          context: context,
          state: state,
          child: LessonsScreen(
            initialCategory: state.extra as String?,
          ),
        ),
      ),
      GoRoute(
        path: profileNotifications,
        pageBuilder: (context, state) => _buildPage(
          context: context,
          state: state,
          child: const NotificationPreferencesScreen(),
        ),
      ),
      GoRoute(
        path: profilePro,
        pageBuilder: (context, state) => _buildPage(
          context: context,
          state: state,
          child: const ProUpgradeScreen(),
        ),
      ),
      GoRoute(
        path: profileHelp,
        pageBuilder: (context, state) => _buildPage(
          context: context,
          state: state,
          child: const HelpCenterScreen(),
        ),
      ),
      GoRoute(
        path: profileFeedback,
        pageBuilder: (context, state) => _buildPage(
          context: context,
          state: state,
          child: const SendFeedbackScreen(),
        ),
      ),
      GoRoute(
        path: lessonDetail,
        pageBuilder: (context, state) {
          final lesson = state.extra as Lesson;
          return _buildPage(
            context: context,
            state: state,
            child: LessonDetailScreen(lesson: lesson),
          );
        },
      ),
      GoRoute(
        path: lessonPractice,
        pageBuilder: (context, state) {
          final lesson = state.extra as Lesson;
          return _buildPage(
            context: context,
            state: state,
            child: LessonPracticeScreen(lesson: lesson),
          );
        },
      ),
      GoRoute(
        path: slideCoachUpload,
        pageBuilder: (context, state) => _buildPage(
          context: context,
          state: state,
          child: const SlideUploadScreen(),
        ),
      ),
      GoRoute(
        path: slideCoachProcessing,
        pageBuilder: (context, state) => _buildPage(
          context: context,
          state: state,
          child: const SlideProcessingScreen(),
        ),
      ),
      GoRoute(
        path: slideCoachReview,
        pageBuilder: (context, state) => _buildPage(
          context: context,
          state: state,
          child: const DeckReviewScreen(),
        ),
      ),
      GoRoute(
        path: slideCoachRehearsal,
        pageBuilder: (context, state) => _buildPage(
          context: context,
          state: state,
          child: const SlideRehearsalScreen(),
        ),
      ),
      GoRoute(
        path: slideCoachQa,
        pageBuilder: (context, state) => _buildPage(
          context: context,
          state: state,
          child: const SlideQaScreen(),
        ),
      ),
    ],
  );
}
