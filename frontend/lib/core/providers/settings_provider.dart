import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/auth_repository.dart';

/// Provider for app-wide user settings, notification preferences, and reminder configuration.
/// Offline-first: stored in SharedPreferences and synced optimistically to backend user doc in Firestore.
class SettingsProvider extends ChangeNotifier {
  static const String _keyThemeMode = 'pitch_coach_theme_mode';
  static const String _keyLocale = 'pitch_coach_locale';
  static const String _keyDailyReminder = 'pitch_coach_daily_reminder';
  static const String _keySlideDeckReady = 'pitch_coach_slide_deck_ready';
  static const String _keyWeeklySummary = 'pitch_coach_weekly_summary';
  static const String _keyTipsLessons = 'pitch_coach_tips_lessons';
  static const String _keyReminderHour = 'pitch_coach_reminder_hour';
  static const String _keyReminderMinute = 'pitch_coach_reminder_minute';
  static const String _keyReminderDays = 'pitch_coach_reminder_days';
  static const String _keyWeeklyGoal = 'pitch_coach_weekly_goal';
  static const String _keyLastReviewPrompt = 'pitch_coach_last_review_prompt';
  static const String _keyAmbientLiveCues = 'pitch_coach_ambient_live_cues';
  static const String _keyInterviewTargetDate =
      'pitch_coach_interview_target_date';
  static const String _keyQuietHoursEnabled =
      'pitch_coach_quiet_hours_enabled';
  static const String _keyQuietHoursStart = 'pitch_coach_quiet_hours_start';
  static const String _keyQuietHoursEnd = 'pitch_coach_quiet_hours_end';

  /// Helper to check if slide deck ready notification is enabled from background/isolated services
  static Future<bool> isSlideDeckReadyAlertEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keySlideDeckReady) ?? true;
    } catch (_) {
      return true;
    }
  }

  final AuthRepository _auth = AuthRepository.instance;
  SharedPreferences? _prefs;

  ThemeMode _themeMode = ThemeMode.system;
  String _locale = 'en';

  bool _dailyReminder = true;
  bool _slideDeckReadyAlerts = true;
  bool _weeklyProgressSummary = true;
  bool _tipsAndLessons = true;
  bool _ambientLiveCues = true;

  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);
  List<int> _reminderDays = [1, 2, 3, 4, 5]; // 1 = Monday ... 7 = Sunday
  int _weeklyGoal = 5;

  DateTime? _interviewTargetDate;
  bool _quietHoursEnabled = true;
  int _quietHoursStart = 22; // 10 PM
  int _quietHoursEnd = 8; // 8 AM

  bool _isLoading = false;
  String? _syncError;

  ThemeMode get themeMode => _themeMode;
  String get locale => _locale;
  bool get dailyReminder => _dailyReminder;
  bool get slideDeckReadyAlerts => _slideDeckReadyAlerts;
  bool get weeklyProgressSummary => _weeklyProgressSummary;
  bool get tipsAndLessons => _tipsAndLessons;
  bool get ambientLiveCues => _ambientLiveCues;
  TimeOfDay get reminderTime => _reminderTime;
  List<int> get reminderDays => List.unmodifiable(_reminderDays);
  int get weeklyGoal => _weeklyGoal;
  DateTime? get interviewTargetDate => _interviewTargetDate;
  bool get quietHoursEnabled => _quietHoursEnabled;
  int get quietHoursStart => _quietHoursStart;
  int get quietHoursEnd => _quietHoursEnd;
  bool get isLoading => _isLoading;
  String? get syncError => _syncError;

  bool isDarkMode(BuildContext context) {
    if (_themeMode == ThemeMode.dark) return true;
    if (_themeMode == ThemeMode.light) return false;
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  }

  /// Initialize and load saved settings from SharedPreferences.
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      _prefs = await SharedPreferences.getInstance();
      _loadFromPrefs();
    } catch (_) {
      // SharedPreferences failure fallback
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _loadFromPrefs() {
    if (_prefs == null) return;

    final themeStr = _prefs!.getString(_keyThemeMode);
    if (themeStr == 'dark') {
      _themeMode = ThemeMode.dark;
    } else if (themeStr == 'light') {
      _themeMode = ThemeMode.light;
    } else {
      _themeMode = ThemeMode.system;
    }

    _locale = _prefs!.getString(_keyLocale) ?? 'en';
    _dailyReminder = _prefs!.getBool(_keyDailyReminder) ?? true;
    _slideDeckReadyAlerts = _prefs!.getBool(_keySlideDeckReady) ?? true;
    _weeklyProgressSummary = _prefs!.getBool(_keyWeeklySummary) ?? true;
    _tipsAndLessons = _prefs!.getBool(_keyTipsLessons) ?? true;
    _ambientLiveCues = _prefs!.getBool(_keyAmbientLiveCues) ?? true;

    final hour = _prefs!.getInt(_keyReminderHour) ?? 9;
    final minute = _prefs!.getInt(_keyReminderMinute) ?? 0;
    _reminderTime = TimeOfDay(hour: hour, minute: minute);

    final daysList = _prefs!.getStringList(_keyReminderDays);
    if (daysList != null && daysList.isNotEmpty) {
      _reminderDays = daysList.map((d) => int.tryParse(d) ?? 1).toList();
    } else {
      _reminderDays = [1, 2, 3, 4, 5];
    }

    _weeklyGoal = _prefs!.getInt(_keyWeeklyGoal) ?? 5;

    final targetDateStr = _prefs!.getString(_keyInterviewTargetDate);
    if (targetDateStr != null && targetDateStr.isNotEmpty) {
      _interviewTargetDate = DateTime.tryParse(targetDateStr);
    } else {
      _interviewTargetDate = null;
    }
    _quietHoursEnabled = _prefs!.getBool(_keyQuietHoursEnabled) ?? true;
    _quietHoursStart = _prefs!.getInt(_keyQuietHoursStart) ?? 22;
    _quietHoursEnd = _prefs!.getInt(_keyQuietHoursEnd) ?? 8;
  }

  /// Map representation for Firestore sync
  Map<String, dynamic> toMap() {
    return {
      'theme_mode': _themeMode.name,
      'locale': _locale,
      'daily_reminder': _dailyReminder,
      'slide_deck_ready_alerts': _slideDeckReadyAlerts,
      'weekly_progress_summary': _weeklyProgressSummary,
      'tips_and_lessons': _tipsAndLessons,
      'ambient_live_cues': _ambientLiveCues,
      'reminder_hour': _reminderTime.hour,
      'reminder_minute': _reminderTime.minute,
      'reminder_days': _reminderDays,
      'weekly_goal': _weeklyGoal,
      'interview_target_date': _interviewTargetDate?.toIso8601String(),
      'quiet_hours_enabled': _quietHoursEnabled,
      'quiet_hours_start': _quietHoursStart,
      'quiet_hours_end': _quietHoursEnd,
    };
  }

  /// Import settings map loaded from backend user doc
  Future<void> importFromMap(Map<String, dynamic>? data) async {
    if (data == null || data.isEmpty) return;

    if (data['theme_mode'] != null) {
      final t = data['theme_mode'] as String;
      _themeMode = t == 'dark'
          ? ThemeMode.dark
          : t == 'light'
          ? ThemeMode.light
          : ThemeMode.system;
    }
    if (data['locale'] != null) {
      _locale = data['locale'] as String;
    }
    if (data['daily_reminder'] != null) {
      _dailyReminder = data['daily_reminder'] as bool;
    }
    if (data['slide_deck_ready_alerts'] != null) {
      _slideDeckReadyAlerts = data['slide_deck_ready_alerts'] as bool;
    }
    if (data['weekly_progress_summary'] != null) {
      _weeklyProgressSummary = data['weekly_progress_summary'] as bool;
    }
    if (data['tips_and_lessons'] != null) {
      _tipsAndLessons = data['tips_and_lessons'] as bool;
    }
    if (data['ambient_live_cues'] != null) {
      _ambientLiveCues = data['ambient_live_cues'] as bool;
    }
    if (data['reminder_hour'] != null && data['reminder_minute'] != null) {
      _reminderTime = TimeOfDay(
        hour: (data['reminder_hour'] as num).toInt(),
        minute: (data['reminder_minute'] as num).toInt(),
      );
    }
    if (data['reminder_days'] != null) {
      final list = data['reminder_days'] as List;
      _reminderDays = list.map((e) => (e as num).toInt()).toList();
    }
    if (data['weekly_goal'] != null) {
      _weeklyGoal = (data['weekly_goal'] as num).toInt().clamp(1, 14);
    }
    if (data.containsKey('interview_target_date')) {
      final str = data['interview_target_date'] as String?;
      _interviewTargetDate = str != null ? DateTime.tryParse(str) : null;
    }
    if (data['quiet_hours_enabled'] != null) {
      _quietHoursEnabled = data['quiet_hours_enabled'] as bool;
    }
    if (data['quiet_hours_start'] != null) {
      _quietHoursStart = (data['quiet_hours_start'] as num).toInt();
    }
    if (data['quiet_hours_end'] != null) {
      _quietHoursEnd = (data['quiet_hours_end'] as num).toInt();
    }

    await _saveToPrefs();
    notifyListeners();
  }

  /// Toggle ambient pacing cues indicator around live recording timer
  Future<void> setAmbientLiveCues(bool enabled) async {
    final previous = _ambientLiveCues;
    _ambientLiveCues = enabled;
    notifyListeners();
    await _saveToPrefs();
    await _syncToBackend(
      rollback: () {
        _ambientLiveCues = previous;
        _saveToPrefs();
        notifyListeners();
      },
    );
  }

  Future<void> _saveToPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    if (_prefs == null) return;
    await _prefs!.setString(_keyThemeMode, _themeMode.name);
    await _prefs!.setString(_keyLocale, _locale);
    await _prefs!.setBool(_keyDailyReminder, _dailyReminder);
    await _prefs!.setBool(_keySlideDeckReady, _slideDeckReadyAlerts);
    await _prefs!.setBool(_keyWeeklySummary, _weeklyProgressSummary);
    await _prefs!.setBool(_keyTipsLessons, _tipsAndLessons);
    await _prefs!.setBool(_keyAmbientLiveCues, _ambientLiveCues);
    await _prefs!.setInt(_keyReminderHour, _reminderTime.hour);
    await _prefs!.setInt(_keyReminderMinute, _reminderTime.minute);
    await _prefs!.setStringList(
      _keyReminderDays,
      _reminderDays.map((d) => d.toString()).toList(),
    );
    await _prefs!.setInt(_keyWeeklyGoal, _weeklyGoal);

    if (_interviewTargetDate != null) {
      await _prefs!.setString(
        _keyInterviewTargetDate,
        _interviewTargetDate!.toIso8601String(),
      );
    } else {
      await _prefs!.remove(_keyInterviewTargetDate);
    }
    await _prefs!.setBool(_keyQuietHoursEnabled, _quietHoursEnabled);
    await _prefs!.setInt(_keyQuietHoursStart, _quietHoursStart);
    await _prefs!.setInt(_keyQuietHoursEnd, _quietHoursEnd);
  }

  /// Optimistically update theme mode and sync
  Future<bool> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _saveToPrefs();

    return _syncToBackend();
  }

  /// Toggle dark mode helper (used by ThemeToggleButton)
  Future<void> toggleDarkMode(BuildContext context) async {
    final currentlyDark = isDarkMode(context);
    await setThemeMode(currentlyDark ? ThemeMode.light : ThemeMode.dark);
  }

  /// Optimistically update locale and sync
  Future<bool> setLocale(String code) async {
    final previous = _locale;
    _locale = code;
    notifyListeners();
    await _saveToPrefs();

    return _syncToBackend(
      rollback: () {
        _locale = previous;
        _saveToPrefs();
        notifyListeners();
      },
    );
  }

  /// Optimistically update notification preferences
  Future<bool> setNotificationPreferences({
    bool? dailyReminder,
    bool? slideDeckReadyAlerts,
    bool? weeklyProgressSummary,
    bool? tipsAndLessons,
  }) async {
    final prevDaily = _dailyReminder;
    final prevSlide = _slideDeckReadyAlerts;
    final prevWeekly = _weeklyProgressSummary;
    final prevTips = _tipsAndLessons;

    if (dailyReminder != null) {
      _dailyReminder = dailyReminder;
    }
    if (slideDeckReadyAlerts != null) {
      _slideDeckReadyAlerts = slideDeckReadyAlerts;
    }
    if (weeklyProgressSummary != null) {
      _weeklyProgressSummary = weeklyProgressSummary;
    }
    if (tipsAndLessons != null) {
      _tipsAndLessons = tipsAndLessons;
    }

    notifyListeners();
    await _saveToPrefs();

    return _syncToBackend(
      rollback: () {
        _dailyReminder = prevDaily;
        _slideDeckReadyAlerts = prevSlide;
        _weeklyProgressSummary = prevWeekly;
        _tipsAndLessons = prevTips;
        _saveToPrefs();
        notifyListeners();
      },
    );
  }

  /// Optimistically update practice reminder schedule & goal
  Future<bool> setReminderConfig({
    TimeOfDay? time,
    List<int>? days,
    int? weeklyGoal,
  }) async {
    final prevTime = _reminderTime;
    final prevDays = List<int>.from(_reminderDays);
    final prevGoal = _weeklyGoal;

    if (time != null) _reminderTime = time;
    if (days != null) _reminderDays = List<int>.from(days);
    if (weeklyGoal != null) _weeklyGoal = weeklyGoal.clamp(1, 14);

    notifyListeners();
    await _saveToPrefs();

    return _syncToBackend(
      rollback: () {
        _reminderTime = prevTime;
        _reminderDays = prevDays;
        _weeklyGoal = prevGoal;
        _saveToPrefs();
        notifyListeners();
      },
    );
  }

  Future<void> setDailyReminder(bool enabled) async {
    await setNotificationPreferences(dailyReminder: enabled);
  }

  Future<void> setSlideDeckReadyAlerts(bool enabled) async {
    await setNotificationPreferences(slideDeckReadyAlerts: enabled);
  }

  Future<void> setWeeklyProgressSummary(bool enabled) async {
    await setNotificationPreferences(weeklyProgressSummary: enabled);
  }

  Future<void> setTipsAndLessons(bool enabled) async {
    await setNotificationPreferences(tipsAndLessons: enabled);
  }

  Future<void> setReminderTime(TimeOfDay time) async {
    await setReminderConfig(time: time);
  }

  Future<void> setReminderDays(List<int> days) async {
    await setReminderConfig(days: days);
  }

  Future<void> setWeeklyGoal(int goal) async {
    await setReminderConfig(weeklyGoal: goal);
  }

  Future<bool> setInterviewTargetDate(DateTime? date) async {
    final prev = _interviewTargetDate;
    _interviewTargetDate = date;
    notifyListeners();
    await _saveToPrefs();

    return _syncToBackend(
      rollback: () {
        _interviewTargetDate = prev;
        _saveToPrefs();
        notifyListeners();
      },
    );
  }

  Future<bool> setQuietHours({
    bool? enabled,
    int? startHour,
    int? endHour,
  }) async {
    final prevEnabled = _quietHoursEnabled;
    final prevStart = _quietHoursStart;
    final prevEnd = _quietHoursEnd;

    if (enabled != null) _quietHoursEnabled = enabled;
    if (startHour != null) _quietHoursStart = startHour;
    if (endHour != null) _quietHoursEnd = endHour;

    notifyListeners();
    await _saveToPrefs();

    return _syncToBackend(
      rollback: () {
        _quietHoursEnabled = prevEnabled;
        _quietHoursStart = prevStart;
        _quietHoursEnd = prevEnd;
        _saveToPrefs();
        notifyListeners();
      },
    );
  }

  Future<bool> syncWithBackend() async {
    return _syncToBackend(rollback: () {});
  }

  /// Rate app throttling: returns true if at least 30 days passed since last prompt
  bool canPromptForReview() {
    if (_prefs == null) return true;
    final last = _prefs!.getInt(_keyLastReviewPrompt) ?? 0;
    if (last == 0) return true;
    final lastDate = DateTime.fromMillisecondsSinceEpoch(last);
    return DateTime.now().difference(lastDate).inDays >= 30;
  }

  Future<void> recordReviewPrompt() async {
    if (_prefs == null) return;
    await _prefs!.setInt(
      _keyLastReviewPrompt,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Internal sync helper — syncs settings optimistically to backend.
  /// If the backend is unreachable or offline, the changes are preserved locally
  /// in SharedPreferences without rolling back the user's selected preferences.
  Future<bool> _syncToBackend({VoidCallback? rollback}) async {
    _syncError = null;
    bool hasTokens = false;
    try {
      hasTokens = await _auth.hasStoredTokens.timeout(
        const Duration(milliseconds: 300),
        onTimeout: () => false,
      );
    } catch (_) {
      // Platform channels unbound or guest mode: local save is sufficient
      return true;
    }

    if (!hasTokens) {
      return true;
    }

    try {
      await _auth
          .updateMe({
            'dark_mode': _themeMode == ThemeMode.dark,
            'settings': toMap(),
          })
          .timeout(const Duration(seconds: 3));
      return true;
    } catch (e) {
      _syncError = 'Could not sync settings to cloud. Changes kept locally.';
      debugPrint('[SettingsProvider] $_syncError: $e');
      // Offline-first: Never roll back local user preferences on cloud sync error
      return false;
    }
  }

  /// Wipes settings stored in SharedPreferences and resets state to defaults.
  /// Preserves the user's theme selection by default so account operations
  /// do not unexpectedly flip the visual appearance from light to dark mode.
  Future<void> clearAllSettings({bool preserveTheme = true}) async {
    _prefs ??= await SharedPreferences.getInstance();
    if (!preserveTheme) {
      await _prefs!.remove(_keyThemeMode);
      _themeMode = ThemeMode.system;
    }
    await _prefs!.remove(_keyLocale);
    await _prefs!.remove(_keyDailyReminder);
    await _prefs!.remove(_keySlideDeckReady);
    await _prefs!.remove(_keyWeeklySummary);
    await _prefs!.remove(_keyTipsLessons);
    await _prefs!.remove(_keyReminderHour);
    await _prefs!.remove(_keyReminderMinute);
    await _prefs!.remove(_keyReminderDays);
    await _prefs!.remove(_keyWeeklyGoal);
    await _prefs!.remove(_keyLastReviewPrompt);
    await _prefs!.remove(_keyAmbientLiveCues);
    await _prefs!.remove(_keyInterviewTargetDate);
    await _prefs!.remove(_keyQuietHoursEnabled);
    await _prefs!.remove(_keyQuietHoursStart);
    await _prefs!.remove(_keyQuietHoursEnd);

    _locale = 'en';
    _dailyReminder = true;
    _slideDeckReadyAlerts = true;
    _weeklyProgressSummary = true;
    _tipsAndLessons = true;
    _ambientLiveCues = true;
    _reminderTime = const TimeOfDay(hour: 9, minute: 0);
    _reminderDays = [1, 2, 3, 4, 5];
    _weeklyGoal = 5;
    _interviewTargetDate = null;
    _quietHoursEnabled = true;
    _quietHoursStart = 22;
    _quietHoursEnd = 8;
    _syncError = null;
    notifyListeners();
  }
}
