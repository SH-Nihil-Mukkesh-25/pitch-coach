import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/auth_repository.dart';

/// Immutable state for app-wide settings and preferences.
class SettingsState extends Equatable {
  final ThemeMode themeMode;
  final String locale;
  final bool dailyReminder;
  final bool slideDeckReadyAlerts;
  final bool weeklyProgressSummary;
  final bool tipsAndLessons;
  final TimeOfDay reminderTime;
  final List<int> reminderDays;
  final int weeklyGoal;
  final bool isLoading;
  final String? syncError;

  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.locale = 'en',
    this.dailyReminder = true,
    this.slideDeckReadyAlerts = true,
    this.weeklyProgressSummary = true,
    this.tipsAndLessons = true,
    this.reminderTime = const TimeOfDay(hour: 9, minute: 0),
    this.reminderDays = const [1, 2, 3, 4, 5],
    this.weeklyGoal = 5,
    this.isLoading = false,
    this.syncError,
  });

  bool isDarkMode(BuildContext context) {
    if (themeMode == ThemeMode.dark) return true;
    if (themeMode == ThemeMode.light) return false;
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  }

  SettingsState copyWith({
    ThemeMode? themeMode,
    String? locale,
    bool? dailyReminder,
    bool? slideDeckReadyAlerts,
    bool? weeklyProgressSummary,
    bool? tipsAndLessons,
    TimeOfDay? reminderTime,
    List<int>? reminderDays,
    int? weeklyGoal,
    bool? isLoading,
    String? syncError,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      dailyReminder: dailyReminder ?? this.dailyReminder,
      slideDeckReadyAlerts: slideDeckReadyAlerts ?? this.slideDeckReadyAlerts,
      weeklyProgressSummary:
          weeklyProgressSummary ?? this.weeklyProgressSummary,
      tipsAndLessons: tipsAndLessons ?? this.tipsAndLessons,
      reminderTime: reminderTime ?? this.reminderTime,
      reminderDays: reminderDays ?? this.reminderDays,
      weeklyGoal: weeklyGoal ?? this.weeklyGoal,
      isLoading: isLoading ?? this.isLoading,
      syncError: syncError,
    );
  }

  Map<String, dynamic> toMap() => {
    'theme': themeMode.name,
    'locale': locale,
    'daily_reminder': dailyReminder,
    'slide_deck_ready_alerts': slideDeckReadyAlerts,
    'weekly_progress_summary': weeklyProgressSummary,
    'tips_and_lessons': tipsAndLessons,
    'reminder_hour': reminderTime.hour,
    'reminder_minute': reminderTime.minute,
    'reminder_days': reminderDays,
    'weekly_goal': weeklyGoal,
  };

  @override
  List<Object?> get props => [
    themeMode,
    locale,
    dailyReminder,
    slideDeckReadyAlerts,
    weeklyProgressSummary,
    tipsAndLessons,
    reminderTime.hour,
    reminderTime.minute,
    reminderDays,
    weeklyGoal,
    isLoading,
    syncError,
  ];
}

/// Cubit managing app-wide preferences, theme, and practice goals.
class SettingsCubit extends Cubit<SettingsState> {
  static const String keyThemeMode = 'pitch_coach_theme_mode';
  static const String keyLocale = 'pitch_coach_locale';
  static const String keyDailyReminder = 'pitch_coach_daily_reminder';
  static const String keySlideDeckReady = 'pitch_coach_slide_deck_ready';
  static const String keyWeeklySummary = 'pitch_coach_weekly_summary';
  static const String keyTipsLessons = 'pitch_coach_tips_lessons';
  static const String keyReminderHour = 'pitch_coach_reminder_hour';
  static const String keyReminderMinute = 'pitch_coach_reminder_minute';
  static const String keyReminderDays = 'pitch_coach_reminder_days';
  static const String keyWeeklyGoal = 'pitch_coach_weekly_goal';

  static Future<bool> isSlideDeckReadyAlertEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(keySlideDeckReady) ?? true;
    } catch (_) {
      return true;
    }
  }

  final AuthRepository _auth;
  SharedPreferences? _prefs;

  SettingsCubit({AuthRepository? authRepository, SharedPreferences? prefs})
    : _auth = authRepository ?? AuthRepository.instance,
      _prefs = prefs,
      super(const SettingsState());

  Future<void> initialize() async {
    emit(state.copyWith(isLoading: true));
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final p = _prefs!;

      final savedTheme = p.getString(keyThemeMode);
      ThemeMode themeMode = ThemeMode.system;
      if (savedTheme == 'light') themeMode = ThemeMode.light;
      if (savedTheme == 'dark') themeMode = ThemeMode.dark;

      final locale = p.getString(keyLocale) ?? 'en';
      final dailyReminder = p.getBool(keyDailyReminder) ?? true;
      final slideDeckReadyAlerts = p.getBool(keySlideDeckReady) ?? true;
      final weeklyProgressSummary = p.getBool(keyWeeklySummary) ?? true;
      final tipsAndLessons = p.getBool(keyTipsLessons) ?? true;

      final hour = p.getInt(keyReminderHour) ?? 9;
      final minute = p.getInt(keyReminderMinute) ?? 0;
      final reminderTime = TimeOfDay(hour: hour, minute: minute);

      final daysStr = p.getStringList(keyReminderDays);
      List<int> reminderDays = [1, 2, 3, 4, 5];
      if (daysStr != null) {
        reminderDays = daysStr.map((s) => int.tryParse(s) ?? 1).toList();
      }

      final weeklyGoal = p.getInt(keyWeeklyGoal) ?? 5;

      emit(
        SettingsState(
          themeMode: themeMode,
          locale: locale,
          dailyReminder: dailyReminder,
          slideDeckReadyAlerts: slideDeckReadyAlerts,
          weeklyProgressSummary: weeklyProgressSummary,
          tipsAndLessons: tipsAndLessons,
          reminderTime: reminderTime,
          reminderDays: reminderDays,
          weeklyGoal: weeklyGoal,
          isLoading: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, syncError: e.toString()));
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    emit(state.copyWith(themeMode: mode));
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(
      keyThemeMode,
      mode == ThemeMode.light
          ? 'light'
          : mode == ThemeMode.dark
          ? 'dark'
          : 'system',
    );
    _syncToBackend({'theme': mode.name});
  }

  void toggleTheme(BuildContext context) {
    final currentIsDark = state.isDarkMode(context);
    setThemeMode(currentIsDark ? ThemeMode.light : ThemeMode.dark);
  }

  Future<void> setLocale(String locale) async {
    emit(state.copyWith(locale: locale));
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(keyLocale, locale);
    _syncToBackend({'locale': locale});
  }

  Future<void> setDailyReminder(bool enabled) async {
    emit(state.copyWith(dailyReminder: enabled));
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool(keyDailyReminder, enabled);
    _syncToBackend({'dailyReminder': enabled});
  }

  Future<void> setSlideDeckReadyAlerts(bool enabled) async {
    emit(state.copyWith(slideDeckReadyAlerts: enabled));
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool(keySlideDeckReady, enabled);
  }

  Future<void> setWeeklyProgressSummary(bool enabled) async {
    emit(state.copyWith(weeklyProgressSummary: enabled));
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool(keyWeeklySummary, enabled);
  }

  Future<void> setTipsAndLessons(bool enabled) async {
    emit(state.copyWith(tipsAndLessons: enabled));
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool(keyTipsLessons, enabled);
  }

  Future<void> setReminderTime(TimeOfDay time) async {
    emit(state.copyWith(reminderTime: time));
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setInt(keyReminderHour, time.hour);
    await _prefs!.setInt(keyReminderMinute, time.minute);
    _syncToBackend({'reminderTime': '${time.hour}:${time.minute}'});
  }

  Future<void> setPracticeGoals({
    required TimeOfDay time,
    required List<int> days,
    required int weeklyGoal,
  }) async {
    emit(
      state.copyWith(
        reminderTime: time,
        reminderDays: days,
        weeklyGoal: weeklyGoal,
      ),
    );
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setInt(keyReminderHour, time.hour);
    await _prefs!.setInt(keyReminderMinute, time.minute);
    await _prefs!.setStringList(
      keyReminderDays,
      days.map((d) => d.toString()).toList(),
    );
    await _prefs!.setInt(keyWeeklyGoal, weeklyGoal);
    _syncToBackend({'reminderDays': days, 'weeklyGoal': weeklyGoal});
  }

  Future<void> _syncToBackend(Map<String, dynamic> data) async {
    try {
      final hasTokens = await _auth.hasStoredTokens.timeout(
        const Duration(milliseconds: 300),
        onTimeout: () => false,
      );
      if (!hasTokens) return;

      await _auth
          .updateMe({'settings': state.toMap()})
          .timeout(const Duration(seconds: 3));
    } catch (e) {
      emit(
        state.copyWith(
          syncError: 'Could not sync settings to cloud. Changes kept locally.',
        ),
      );
    }
  }

  /// Wipes settings from SharedPreferences and resets state to default.
  /// Preserves the user's theme selection by default so account operations
  /// do not unexpectedly flip the visual appearance from light to dark mode.
  Future<void> clearAllSettings({bool preserveTheme = true}) async {
    _prefs ??= await SharedPreferences.getInstance();
    final themeToKeep = preserveTheme ? state.themeMode : ThemeMode.system;
    if (!preserveTheme) {
      await _prefs!.remove(keyThemeMode);
    }
    await _prefs!.remove(keyLocale);
    await _prefs!.remove(keyDailyReminder);
    await _prefs!.remove(keySlideDeckReady);
    await _prefs!.remove(keyWeeklySummary);
    await _prefs!.remove(keyTipsLessons);
    await _prefs!.remove(keyReminderHour);
    await _prefs!.remove(keyReminderMinute);
    await _prefs!.remove(keyReminderDays);
    await _prefs!.remove(keyWeeklyGoal);

    emit(SettingsState(
      themeMode: themeToKeep,
    ));
  }
}
