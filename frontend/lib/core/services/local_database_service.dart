import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/stats_models.dart';
import '../models/session_result.dart';

/// Local SQLite service for offline-first metrics, achievements, and sync outbox.
/// Each user has an isolated SQLite database file: pitch_coach_{user_id}.db.
class LocalDatabaseService {
  LocalDatabaseService._();
  static final LocalDatabaseService instance = LocalDatabaseService._();

  static bool _ffiInitialized = false;

  Database? _db;
  String? _currentUserId;

  Database get db {
    if (_db == null || !_db!.isOpen) {
      throw StateError(
        'LocalDatabaseService is not initialized. Call initForUser first.',
      );
    }
    return _db!;
  }

  bool get isOpen => _db != null && _db!.isOpen;
  String? get currentUserId => _currentUserId;

  /// Ensures SQLite FFI is initialized on desktop / test environments.
  static void ensureFfiInitialized() {
    if (!_ffiInitialized) {
      if (!kIsWeb &&
          (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }
      _ffiInitialized = true;
    }
  }

  /// Initializes or switches the database for the given user.
  /// If the database for another user is currently open, it is closed first.
  Future<Database> initForUser(String userId) async {
    ensureFfiInitialized();
    final sanitizedUserId = userId.isEmpty
        ? 'guest'
        : userId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

    if (_db != null && _db!.isOpen) {
      if (_currentUserId == sanitizedUserId) {
        return _db!;
      }
      await close();
    }

    _currentUserId = sanitizedUserId;
    final dbPath = await _resolveDbPath('pitch_coach_$sanitizedUserId.db');

    _db = await openDatabase(
      dbPath,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: (db, version) async {
        await _applyMigrations(db, 0, version);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _applyMigrations(db, oldVersion, newVersion);
      },
    );

    return _db!;
  }

  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }

  /// Permanently deletes the local SQLite database for the given user,
  /// removing all session metrics, fillers, achievements, sync outbox rows, and cursors.
  Future<void> wipeUserData(String userId) async {
    ensureFfiInitialized();
    final sanitizedUserId = userId.isEmpty
        ? 'guest'
        : userId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

    if (_db != null && _db!.isOpen) {
      if (_currentUserId == sanitizedUserId) {
        await close();
      }
    }

    final dbPath = await _resolveDbPath('pitch_coach_$sanitizedUserId.db');
    try {
      await deleteDatabase(dbPath);
      debugPrint('[LocalDatabaseService] Successfully wiped local DB: $dbPath');
    } catch (e) {
      debugPrint('[LocalDatabaseService] Notice during deleteDatabase for $dbPath: $e');
    }

    if (_currentUserId == sanitizedUserId) {
      _currentUserId = null;
    }
  }

  /// Wipes all local SQLite databases (the user's DB and any guest DB).
  Future<void> wipeAllLocalDatabases(String userId) async {
    await wipeUserData(userId);
    await wipeUserData('guest');
    await close();
    _currentUserId = null;

    final foldersToCheck = <String>[];
    try {
      foldersToCheck.add(await getDatabasesPath());
    } catch (_) {}
    try {
      final docs = await getApplicationDocumentsDirectory();
      foldersToCheck.add(docs.path);
    } catch (_) {}

    for (final folder in foldersToCheck) {
      try {
        final dir = Directory(folder);
        if (await dir.exists()) {
          final entities = dir.listSync();
          for (final entity in entities) {
            if (entity is File) {
              final name = p.basename(entity.path);
              if (name.startsWith('pitch_coach_')) {
                try {
                  await entity.delete();
                } catch (_) {}
              }
            }
          }
        }
      } catch (_) {}
    }
  }

  Future<String> _resolveDbPath(String fileName) async {
    try {
      final dbFolder = await getDatabasesPath();
      return p.join(dbFolder, fileName);
    } catch (_) {
      final docs = await getApplicationDocumentsDirectory();
      return p.join(docs.path, fileName);
    }
  }

  static Future<void> _applyMigrations(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 1) {
      await _migrationV1(db);
    }
  }

  static Future<void> _migrationV1(Database db) async {
    final batch = db.batch();

    // 1. session_metrics
    batch.execute('''
      CREATE TABLE IF NOT EXISTS session_metrics (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        mode TEXT NOT NULL DEFAULT 'interview',
        topic_or_question TEXT NOT NULL,
        duration_seconds REAL NOT NULL DEFAULT 0,
        wpm REAL NOT NULL DEFAULT 0,
        filler_word_count INTEGER NOT NULL DEFAULT 0,
        pause_count INTEGER NOT NULL DEFAULT 0,
        avg_pause_length REAL NOT NULL DEFAULT 0,
        clarity_score REAL NOT NULL DEFAULT 0,
        confidence_score REAL NOT NULL DEFAULT 0,
        overall_score REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL,
        local_date TEXT NOT NULL,
        tz_offset_minutes INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      );
    ''');
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_sm_user_date ON session_metrics(user_id, local_date DESC);',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_sm_user_updated ON session_metrics(user_id, updated_at, id);',
    );

    // 2. session_fillers
    batch.execute('''
      CREATE TABLE IF NOT EXISTS session_fillers (
        session_id TEXT NOT NULL,
        filler_word TEXT NOT NULL,
        count INTEGER NOT NULL DEFAULT 1,
        PRIMARY KEY (session_id, filler_word),
        FOREIGN KEY (session_id) REFERENCES session_metrics(id) ON DELETE CASCADE
      );
    ''');

    // 3. achievement_catalog
    batch.execute('''
      CREATE TABLE IF NOT EXISTS achievement_catalog (
        key TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        icon_name TEXT NOT NULL,
        category TEXT NOT NULL
      );
    ''');

    // Seed achievement_catalog
    batch.execute('''
      INSERT OR IGNORE INTO achievement_catalog (key, title, description, icon_name, category) VALUES
      ('first_session', 'First Step', 'Complete your first practice session.', 'mic', 'milestone'),
      ('7_day_streak', '7-Day Streak', 'Practice 7 days in a row.', 'fire', 'streak'),
      ('50_sessions', '50 Sessions', 'Complete 50 practice sessions.', 'target', 'milestone'),
      ('clarity_master', 'Clarity Master', 'Achieve a clarity score ≥ 85% in any session.', 'diamond', 'skill'),
      ('early_bird', 'Early Bird', 'Complete a session before 8:00 AM.', 'sunrise', 'habit');
    ''');
    batch.execute('''
      UPDATE achievement_catalog SET icon_name = 'mic' WHERE key = 'first_session';
      UPDATE achievement_catalog SET icon_name = 'fire' WHERE key = '7_day_streak';
      UPDATE achievement_catalog SET icon_name = 'target' WHERE key = '50_sessions';
      UPDATE achievement_catalog SET icon_name = 'diamond' WHERE key = 'clarity_master';
      UPDATE achievement_catalog SET icon_name = 'sunrise' WHERE key = 'early_bird';
    ''');

    // 4. user_achievements
    batch.execute('''
      CREATE TABLE IF NOT EXISTS user_achievements (
        user_id TEXT NOT NULL,
        achievement_key TEXT NOT NULL,
        unlocked_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (user_id, achievement_key),
        FOREIGN KEY (achievement_key) REFERENCES achievement_catalog(key)
      );
    ''');

    // 5. sync_outbox (local SQLite only)
    batch.execute('''
      CREATE TABLE IF NOT EXISTS sync_outbox (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        action TEXT NOT NULL,
        payload TEXT NOT NULL,
        local_audio_path TEXT,
        state TEXT NOT NULL DEFAULT 'queued',
        retry_count INTEGER NOT NULL DEFAULT 0,
        next_attempt_at TEXT,
        last_error TEXT,
        created_at TEXT NOT NULL
      );
    ''');

    // 6. sync_state (local SQLite only)
    batch.execute('''
      CREATE TABLE IF NOT EXISTS sync_state (
        user_id TEXT PRIMARY KEY,
        last_cursor_updated_at TEXT,
        last_cursor_id TEXT
      );
    ''');

    await batch.commit(noResult: true);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Session Metrics DAO
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> upsertSessionMetric(Map<String, dynamic> row) async {
    await db.rawInsert(
      '''
      INSERT INTO session_metrics (
        id, user_id, mode, topic_or_question, duration_seconds, wpm,
        filler_word_count, pause_count, avg_pause_length, clarity_score,
        confidence_score, overall_score, status, created_at, local_date,
        tz_offset_minutes, updated_at, deleted_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        user_id = excluded.user_id,
        mode = excluded.mode,
        topic_or_question = excluded.topic_or_question,
        duration_seconds = excluded.duration_seconds,
        wpm = excluded.wpm,
        filler_word_count = excluded.filler_word_count,
        pause_count = excluded.pause_count,
        avg_pause_length = excluded.avg_pause_length,
        clarity_score = excluded.clarity_score,
        confidence_score = excluded.confidence_score,
        overall_score = excluded.overall_score,
        status = excluded.status,
        created_at = excluded.created_at,
        local_date = excluded.local_date,
        tz_offset_minutes = excluded.tz_offset_minutes,
        updated_at = excluded.updated_at,
        deleted_at = excluded.deleted_at;
    ''',
      [
        row['id'],
        row['user_id'],
        row['mode'] ?? 'interview',
        row['topic_or_question'] ?? '',
        (row['duration_seconds'] as num?)?.toDouble() ?? 0.0,
        (row['wpm'] as num?)?.toDouble() ?? 0.0,
        (row['filler_word_count'] as num?)?.toInt() ?? 0,
        (row['pause_count'] as num?)?.toInt() ?? 0,
        (row['avg_pause_length'] as num?)?.toDouble() ?? 0.0,
        (row['clarity_score'] as num?)?.toDouble() ?? 0.0,
        (row['confidence_score'] as num?)?.toDouble() ?? 0.0,
        (row['overall_score'] as num?)?.toDouble() ?? 0.0,
        row['status'] ?? 'pending',
        row['created_at'],
        row['local_date'],
        (row['tz_offset_minutes'] as num?)?.toInt() ?? 0,
        row['updated_at'] ?? DateTime.now().toUtc().toIso8601String(),
        row['deleted_at'],
      ],
    );
  }

  Future<void> softDeleteSession(
    String id,
    String deletedAt, {
    String? updatedAt,
  }) async {
    final updated = updatedAt ?? DateTime.now().toUtc().toIso8601String();
    await db.rawUpdate(
      '''
      UPDATE session_metrics
      SET deleted_at = ?, updated_at = ?
      WHERE id = ?;
    ''',
      [deletedAt, updated, id],
    );
  }

  Future<SessionSummary?> getRecentSession(String userId) async {
    final rows = await db.rawQuery(
      '''
      SELECT * FROM session_metrics
      WHERE user_id = ? AND deleted_at IS NULL
      ORDER BY created_at DESC
      LIMIT 1;
    ''',
      [userId],
    );

    if (rows.isEmpty) return null;
    return _mapRowToSessionSummary(rows.first);
  }

  Future<List<SessionSummary>> getSessionSummaries(
    String userId, {
    String? mode,
    int limit = 20,
    int offset = 0,
  }) async {
    String sql = '''
      SELECT * FROM session_metrics
      WHERE user_id = ? AND deleted_at IS NULL
    ''';
    final params = <dynamic>[userId];

    if (mode != null && mode != 'All' && mode.isNotEmpty) {
      sql += ' AND mode = ?';
      params.add(mode.toLowerCase());
    }

    sql += ' ORDER BY created_at DESC LIMIT ? OFFSET ?;';
    params.add(limit);
    params.add(offset);

    final rows = await db.rawQuery(sql, params);
    return rows.map(_mapRowToSessionSummary).toList();
  }

  SessionSummary _mapRowToSessionSummary(Map<String, dynamic> r) {
    final status = r['status'] as String? ?? 'pending';
    return SessionSummary(
      id: r['id'] as String,
      mode: r['mode'] as String? ?? 'interview',
      topicOrQuestion: r['topic_or_question'] as String? ?? '',
      durationSeconds: (r['duration_seconds'] as num?)?.toDouble() ?? 0.0,
      overallScore: (r['overall_score'] as num?)?.toDouble() ?? 0.0,
      confidenceScore: (r['confidence_score'] as num?)?.toDouble() ?? 0.0,
      createdAt:
          DateTime.tryParse(r['created_at'] as String? ?? '') ?? DateTime.now(),
      localDate: r['local_date'] as String?,
      tzOffsetMinutes: (r['tz_offset_minutes'] as num?)?.toInt(),
      isAnalyzed: status == 'analyzed',
      analysisFailed: status == 'failed',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Session Fillers DAO
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> replaceFillers(
    String sessionId,
    List<Map<String, dynamic>> fillers,
  ) async {
    await db.transaction((txn) async {
      await txn.rawDelete('DELETE FROM session_fillers WHERE session_id = ?;', [
        sessionId,
      ]);
      for (final f in fillers) {
        await txn.rawInsert(
          '''
          INSERT OR REPLACE INTO session_fillers (session_id, filler_word, count)
          VALUES (?, ?, ?);
        ''',
          [
            sessionId,
            f['filler_word'] as String,
            (f['count'] as num?)?.toInt() ?? 1,
          ],
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> getTopFillers(
    String userId, {
    int limit = 5,
  }) async {
    return db.rawQuery(
      '''
      SELECT f.filler_word, SUM(f.count) AS total_count
      FROM session_fillers f
      JOIN session_metrics m ON f.session_id = m.id
      WHERE m.user_id = ? AND m.status = 'analyzed' AND m.deleted_at IS NULL
      GROUP BY f.filler_word
      ORDER BY total_count DESC
      LIMIT ?;
    ''',
      [userId, limit],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // User Achievements DAO
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> upsertUserAchievement(
    String userId,
    String key,
    String unlockedAt,
    String updatedAt,
  ) async {
    await db.rawInsert(
      '''
      INSERT INTO user_achievements (user_id, achievement_key, unlocked_at, updated_at)
      VALUES (?, ?, ?, ?)
      ON CONFLICT(user_id, achievement_key) DO UPDATE SET
        unlocked_at = excluded.unlocked_at,
        updated_at = excluded.updated_at;
    ''',
      [userId, key, unlockedAt, updatedAt],
    );
  }

  Future<List<Achievement>> getUserAchievements(String userId) async {
    final rows = await db.rawQuery(
      '''
      SELECT c.key, c.title, c.description, c.icon_name, c.category,
             ua.unlocked_at, ua.updated_at,
             CASE WHEN ua.achievement_key IS NOT NULL THEN 1 ELSE 0 END AS is_unlocked
      FROM achievement_catalog c
      LEFT JOIN user_achievements ua
        ON c.key = ua.achievement_key AND ua.user_id = ?
      ORDER BY c.key ASC;
    ''',
      [userId],
    );

    return rows.map((r) {
      final unlocked = (r['is_unlocked'] as int? ?? 0) == 1;
      final unlockedStr = r['unlocked_at'] as String?;
      return Achievement(
        key: r['key'] as String? ?? '',
        title: r['title'] as String? ?? '',
        icon: r['icon_name'] as String? ?? 'trophy',
        isUnlocked: unlocked,
        unlockedAt: (unlocked && unlockedStr != null)
            ? DateTime.tryParse(unlockedStr)
            : null,
        description: r['description'] as String? ?? '',
      );
    }).toList();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Sync State DAO
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, String?>> getSyncCursor(String userId) async {
    final rows = await db.rawQuery(
      '''
      SELECT last_cursor_updated_at, last_cursor_id
      FROM sync_state
      WHERE user_id = ?;
    ''',
      [userId],
    );

    if (rows.isEmpty) {
      return {'cursor_updated_at': null, 'cursor_id': null};
    }
    return {
      'cursor_updated_at': rows.first['last_cursor_updated_at'] as String?,
      'cursor_id': rows.first['last_cursor_id'] as String?,
    };
  }

  Future<void> setSyncCursor(
    String userId,
    String? cursorUpdatedAt,
    String? cursorId,
  ) async {
    await db.rawInsert(
      '''
      INSERT INTO sync_state (user_id, last_cursor_updated_at, last_cursor_id)
      VALUES (?, ?, ?)
      ON CONFLICT(user_id) DO UPDATE SET
        last_cursor_updated_at = excluded.last_cursor_updated_at,
        last_cursor_id = excluded.last_cursor_id;
    ''',
      [userId, cursorUpdatedAt, cursorId],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Sync Outbox DAO (Offline support)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> enqueueOutbox({
    required String id,
    required String userId,
    required String action,
    required String payload,
    String? localAudioPath,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await db.rawInsert(
      '''
      INSERT OR REPLACE INTO sync_outbox (
        id, user_id, action, payload, local_audio_path, state, retry_count, next_attempt_at, last_error, created_at
      ) VALUES (?, ?, ?, ?, ?, 'queued', 0, NULL, NULL, ?);
    ''',
      [id, userId, action, payload, localAudioPath, now],
    );
  }

  Future<List<Map<String, dynamic>>> getPendingOutbox(String userId) async {
    return db.rawQuery(
      '''
      SELECT * FROM sync_outbox
      WHERE user_id = ? AND state != 'done'
      ORDER BY created_at ASC;
    ''',
      [userId],
    );
  }

  Future<void> updateOutboxState({
    required String id,
    required String state,
    int? retryCount,
    String? nextAttemptAt,
    String? lastError,
  }) async {
    await db.rawUpdate(
      '''
      UPDATE sync_outbox
      SET state = ?,
          retry_count = COALESCE(?, retry_count),
          next_attempt_at = ?,
          last_error = ?
      WHERE id = ?;
    ''',
      [state, retryCount, nextAttemptAt, lastError, id],
    );
  }

  Future<void> deleteOutbox(String id) async {
    await db.rawDelete('DELETE FROM sync_outbox WHERE id = ?;', [id]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Dashboard Queries (Offline-first metrics reading)
  // ─────────────────────────────────────────────────────────────────────────

  /// Computes summary strictly from local SQLite.
  Future<StatsSummary> getSummary(
    String userId, {
    int tzOffsetMinutes = 330,
  }) async {
    final summaryRows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS total_sessions,
             ROUND(AVG(overall_score), 1) AS avg_score,
             ROUND(AVG(wpm), 1) AS avg_wpm,
             ROUND(AVG(clarity_score), 1) AS avg_clarity,
             ROUND(AVG(confidence_score), 1) AS avg_confidence,
             ROUND(SUM(duration_seconds), 1) AS total_duration
      FROM session_metrics
      WHERE user_id = ? AND status = 'analyzed' AND deleted_at IS NULL;
    ''',
      [userId],
    );

    final totalSessions =
        (summaryRows.first['total_sessions'] as num?)?.toInt() ?? 0;
    final avgConfidence =
        (summaryRows.first['avg_confidence'] as num?)?.toDouble() ?? 0.0;
    final avgScore =
        (summaryRows.first['avg_score'] as num?)?.toDouble() ?? 0.0;
    final avgWpm = (summaryRows.first['avg_wpm'] as num?)?.toDouble() ?? 0.0;
    final avgClarity =
        (summaryRows.first['avg_clarity'] as num?)?.toDouble() ?? 0.0;
    final totalDuration =
        (summaryRows.first['total_duration'] as num?)?.toDouble() ?? 0.0;

    if (totalSessions == 0) {
      return StatsSummary.empty;
    }

    // Streak calculation using local dates
    final nowLocal = DateTime.now().toUtc().add(
      Duration(minutes: tzOffsetMinutes),
    );
    final todayStr = _formatDate(nowLocal);
    final yesterdayStr = _formatDate(
      nowLocal.subtract(const Duration(days: 1)),
    );

    final streak = await getStreak(userId, todayStr, yesterdayStr);

    // Filler reduction percentage
    final fillerRows = await db.rawQuery(
      '''
      WITH ordered AS (
        SELECT filler_word_count,
               ROW_NUMBER() OVER (ORDER BY created_at ASC) AS rn,
               COUNT(*) OVER () AS total_count
        FROM session_metrics
        WHERE user_id = ? AND status = 'analyzed' AND deleted_at IS NULL
      )
      SELECT
        AVG(CASE WHEN rn <= total_count / 2 THEN filler_word_count END) AS first_half_avg,
        AVG(CASE WHEN rn > total_count / 2 THEN filler_word_count END) AS second_half_avg
      FROM ordered;
    ''',
      [userId],
    );

    double fillerReduction = 0.0;
    if (fillerRows.isNotEmpty && fillerRows.first['first_half_avg'] != null) {
      final firstAvg =
          (fillerRows.first['first_half_avg'] as num?)?.toDouble() ?? 0.0;
      final secondAvg =
          (fillerRows.first['second_half_avg'] as num?)?.toDouble() ?? 0.0;
      if (firstAvg > 0) {
        fillerReduction =
            ((firstAvg - secondAvg) / firstAvg * 100.0 * 10).round() / 10.0;
      }
    }

    return StatsSummary(
      totalSessions: totalSessions,
      avgConfidence: avgConfidence,
      streakDays: streak,
      fillerReductionPct: fillerReduction,
      avgScore: avgScore,
      avgWpm: avgWpm,
      avgClarity: avgClarity,
      totalDuration: totalDuration,
    );
  }

  /// 30-day or 7-day trend query grouped by local_date.
  Future<List<TrendPoint>> getTrend(
    String userId, {
    int days = 7,
    int tzOffsetMinutes = 330,
    DateTime? asOf,
  }) async {
    final nowLocal = (asOf ?? DateTime.now()).toUtc().add(
      Duration(minutes: tzOffsetMinutes),
    );
    final cutoffDate = _formatDate(nowLocal.subtract(Duration(days: days)));

    final rows = await db.rawQuery(
      '''
      SELECT local_date,
             ROUND(AVG(overall_score), 1) AS score,
             ROUND(AVG(wpm), 1) AS wpm,
             ROUND(AVG(clarity_score), 1) AS clarity,
             ROUND(AVG(confidence_score), 1) AS confidence,
             COUNT(*) AS session_count
      FROM session_metrics
      WHERE user_id = ? AND status = 'analyzed' AND deleted_at IS NULL AND local_date >= ?
      GROUP BY local_date
      ORDER BY local_date ASC;
    ''',
      [userId, cutoffDate],
    );

    return rows.map((r) {
      return TrendPoint(
        date: r['local_date'] as String? ?? '',
        confidence:
            (r['confidence'] as num?)?.toDouble() ??
            (r['score'] as num?)?.toDouble() ??
            0.0,
      );
    }).toList();
  }

  /// Calculates current active streak from local SQLite.
  Future<int> getStreak(
    String userId,
    String todayStr,
    String yesterdayStr,
  ) async {
    final rows = await db.rawQuery(
      '''
      WITH d AS (
        SELECT DISTINCT local_date FROM session_metrics
        WHERE user_id = ? AND deleted_at IS NULL AND status = 'analyzed'
      ), g AS (
        SELECT local_date, julianday(local_date) - ROW_NUMBER() OVER (ORDER BY local_date) AS grp FROM d
      )
      SELECT COUNT(*) AS streak, MAX(local_date) AS last_day
      FROM g GROUP BY grp ORDER BY last_day DESC LIMIT 1;
    ''',
      [userId],
    );

    if (rows.isEmpty) return 0;
    final lastDay = rows.first['last_day'] as String?;
    final streak = (rows.first['streak'] as num?)?.toInt() ?? 0;

    if (lastDay == todayStr || lastDay == yesterdayStr) {
      return streak;
    }
    return 0;
  }

  static String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
