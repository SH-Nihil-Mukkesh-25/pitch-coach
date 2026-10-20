import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';
import '../models/session_result.dart';
import '../repositories/practice_plan_repository.dart';
import '../repositories/session_repository.dart';
import '../services/local_database_service.dart';
import '../services/notification_service.dart';

enum ResultsLoadState { loading, analyzing, ready, failed, error }

/// Holds the current session results, drives the exponential backoff polling loop,
/// and orchestrates background analysis with phone & in-app notifications.
class SessionResultsProvider extends ChangeNotifier {
  final _repo = SessionRepository.instance;
  static const String _storageActiveSessionKey = 'active_processing_session_id';
  final _storage = const FlutterSecureStorage();

  SessionResult? _result;
  ResultsLoadState _state = ResultsLoadState.loading;
  String? _errorMessage;
  Timer? _pollTimer;
  DateTime? _pollStartTime;
  Duration _currentInterval = AppConfig.resultsPollInitialInterval;
  bool _disposed = false;

  // ── Background Processing State ──
  String? _activeSessionId;
  String? _activeTopic;
  String? _activeMode;
  bool _isBackgroundProcessing = false;

  // ── In-App Completed Celebration Announcement ──
  SessionResult? _completedSessionToAnnounce;
  SessionResult? get completedSessionToAnnounce => _completedSessionToAnnounce;

  void dismissCompletedAnnouncement() {
    _completedSessionToAnnounce = null;
    notifyListeners();
  }

  SessionResult? get result => _result;
  ResultsLoadState get state => _state;
  String? get errorMessage => _errorMessage;

  bool get hasActiveBackgroundProcessing =>
      _isBackgroundProcessing &&
      _activeSessionId != null &&
      (_state == ResultsLoadState.analyzing ||
          _state == ResultsLoadState.loading);

  String? get activeSessionId => _activeSessionId;
  String? get activeTopic => _activeTopic;
  String? get activeMode => _activeMode;

  /// Restores active processing state upon app cold start or resume.
  Future<void> restoreActiveSessionIfProcessing() async {
    try {
      final storedData = await _storage.read(key: _storageActiveSessionKey);
      if (storedData == null || storedData.trim().isEmpty) return;

      Map<String, dynamic> parsed;
      try {
        parsed = jsonDecode(storedData) as Map<String, dynamic>;
      } catch (_) {
        parsed = {'id': storedData};
      }

      final sessionId = parsed['id'] as String?;
      if (sessionId == null || sessionId.isEmpty) return;
      if (_isBackgroundProcessing && _activeSessionId == sessionId) return;

      _activeSessionId = sessionId;
      _activeTopic = parsed['topic'] as String?;
      _activeMode = parsed['mode'] as String?;
      _isBackgroundProcessing = true;

      final session = await _repo.getSession(sessionId);
      if (session.isAnalyzed) {
        await _storage.delete(key: _storageActiveSessionKey);
        _isBackgroundProcessing = false;
        _repo.cacheSession(session);
        _result = session;
        if (!session.analysisFailed) {
          _state = ResultsLoadState.ready;
          _completedSessionToAnnounce = session;
          try {
            await NotificationService.instance.showInstantNotification(
              'Practice Session Ready',
              'Your ${session.modeLabel} feedback for "${session.topicOrQuestion}" is ready with score ${session.overallScore.round()}%.',
            );
          } catch (e) {
            debugPrint('Failed to send session notification: $e');
          }
        } else {
          _state = ResultsLoadState.failed;
          _errorMessage = session.failureReason ?? 'Analysis failed';
        }
        notifyListeners();
      } else {
        _startPolling(sessionId);
      }
    } catch (e) {
      debugPrint('[SessionResultsProvider] Error restoring active session: $e');
    }
  }

  /// Initiates or registers background analysis tracking with secure storage persistence.
  Future<void> startBackgroundProcessing({
    required String sessionId,
    String? topic,
    String? mode,
  }) async {
    _activeSessionId = sessionId;
    _activeTopic = topic;
    _activeMode = mode;
    _isBackgroundProcessing = true;
    _state = ResultsLoadState.analyzing;
    _errorMessage = null;
    notifyListeners();

    try {
      await _storage.write(
        key: _storageActiveSessionKey,
        value: jsonEncode({
          'id': sessionId,
          'topic': topic ?? 'Practice session',
          'mode': mode ?? 'interview',
        }),
      );
    } catch (e) {
      debugPrint('Failed to save active session to secure storage: $e');
    }

    _pollStartTime = DateTime.now();
    _currentInterval = AppConfig.resultsPollInitialInterval;
    _startPolling(sessionId);
  }

  /// Called by ResultsScreen when it receives a session_id.
  /// If session is already analyzed in memory, loads instantly with 0ms delay!
  void loadSession(
    String sessionId, {
    bool forceRefresh = false,
    String? topic,
    String? mode,
  }) {
    if (!forceRefresh) {
      final cached = _repo.getCachedSession(sessionId);
      if (cached != null && cached.isAnalyzed && !cached.analysisFailed) {
        _result = cached;
        _state = ResultsLoadState.ready;
        _errorMessage = null;
        notifyListeners();
        return;
      }
    }

    _activeSessionId = sessionId;
    if (topic != null) _activeTopic = topic;
    if (mode != null) _activeMode = mode;
    _isBackgroundProcessing = true;
    _state = ResultsLoadState.loading;
    _errorMessage = null;
    _pollStartTime = DateTime.now();
    _currentInterval = AppConfig.resultsPollInitialInterval;
    notifyListeners();
    _startPolling(sessionId);
  }

  /// Re-runs server-side analysis for a failed session, then resumes polling.
  Future<void> retry(String sessionId) async {
    if (_state == ResultsLoadState.failed) {
      try {
        await _repo.retryAnalysis(sessionId);
      } catch (_) {
        _errorMessage = 'Could not restart the analysis. Please try again.';
        notifyListeners();
        return;
      }
    }
    _errorMessage = null;
    loadSession(sessionId, forceRefresh: true);
  }

  void _startPolling(String sessionId) {
    _pollTimer?.cancel();

    // Check timeout
    if (_pollStartTime != null &&
        DateTime.now().difference(_pollStartTime!) >
            AppConfig.resultsPollTimeout) {
      _state = ResultsLoadState.error;
      _errorMessage = 'Analysis timed out. Tap retry to check again.';
      notifyListeners();
      return;
    }

    _pollTimer = Timer(_currentInterval, () async {
      if (_disposed) return;

      try {
        final session = await _repo.getSession(sessionId);
        _result = session;

        if (session.isAnalyzed) {
          _isBackgroundProcessing = false;
          try {
            await _storage.delete(key: _storageActiveSessionKey);
          } catch (_) {}

          _repo.cacheSession(session);

          // Update local SQLite db with full analyzed scores
          if (LocalDatabaseService.instance.isOpen) {
            try {
              final userId =
                  LocalDatabaseService.instance.currentUserId ?? 'user';
              await LocalDatabaseService.instance.upsertSessionMetric({
                'id': session.id,
                'user_id': userId,
                'mode': session.mode,
                'topic_or_question': session.topicOrQuestion,
                'duration_seconds': session.durationSeconds,
                'wpm': session.wpm,
                'filler_word_count': session.fillerWordCount,
                'pause_count': session.pauseCount,
                'avg_pause_length': session.avgPauseLength,
                'clarity_score': session.clarityScore,
                'confidence_score': session.confidenceScore,
                'overall_score': session.overallScore,
                'status': session.analysisFailed ? 'failed' : 'analyzed',
                'created_at': session.createdAt.toUtc().toIso8601String(),
                'local_date':
                    session.localDate ??
                    DateTime.now().toIso8601String().substring(0, 10),
                'tz_offset_minutes': session.tzOffsetMinutes ?? 0,
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              });
            } catch (e) {
              debugPrint('[SessionResultsProvider] Error updating SQLite: $e');
            }
          }

          if (session.analysisFailed) {
            _state = ResultsLoadState.failed;
            _errorMessage =
                session.failureReason ?? 'Analysis could not be completed.';
          } else {
            _state = ResultsLoadState.ready;
            _completedSessionToAnnounce = session;

            // Automatically check and complete targeted drills (Feature 6)
            try {
              unawaited(
                PracticePlanRepository.instance.evaluateSessionAgainstDrills(
                  durationSeconds: session.durationSeconds.toDouble(),
                  wpm: session.wpm.toDouble(),
                  fillerCount: session.fillerWordCount,
                  pauseCount: session.pauseCount,
                  sessionId: session.id,
                ),
              );
            } catch (_) {}

            // Trigger instant phone notification
            try {
              await NotificationService.instance.showInstantNotification(
                'Practice Session Ready',
                'Your ${session.modeLabel} feedback for "${session.topicOrQuestion}" is ready with score ${session.overallScore.round()}%.',
              );
            } catch (e) {
              debugPrint('Failed to send instant notification: $e');
            }
          }
          notifyListeners();
          return;
        } else {
          _state = ResultsLoadState.analyzing;
          notifyListeners();
        }
      } catch (_) {
        // Transient network error: continue backoff polling without breaking
      }

      if (_disposed) return;

      // Exponential backoff: multiply interval by 1.5 up to max interval
      final nextMs = min(
        AppConfig.resultsPollMaxInterval.inMilliseconds,
        (_currentInterval.inMilliseconds * 1.5).round(),
      );
      _currentInterval = Duration(milliseconds: nextMs);

      _startPolling(sessionId);
    });
  }

  /// Cancels polling, clears in-memory session results, and removes persisted processing session id.
  Future<void> reset() async {
    _pollTimer?.cancel();
    _result = null;
    _state = ResultsLoadState.loading;
    _errorMessage = null;
    _activeSessionId = null;
    _activeTopic = null;
    _activeMode = null;
    _isBackgroundProcessing = false;
    _completedSessionToAnnounce = null;
    try {
      await _storage.delete(key: _storageActiveSessionKey);
    } catch (_) {}
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    super.dispose();
  }
}
