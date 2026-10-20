import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'core/blocs/app_bloc_observer.dart';
import 'core/blocs/session_results_bloc.dart';
import 'core/config/app_config.dart';
import 'core/cubits/settings_cubit.dart';
import 'core/cubits/slide_coach_cubit.dart';
import 'core/cubits/stats_cubit.dart';
import 'core/cubits/user_cubit.dart';
import 'core/providers/session_results_provider.dart';
import 'core/providers/settings_provider.dart';
import 'core/providers/slide_coach_provider.dart';
import 'core/providers/stats_provider.dart';
import 'core/providers/user_provider.dart';
import 'core/providers/gamification_provider.dart';
import 'core/providers/practice_plan_provider.dart';
import 'core/router/app_router.dart';
import 'core/services/api_client.dart';
import 'core/services/notification_service.dart';
import 'core/services/outbox_worker.dart';
import 'core/services/sync_service.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Bloc.observer = const AppBlocObserver();
  AppConfig.validate();

  // Fast auto-discovery of backend (127.0.0.1 for adb reverse or 10.0.2.2 for emulator)
  try {
    final discovered = await AppConfig.discoverBaseUrl();
    ApiClient.instance.updateBaseUrl(discovered);
  } catch (_) {}

  // Firebase / notifications must never block first paint (white/blank web screen).
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e, st) {
    debugPrint('Firebase init failed: $e\n$st');
  }

  if (!kIsWeb) {
    try {
      await NotificationService.instance.initialize();
    } catch (e, st) {
      debugPrint('Notification init failed: $e\n$st');
    }
  }

  // Initialize offline OutboxWorker on app start
  OutboxWorker.instance.init();

  runApp(
    MultiProvider(
      providers: [
        // ── Blocs & Cubits (Enterprise State Management) ──────────────────────
        BlocProvider(create: (_) => SettingsCubit()..initialize()),
        BlocProvider(create: (_) => UserCubit()..tryRestoreSession()),
        BlocProvider(create: (_) => StatsCubit()),
        BlocProvider(
          create: (_) =>
              SessionResultsBloc()..add(const RestoreActiveSessionEvent()),
        ),
        BlocProvider(create: (_) => SlideCoachCubit()..loadSavedDecks()),

        // ── Providers (Backwards compatibility & Shared State) ────────────────
        ChangeNotifierProvider(create: (_) => SettingsProvider()..initialize()),
        ChangeNotifierProvider(
          create: (_) => UserProvider()..tryRestoreSession(),
        ),
        ChangeNotifierProvider(create: (_) => StatsProvider()),
        // SessionResultsProvider is created per-results-screen via ChangeNotifierProvider.value
        // but we expose one top-level instance for convenience
        ChangeNotifierProvider(
          create: (_) =>
              SessionResultsProvider()..restoreActiveSessionIfProcessing(),
        ),
        ChangeNotifierProvider(
          create: (_) => SlideCoachProvider()..restoreActiveDeckIfProcessing(),
        ),
        ChangeNotifierProvider(
          create: (_) => GamificationProvider()..loadGamificationData(),
        ),
        ChangeNotifierProvider(
          create: (_) => PracticePlanProvider(),
        ),
      ],
      child: const PitchCoachApp(),
    ),
  );
}

class PitchCoachApp extends StatefulWidget {
  const PitchCoachApp({super.key});

  @override
  State<PitchCoachApp> createState() => _PitchCoachAppState();
}

class _PitchCoachAppState extends State<PitchCoachApp> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        SyncService.instance.pull();
        OutboxWorker.instance.process();
        try {
          context.read<SlideCoachProvider>().restoreActiveDeckIfProcessing();
          context
              .read<SessionResultsProvider>()
              .restoreActiveSessionIfProcessing();
        } catch (_) {}
      },
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Pitch Coach',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: context.watch<SettingsProvider>().themeMode,
      routerConfig: AppRouter.router,
    );
  }
}
