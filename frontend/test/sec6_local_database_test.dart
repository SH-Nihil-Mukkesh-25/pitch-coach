import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pitch_coach/core/services/local_database_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await LocalDatabaseService.instance.close();
  });

  group('Section 6: Flutter Local Database Verification', () {
    test(
      'DAO queries match the exact Section 3 backend fixtures and expected values',
      () async {
        final service = LocalDatabaseService.instance;
        final userId = 'user_sec6_fixtures';
        await service.initForUser(userId);

        // Seed exact fixtures matching Backend Section 3
        // 4 analyzed active sessions
        await service.upsertSessionMetric({
          'id': 's1',
          'user_id': userId,
          'mode': 'interview',
          'topic_or_question': 'Topic 1',
          'duration_seconds': 60.0,
          'wpm': 140.0,
          'filler_word_count': 2,
          'pause_count': 1,
          'avg_pause_length': 0.5,
          'clarity_score': 90.0,
          'confidence_score': 85.0,
          'overall_score': 90.0,
          'status': 'analyzed',
          'created_at': '2026-10-09T08:00:00Z',
          'local_date': '2026-10-09',
          'tz_offset_minutes': 330,
          'updated_at': '2026-10-09T08:00:00Z',
        });
        await service.replaceFillers('s1', [
          {'filler_word': 'um', 'count': 2},
        ]);

        await service.upsertSessionMetric({
          'id': 's2',
          'user_id': userId,
          'mode': 'interview',
          'topic_or_question': 'Topic 2',
          'duration_seconds': 40.0,
          'wpm': 120.0,
          'filler_word_count': 1,
          'pause_count': 1,
          'avg_pause_length': 0.5,
          'clarity_score': 80.0,
          'confidence_score': 75.0,
          'overall_score': 80.0,
          'status': 'analyzed',
          'created_at': '2026-10-09T14:00:00Z',
          'local_date': '2026-10-09',
          'tz_offset_minutes': 330,
          'updated_at': '2026-10-09T14:00:00Z',
        });
        await service.replaceFillers('s2', [
          {'filler_word': 'like', 'count': 1},
        ]);

        await service.upsertSessionMetric({
          'id': 's3',
          'user_id': userId,
          'mode': 'interview',
          'topic_or_question': 'Topic 3',
          'duration_seconds': 50.0,
          'wpm': 130.0,
          'filler_word_count': 3,
          'pause_count': 1,
          'avg_pause_length': 0.5,
          'clarity_score': 85.0,
          'confidence_score': 80.0,
          'overall_score': 85.0,
          'status': 'analyzed',
          'created_at': '2026-10-08T10:00:00Z',
          'local_date': '2026-10-08',
          'tz_offset_minutes': 330,
          'updated_at': '2026-10-08T10:00:00Z',
        });
        await service.replaceFillers('s3', [
          {'filler_word': 'um', 'count': 3},
        ]);

        await service.upsertSessionMetric({
          'id': 's4',
          'user_id': userId,
          'mode': 'interview',
          'topic_or_question': 'Topic 4',
          'duration_seconds': 30.0,
          'wpm': 110.0,
          'filler_word_count': 2,
          'pause_count': 1,
          'avg_pause_length': 0.5,
          'clarity_score': 70.0,
          'confidence_score': 65.0,
          'overall_score': 70.0,
          'status': 'analyzed',
          'created_at': '2026-10-07T10:00:00Z',
          'local_date': '2026-10-07',
          'tz_offset_minutes': 330,
          'updated_at': '2026-10-07T10:00:00Z',
        });

        // Excluded rows
        await service.upsertSessionMetric({
          'id': 's_failed',
          'user_id': userId,
          'overall_score': 10.0,
          'status': 'failed',
          'created_at': '2026-10-09T11:00:00Z',
          'local_date': '2026-10-09',
          'tz_offset_minutes': 330,
          'updated_at': '2026-10-09T11:00:00Z',
        });
        await service.upsertSessionMetric({
          'id': 's_pending',
          'user_id': userId,
          'overall_score': 10.0,
          'status': 'pending',
          'created_at': '2026-10-09T11:00:00Z',
          'local_date': '2026-10-09',
          'tz_offset_minutes': 330,
          'updated_at': '2026-10-09T11:00:00Z',
        });
        await service.upsertSessionMetric({
          'id': 's_deleted',
          'user_id': userId,
          'overall_score': 10.0,
          'status': 'analyzed',
          'created_at': '2026-10-09T11:00:00Z',
          'local_date': '2026-10-09',
          'tz_offset_minutes': 330,
          'updated_at': '2026-10-09T11:00:00Z',
          'deleted_at': '2026-10-09T12:00:00Z',
        });

        // Assert Summary
        final summary = await service.getSummary(userId);
        expect(summary.totalSessions, 4);
        expect(summary.avgConfidence, 76.3);

        // Assert Streak (3 consecutive days: Oct 7, Oct 8, Oct 9)
        final streak = await service.getStreak(
          userId,
          '2026-10-09',
          '2026-10-08',
        );
        expect(streak, 3);

        // Assert Trend
        final trend = await service.getTrend(
          userId,
          days: 7,
          asOf: DateTime.parse('2026-10-09T12:00:00Z'),
        );
        expect(trend.length, 3);
        expect(trend[0].date, '2026-10-07');
        expect(trend[1].date, '2026-10-08');
        expect(trend[2].date, '2026-10-09');

        // Assert Top Fillers
        final topFillers = await service.getTopFillers(userId);
        expect(topFillers.first['filler_word'], 'um');
        expect(topFillers.first['total_count'], 5); // 2 in s1 + 3 in s3
      },
    );

    test(
      'Rows are scoped strictly by user_id and switching account isolates data',
      () async {
        final service = LocalDatabaseService.instance;
        final userA = 'user_account_a';
        final userB = 'user_account_b';

        // 1. Seed user A
        await service.initForUser(userA);
        await service.upsertSessionMetric({
          'id': 'sess-a',
          'user_id': userA,
          'mode': 'interview',
          'topic_or_question': 'User A secret session',
          'overall_score': 95.0,
          'confidence_score': 90.0,
          'status': 'analyzed',
          'created_at': '2026-10-09T10:00:00Z',
          'local_date': '2026-10-09',
          'tz_offset_minutes': 0,
          'updated_at': '2026-10-09T10:00:00Z',
        });

        final summaryA = await service.getSummary(userA);
        expect(summaryA.totalSessions, 1);

        // 2. Switch to user B
        await service.initForUser(userB);
        final summaryB = await service.getSummary(userB);
        expect(summaryB.totalSessions, 0);

        final recentB = await service.getRecentSession(userB);
        expect(recentB, isNull);

        // 3. Switch back to user A
        await service.initForUser(userA);
        final recentA = await service.getRecentSession(userA);
        expect(recentA, isNotNull);
        expect(recentA!.id, 'sess-a');
      },
    );

    test(
      'Dashboard query operates offline with zero network connection',
      () async {
        final service = LocalDatabaseService.instance;
        final userId = 'user_offline_test';
        await service.initForUser(userId);

        // Running without any network initialised
        final summary = await service.getSummary(userId);
        expect(summary.totalSessions, 0);
        expect(summary.avgConfidence, 0.0);
      },
    );

    test(
      'Account deletion wipes user database and all local records',
      () async {
        final service = LocalDatabaseService.instance;
        const userId = 'user_delete_test';
        await service.initForUser(userId);

        await service.upsertSessionMetric({
          'id': 'sess-delete-1',
          'user_id': userId,
          'mode': 'interview',
          'topic_or_question': 'To be deleted session',
          'overall_score': 88.0,
          'confidence_score': 85.0,
          'status': 'analyzed',
          'created_at': '2026-10-15T10:00:00Z',
          'local_date': '2026-10-15',
          'tz_offset_minutes': 0,
          'updated_at': '2026-10-15T10:00:00Z',
        });
        await service.upsertUserAchievement(
          userId,
          'first_session',
          '2026-10-15T10:00:00Z',
          '2026-10-15T10:00:00Z',
        );

        final initialSummary = await service.getSummary(userId);
        expect(initialSummary.totalSessions, 1);
        final initialAchievements = await service.getUserAchievements(userId);
        expect(initialAchievements.where((a) => a.isUnlocked).length, 1);

        // Perform complete local database wipe
        await service.wipeAllLocalDatabases(userId);

        // Re-open and verify database is clean
        await service.initForUser(userId);
        final wipedSummary = await service.getSummary(userId);
        expect(wipedSummary.totalSessions, 0);
        final wipedAchievements = await service.getUserAchievements(userId);
        expect(wipedAchievements.where((a) => a.isUnlocked).isEmpty, isTrue);
      },
    );
  });
}
