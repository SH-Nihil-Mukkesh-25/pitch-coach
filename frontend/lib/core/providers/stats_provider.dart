import 'dart:async';
import 'package:flutter/material.dart';
import '../models/stats_models.dart';
import '../repositories/stats_repository.dart';
import '../repositories/demo_repository.dart';
import '../services/local_database_service.dart';
import '../services/sync_service.dart';

enum StatsLoadState { idle, loading, ready, error }

/// Holds stats summary, trend chart data, skill breakdown, and achievements.
///
/// Offline-first design:
/// - Reads immediately from local SQLite.
/// - Network pull sync refreshes local SQLite in background.
/// - Automatically updates when SyncService finishes pull.
class StatsProvider extends ChangeNotifier {
  final _repo = StatsRepository.instance;
  final _localDb = LocalDatabaseService.instance;
  final _sync = SyncService.instance;
  StreamSubscription<String>? _syncSub;

  StatsSummary _summary = StatsSummary.empty;
  List<TrendPoint> _trend = [];
  SkillBreakdown _skills = SkillBreakdown.empty;
  List<Achievement> _achievements = [];
  StatsLoadState _state = StatsLoadState.idle;
  String? _error;
  DateTime? _lastLoaded;

  StatsProvider() {
    _syncSub = _sync.onSyncCompleted.listen((userId) {
      if (_localDb.isOpen && _localDb.currentUserId == userId) {
        _reloadFromLocalDb(userId);
      }
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  StatsSummary get summary => _summary;
  List<TrendPoint> get trend => _trend;
  SkillBreakdown get skills => _skills;
  List<Achievement> get achievements => _achievements;
  StatsLoadState get state => _state;
  String? get error => _error;
  DateTime? get lastLoaded => _lastLoaded;
  bool get isLoading => _state == StatsLoadState.loading;
  bool get hasData => _state == StatsLoadState.ready;

  Future<void> _reloadFromLocalDb(
    String userId, {
    String trendRange = 'week',
  }) async {
    try {
      final summary = await _localDb.getSummary(userId);
      final trend = await _localDb.getTrend(
        userId,
        days: trendRange == 'week' ? 7 : 30,
      );
      final achievements = await _localDb.getUserAchievements(userId);

      _summary = summary;
      _trend = trend;
      if (achievements.isNotEmpty) {
        _achievements = achievements;
      }
      _state = StatsLoadState.ready;
      _lastLoaded = DateTime.now();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadAll({
    String trendRange = 'week',
    bool force = false,
    String? userId,
  }) async {
    final effectiveUserId = userId ?? _localDb.currentUserId;

    // Guest mode
    if (effectiveUserId == null ||
        effectiveUserId == 'guest' ||
        effectiveUserId == 'demo-guest') {
      loadDemo();
      return;
    }

    // 1. Instant load from local SQLite
    if (_localDb.isOpen && _localDb.currentUserId == effectiveUserId) {
      try {
        final localSummary = await _localDb.getSummary(effectiveUserId);
        final localTrend = await _localDb.getTrend(
          effectiveUserId,
          days: trendRange == 'week' ? 7 : 30,
        );
        final localAchievements = await _localDb.getUserAchievements(
          effectiveUserId,
        );

        if (localSummary.totalSessions > 0 || localAchievements.isNotEmpty) {
          _summary = localSummary;
          _trend = localTrend;
          _achievements = localAchievements;
          _state = StatsLoadState.ready;
          notifyListeners();
        }
      } catch (e) {
        debugPrint('[StatsProvider] Error loading from local SQLite: $e');
      }
    }

    // Only set loading if we don't already have ready data
    if (_state != StatsLoadState.ready) {
      _state = StatsLoadState.loading;
      notifyListeners();
    }

    // 2. Refresh via pull sync and fetch remote skills breakdown
    try {
      // Trigger background pull sync
      _sync
          .pull(userId: effectiveUserId)
          .then((_) {
            if (_localDb.isOpen && _localDb.currentUserId == effectiveUserId) {
              _reloadFromLocalDb(effectiveUserId, trendRange: trendRange);
            }
          })
          .catchError((_) {});

      // Fetch skills from API (as skills are computed on backend)
      final skills = await _repo.getSkills();
      _skills = skills;
      _error = null;
      _lastLoaded = DateTime.now();
    } catch (e) {
      if (_state != StatsLoadState.ready) {
        _state = StatsLoadState.error;
        _error = e.toString();
      }
    }
    notifyListeners();
  }

  Future<void> loadSummaryOnly({bool force = false, String? userId}) async {
    final effectiveUserId = userId ?? _localDb.currentUserId;
    if (effectiveUserId == null ||
        effectiveUserId == 'guest' ||
        effectiveUserId == 'demo-guest') {
      return;
    }

    // 1. Read immediately from local SQLite
    if (_localDb.isOpen && _localDb.currentUserId == effectiveUserId) {
      try {
        final localSummary = await _localDb.getSummary(effectiveUserId);
        if (localSummary.totalSessions > 0) {
          _summary = localSummary;
          _state = StatsLoadState.ready;
          notifyListeners();
        }
      } catch (_) {}
    }

    // 2. Trigger pull sync in background
    _sync
        .pull(userId: effectiveUserId)
        .then((_) async {
          if (_localDb.isOpen && _localDb.currentUserId == effectiveUserId) {
            final refreshed = await _localDb.getSummary(effectiveUserId);
            _summary = refreshed;
            _lastLoaded = DateTime.now();
            notifyListeners();
          }
        })
        .catchError((_) {});
  }

  void loadDemo() {
    final demo = DemoRepository.instance;
    _summary = demo.summary;
    _trend = demo.trend;
    _skills = demo.skills;
    _achievements = [];
    _state = StatsLoadState.ready;
    _error = null;
    _lastLoaded = DateTime.now();
    notifyListeners();
  }

  /// Clears in-memory stats, trend, skills, and achievements.
  void reset() {
    _summary = StatsSummary.empty;
    _trend = [];
    _skills = SkillBreakdown.empty;
    _achievements = [];
    _state = StatsLoadState.idle;
    _error = null;
    _lastLoaded = null;
    notifyListeners();
  }
}
