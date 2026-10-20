import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pitch_coach/core/services/local_database_service.dart';

void main() {
  late String testId;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    testId = 'u_${DateTime.now().microsecondsSinceEpoch}';
  });

  tearDown(() async {
    await LocalDatabaseService.instance.close();
  });

  group('Phase 3: Local SQLite & DAOs', () {
    test(
      'Initializes DB with PRAGMA user_version = 1 and seeds achievements',
      () async {
        final service = LocalDatabaseService.instance;
        final db = await service.initForUser(testId);

        final versionResult = await db.rawQuery('PRAGMA user_version;');
        final version = versionResult.first.values.first as int;
        expect(version, 1);

        // Check achievement catalog seeded
        final catalogRows = await db.rawQuery(
          'SELECT * FROM achievement_catalog ORDER BY key ASC;',
        );
        expect(catalogRows.length, 5);
        expect(catalogRows.any((r) => r['key'] == 'first_session'), isTrue);
        expect(catalogRows.any((r) => r['key'] == '7_day_streak'), isTrue);
        expect(catalogRows.any((r) => r['key'] == '50_sessions'), isTrue);
        expect(catalogRows.any((r) => r['key'] == 'clarity_master'), isTrue);
        expect(catalogRows.any((r) => r['key'] == 'early_bird'), isTrue);
      },
    );

    test('Upserts session_metrics and replaces fillers idempotently', () async {
      final service = LocalDatabaseService.instance;
      await service.initForUser(testId);

      final session1 = {
        'id': 'sess-100',
        'user_id': testId,
        'mode': 'interview',
        'topic_or_question': 'Tell me about yourself',
        'duration_seconds': 60.0,
        'wpm': 130.0,
        'filler_word_count': 3,
        'pause_count': 2,
        'avg_pause_length': 1.0,
        'clarity_score': 85.0,
        'confidence_score': 80.0,
        'overall_score': 82.5,
        'status': 'analyzed',
        'created_at': '2026-10-08T10:00:00Z',
        'local_date': '2026-10-08',
        'tz_offset_minutes': 330,
        'updated_at': '2026-10-08T10:05:00Z',
      };

      await service.upsertSessionMetric(session1);
      await service.replaceFillers('sess-100', [
        {'filler_word': 'um', 'count': 2},
        {'filler_word': 'like', 'count': 1},
      ]);

      // Verify inserted
      final recent = await service.getRecentSession(testId);
      expect(recent, isNotNull);
      expect(recent!.id, 'sess-100');
      expect(recent.overallScore, 82.5);

      // Verify idempotent update
      final session1Updated = Map<String, dynamic>.from(session1);
      session1Updated['overall_score'] = 90.0;
      await service.upsertSessionMetric(session1Updated);

      final updatedRecent = await service.getRecentSession(testId);
      expect(updatedRecent!.overallScore, 90.0);

      // Check top fillers
      final topFillers = await service.getTopFillers(testId);
      expect(topFillers.length, 2);
      expect(topFillers.first['filler_word'], 'um');
      expect(topFillers.first['total_count'], 2);
    });

    test(
      'Computes summary, 30-day trend, and streak strictly from local SQLite',
      () async {
        final service = LocalDatabaseService.instance;
        await service.initForUser(testId);

        // Insert 2 sessions on consecutive days
        await service.upsertSessionMetric({
          'id': 'sess-day1',
          'user_id': testId,
          'mode': 'interview',
          'topic_or_question': 'Q1',
          'duration_seconds': 60.0,
          'wpm': 120.0,
          'filler_word_count': 4,
          'pause_count': 1,
          'avg_pause_length': 1.0,
          'clarity_score': 80.0,
          'confidence_score': 75.0,
          'overall_score': 78.0,
          'status': 'analyzed',
          'created_at': '2026-10-08T09:00:00Z',
          'local_date': '2026-10-08',
          'tz_offset_minutes': 330,
          'updated_at': '2026-10-08T09:05:00Z',
        });

        await service.upsertSessionMetric({
          'id': 'sess-day2',
          'user_id': testId,
          'mode': 'presentation',
          'topic_or_question': 'Q2',
          'duration_seconds': 120.0,
          'wpm': 140.0,
          'filler_word_count': 2,
          'pause_count': 2,
          'avg_pause_length': 0.8,
          'clarity_score': 90.0,
          'confidence_score': 85.0,
          'overall_score': 88.0,
          'status': 'analyzed',
          'created_at': '2026-10-09T09:00:00Z',
          'local_date': '2026-10-09',
          'tz_offset_minutes': 330,
          'updated_at': '2026-10-09T09:05:00Z',
        });

        // Test Summary
        final summary = await service.getSummary(testId);
        expect(summary.totalSessions, 2);
        expect(summary.avgConfidence, 80.0);
        expect(
          summary.fillerReductionPct,
          50.0,
        ); // from 4 to 2 => (4 - 2)/4 = 50%

        // Test Trend
        final trend = await service.getTrend(
          testId,
          days: 7,
          asOf: DateTime.parse('2026-10-09T12:00:00Z'),
        );
        expect(trend.length, 2);
        expect(trend[0].date, '2026-10-08');
        expect(trend[1].date, '2026-10-09');

        // Test Streak (yesterday is 2026-10-08, today is 2026-10-09)
        final streak = await service.getStreak(
          testId,
          '2026-10-09',
          '2026-10-08',
        );
        expect(streak, 2);
      },
    );

    test('Sync outbox and sync state DAOs operate correctly', () async {
      final service = LocalDatabaseService.instance;
      await service.initForUser(testId);

      // Test sync state cursor
      final initialCursor = await service.getSyncCursor(testId);
      expect(initialCursor['cursor_updated_at'], isNull);

      await service.setSyncCursor(testId, '2026-10-09T12:00:00Z', 'sess-999');
      final updatedCursor = await service.getSyncCursor(testId);
      expect(updatedCursor['cursor_updated_at'], '2026-10-09T12:00:00Z');
      expect(updatedCursor['cursor_id'], 'sess-999');

      // Test outbox
      await service.enqueueOutbox(
        id: 'outbox-1',
        userId: testId,
        action: 'CREATE_SESSION',
        payload: '{"mode": "interview"}',
        localAudioPath: '/path/to/audio.m4a',
      );

      var pending = await service.getPendingOutbox(testId);
      expect(pending.length, 1);
      expect(pending.first['action'], 'CREATE_SESSION');
      expect(pending.first['state'], 'queued');

      await service.updateOutboxState(
        id: 'outbox-1',
        state: 'in_flight',
        retryCount: 1,
      );

      pending = await service.getPendingOutbox(testId);
      expect(pending.first['state'], 'in_flight');
      expect(pending.first['retry_count'], 1);

      await service.deleteOutbox('outbox-1');
      pending = await service.getPendingOutbox(testId);
      expect(pending.isEmpty, isTrue);
    });
  });
}
