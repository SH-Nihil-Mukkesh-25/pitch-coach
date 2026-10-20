import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../models/session_result.dart';
import '../services/api_client.dart';
import '../services/local_database_service.dart';
import '../utils/local_file.dart';

enum MicPermissionState { granted, denied, permanentlyDenied }

/// Encapsulates recording and the session API lifecycle.
/// Used by InterviewSessionController.
class SessionRepository {
  SessionRepository._();
  static final SessionRepository instance = SessionRepository._();

  final _api = ApiClient.instance;
  final AudioRecorder _recorder = AudioRecorder();

  String? _currentSessionId;
  String? _currentAudioPath;
  static final Map<String, String> _audioPathCache = {};
  // Paths staged for deletion once the results screen is done with them
  static final Set<String> _pendingDeletePaths = {};
  List<SessionSummary>? _cachedSessions;
  DateTime? _sessionsCacheTime;

  String? get currentSessionId => _currentSessionId;
  String? get currentAudioPath => _currentAudioPath;
  List<SessionSummary>? get cachedSessions => _cachedSessions;
  SessionSummary? get cachedRecentSession =>
      (_cachedSessions != null && _cachedSessions!.isNotEmpty)
      ? _cachedSessions!.first
      : null;

  void invalidateCache() {
    _cachedSessions = null;
    _sessionsCacheTime = null;
  }

  // ── Permissions ───────────────────────────────────────────────────────────

  Future<bool> requestMicPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<MicPermissionState> requestMicPermissionStatus() async {
    final current = await Permission.microphone.status;
    if (current.isGranted) {
      return MicPermissionState.granted;
    }
    if (current.isPermanentlyDenied) {
      return MicPermissionState.permanentlyDenied;
    }

    final result = await Permission.microphone.request();
    if (result.isGranted) {
      return MicPermissionState.granted;
    }
    if (result.isPermanentlyDenied) {
      return MicPermissionState.permanentlyDenied;
    }
    return MicPermissionState.denied;
  }

  Future<bool> openSettings() async {
    return await openAppSettings();
  }

  Stream<Amplitude> get amplitudeStream =>
      _recorder.onAmplitudeChanged(const Duration(milliseconds: 120));

  Future<bool> isRecording() async => await _recorder.isRecording();

  /// Guest Mode records locally for a genuine microphone experience, but never
  /// creates a backend session or uploads the resulting file.
  Future<void> startDemoRecording() async {
    if (!await _recorder.hasPermission()) {
      throw StateError('Microphone permission is required to record.');
    }
    final dir = await getApplicationDocumentsDirectory();
    _currentAudioPath =
        '${dir.path}/demo_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        numChannels: 1,
        bitRate: 64000,
      ),
      path: _currentAudioPath!,
    );
  }

  Future<String> finishDemoRecording() async {
    final path = await _recorder.stop() ?? _currentAudioPath;
    final recordedPath = path;
    _currentAudioPath = null;
    if (recordedPath == null) {
      throw StateError('Recording did not produce an audio file.');
    }
    if (!await localFileExistsAndNonEmpty(recordedPath)) {
      throw StateError('The recording is missing or empty. Please try again.');
    }
    return recordedPath;
  }

  /// Explicitly releases and deletes the locally-cached audio file for a session
  /// (call this after the results screen is dismissed / done with playback).
  Future<void> releaseAudioFile(String sessionId) async {
    final path = _audioPathCache.remove(sessionId);
    if (path != null) {
      _pendingDeletePaths.remove(path);
      await deleteLocalFile(path);
    }
  }

  /// Cleans up any cached session audio files on disk and resets internal caches.
  Future<void> clearAllLocalAudioFiles() async {
    if (!kIsWeb) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final dirObj = Directory(dir.path);
        if (await dirObj.exists()) {
          final entities = dirObj.listSync();
          for (final entity in entities) {
            if (entity is File) {
              final name = p.basename(entity.path);
              if (name.startsWith('session_') || name.startsWith('demo_')) {
                try {
                  await entity.delete();
                } catch (_) {}
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[SessionRepository] Notice clearing audio files: $e');
      }
    }
    _audioPathCache.clear();
    _pendingDeletePaths.clear();
    _currentAudioPath = null;
    _currentSessionId = null;
  }

  /// Cleans up any audio files that were staged for deletion from previous sessions.
  Future<void> _cleanupPendingDeletes() async {
    final toDelete = Set<String>.from(_pendingDeletePaths);
    for (final path in toDelete) {
      // Only delete if the path is not referenced by any active cache entry
      final isInUse = _audioPathCache.values.contains(path);
      if (!isInUse) {
        _pendingDeletePaths.remove(path);
        await deleteLocalFile(path);
      }
    }
  }

  Completer<String?>? _sessionRegistrationCompleter;

  // ── Session lifecycle ─────────────────────────────────────────────────────

  /// Step 1: start recording immediately (mic activates instantly), then
  /// register the session on the backend concurrently in the background.
  /// This ensures zero UI lag when tapping the mic.
  Future<String?> startSession({
    required String mode,
    required String topicOrQuestion,
    String? parentSessionId,
  }) async {
    if (!await _recorder.hasPermission()) {
      throw StateError('Microphone permission is required to record.');
    }
    // Clean up audio files from previous sessions now that we're starting fresh
    await _cleanupPendingDeletes();

    // 1a. Start recording immediately so the mic activates without waiting for
    //     the network round-trip to the backend.
    final dir = await getApplicationDocumentsDirectory();
    final generatedSessionId = const Uuid().v4();
    _currentSessionId = generatedSessionId;
    _currentAudioPath = '${dir.path}/session_$generatedSessionId.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        numChannels: 1,
        bitRate: 64000,
      ),
      path: _currentAudioPath!,
    );

    // 1b. Register session on the backend concurrently in background
    final completer = Completer<String?>();
    _sessionRegistrationCompleter = completer;

    final now = DateTime.now();
    final localDate =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final tzOffsetMinutes = now.timeZoneOffset.inMinutes;

    final payload = <String, dynamic>{
      'session_id': generatedSessionId,
      'mode': mode,
      'topic_or_question': topicOrQuestion,
      'local_date': localDate,
      'tz_offset_minutes': tzOffsetMinutes,
    };
    if (parentSessionId != null && parentSessionId.isNotEmpty) {
      payload['parent_session_id'] = parentSessionId;
    }

    _api
        .post(
          '/sessions/start',
          data: payload,
        )
        .then((res) {
          final data = res as Map<String, dynamic>;
          final id = (data['session_id'] as String?) ?? generatedSessionId;
          _currentSessionId = id;
          if (!completer.isCompleted) completer.complete(id);
        })
        .catchError((_) {
          // In offline scenario, client generated ID remains authoritative
          _currentSessionId = generatedSessionId;
          if (!completer.isCompleted) completer.complete(generatedSessionId);
        });

    return _currentSessionId;
  }

  /// Stops recorder without uploading. Returns the local audio file path.
  Future<String?> stopAudioRecorder() async {
    final path = await _recorder.stop();
    return path ?? _currentAudioPath;
  }

  /// Step 2: stop recording and upload audio → triggers AI pipeline on server.
  Future<SessionResult?> finishSession(double durationSeconds) async {
    // If background registration is still in flight, wait briefly
    if (_currentSessionId == null && _sessionRegistrationCompleter != null) {
      try {
        _currentSessionId = await _sessionRegistrationCompleter!.future.timeout(
          const Duration(milliseconds: 2000),
          onTimeout: () => null,
        );
      } catch (_) {}
    }

    // If session registration with backend failed at start, attempt a late registration now.
    if (_currentSessionId == null && _currentAudioPath != null) {
      try {
        final generatedId = const Uuid().v4();
        final now = DateTime.now();
        final localDate =
            '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        final tzOffsetMinutes = now.timeZoneOffset.inMinutes;
        final data =
            await _api.post(
                  '/sessions/start',
                  data: {
                    'session_id': generatedId,
                    'mode': 'interview',
                    'topic_or_question': 'Practice session',
                    'local_date': localDate,
                    'tz_offset_minutes': tzOffsetMinutes,
                  },
                )
                as Map<String, dynamic>;
        _currentSessionId = (data['session_id'] as String?) ?? generatedId;
      } catch (_) {
        // Still unreachable — return null so the controller handles it as a local-only session.
        return null;
      }
    }
    if (_currentSessionId == null) return null;

    // Stop recorder safely — checking isRecording first prevents "Stop() called but track is not started or stopped"
    String? path;
    try {
      if (await _recorder.isRecording()) {
        path = await _recorder.stop();
      }
    } catch (e) {
      debugPrint('[SessionRepository] recorder.stop notice: $e');
    }
    final audioPath = path ?? _currentAudioPath;
    if (audioPath == null) {
      throw StateError('Recording did not produce an audio file.');
    }

    if (!await localFileExistsAndNonEmpty(audioPath)) {
      throw StateError('The recording is missing or empty. Please try again.');
    }

    // MultipartFile.fromFile is unavailable on web; bytes path works everywhere.
    final MultipartFile audioPart;
    if (kIsWeb) {
      throw StateError(
        'Audio upload from Chrome is not supported yet. '
        'Use the Android/iOS app or Windows desktop build for live sessions.',
      );
    } else {
      audioPart = await MultipartFile.fromFile(
        audioPath,
        filename: 'recording.m4a',
      );
    }

    final formData = FormData.fromMap({
      'audio_file': audioPart,
      'duration_seconds': durationSeconds.toString(),
    });

    final sessionId = _currentSessionId!;
    final raw =
        await _api.postMultipart('/sessions/$sessionId/finish', formData)
            as Map<String, dynamic>;

    // Cache the audio path BEFORE deletion so ResultsScreen can play it back.
    // Actual file deletion is deferred to the next session start or an explicit
    // releaseAudioFile() call, giving the results screen time to use the file.
    _audioPathCache[sessionId] = audioPath;
    _pendingDeletePaths.add(audioPath);
    _currentAudioPath = null;
    _currentSessionId = null;
    invalidateCache();

    final result = SessionResult.fromJson(raw);
    return result.copyWith(audioPath: audioPath);
  }

  // ── Session Result In-Memory Cache (Instant Load, Zero Re-calculation) ───
  final Map<String, SessionResult> _sessionResultCache = {};

  SessionResult? getCachedSession(String sessionId) =>
      _sessionResultCache[sessionId];

  void cacheSession(SessionResult result) {
    if (result.isAnalyzed && !result.analysisFailed) {
      _sessionResultCache[result.id] = result;
    }
  }

  void invalidateSessionResult(String sessionId) {
    _sessionResultCache.remove(sessionId);
  }

  /// Step 3 (polling/retrieval): fetch session with local cache verification.
  /// If session is already analyzed and cached, returns instantly with 0ms delay.
  Future<SessionResult> getSession(
    String sessionId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _sessionResultCache.containsKey(sessionId)) {
      final cached = _sessionResultCache[sessionId]!;
      if (cached.isAnalyzed && !cached.analysisFailed) {
        return cached;
      }
    }

    final raw = await _api.get('/sessions/$sessionId') as Map<String, dynamic>;
    final result = SessionResult.fromJson(raw);
    final cachedPath = _audioPathCache[sessionId];
    SessionResult resolved = result;
    if (cachedPath != null) {
      resolved = result.copyWith(audioPath: cachedPath);
    } else {
      final serverAudio = raw['audio_url'] as String?;
      if (serverAudio != null && serverAudio.isNotEmpty) {
        final fullUrl = serverAudio.startsWith('http')
            ? serverAudio
            : '${AppConfig.apiBaseUrl}$serverAudio';
        resolved = result.copyWith(audioUrl: fullUrl);
      }
    }

    if (resolved.isAnalyzed && !resolved.analysisFailed) {
      _sessionResultCache[sessionId] = resolved;
    }

    return resolved;
  }

  /// Asks the server to re-run analysis on an already-uploaded recording.
  Future<void> retryAnalysis(String sessionId) async {
    _sessionResultCache.remove(sessionId);
    await _api.post('/sessions/$sessionId/retry');
  }

  /// History list — used by HistoryScreen with in-memory caching.
  Future<List<SessionSummary>> listSessions({
    String? mode,
    String? search,
    int page = 1,
    int limit = 20,
    bool forceRefresh = false,
  }) async {
    final isDefaultQuery =
        (mode == null || mode == 'All') &&
        (search == null || search.isEmpty) &&
        page == 1;

    // Return in-memory cached sessions if available, fresh (< 3 mins), and not forced
    if (isDefaultQuery &&
        !forceRefresh &&
        _cachedSessions != null &&
        _sessionsCacheTime != null) {
      final age = DateTime.now().difference(_sessionsCacheTime!);
      if (age < const Duration(minutes: 3)) {
        return _cachedSessions!;
      }
    }

    final params = <String, dynamic>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (mode != null && mode != 'All') params['mode'] = mode;
    if (search != null && search.isNotEmpty) params['search'] = search;

    try {
      final raw = await _api.get('/sessions', params: params) as List<dynamic>;
      final list = raw
          .map((e) => SessionSummary.fromJson(e as Map<String, dynamic>))
          .toList();

      if (isDefaultQuery) {
        _cachedSessions = list;
        _sessionsCacheTime = DateTime.now();
      }

      return list;
    } catch (e) {
      // Offline fallback: load from local SQLite database
      final localDb = LocalDatabaseService.instance;
      if (localDb.isOpen &&
          localDb.currentUserId != null &&
          localDb.currentUserId != 'guest') {
        try {
          final localList = await localDb.getSessionSummaries(
            localDb.currentUserId!,
            mode: (mode != null && mode != 'All') ? mode : null,
            limit: limit,
          );
          if (localList.isNotEmpty) {
            return localList;
          }
        } catch (_) {}
      }
      if (_cachedSessions != null && _cachedSessions!.isNotEmpty) {
        return _cachedSessions!;
      }
      rethrow;
    }
  }

  /// Recent session helper for HomeScreen with caching support.
  Future<SessionSummary?> getRecentSession({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      if (_cachedSessions != null && _cachedSessions!.isNotEmpty) {
        return _cachedSessions!.first;
      }
      final localDb = LocalDatabaseService.instance;
      if (localDb.isOpen &&
          localDb.currentUserId != null &&
          localDb.currentUserId != 'guest') {
        try {
          final localRecent = await localDb.getRecentSession(
            localDb.currentUserId!,
          );
          if (localRecent != null) {
            return localRecent;
          }
        } catch (_) {}
      }
    }
    final list = await listSessions(limit: 1, forceRefresh: forceRefresh);
    return list.isNotEmpty ? list.first : null;
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────

  Future<void> cancelSession() async {
    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
    } catch (_) {}

    if (_currentAudioPath != null) {
      await deleteLocalFile(_currentAudioPath);
    }
    _currentSessionId = null;
    _currentAudioPath = null;
    _sessionRegistrationCompleter = null;
  }

  void dispose() {
    _recorder.dispose();
  }
}
