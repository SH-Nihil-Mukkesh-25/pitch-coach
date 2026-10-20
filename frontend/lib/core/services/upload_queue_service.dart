import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/session_result.dart';
import '../services/api_client.dart';
import '../utils/local_file.dart';

/// Represents an audio session whose upload failed or is queued for retry.
class PendingUploadItem {
  final String id;
  final String? sessionId;
  final String audioPath;
  final double durationSeconds;
  final String mode;
  final String topicOrQuestion;
  final DateTime createdAt;
  final int retryCount;
  final String? lastError;

  const PendingUploadItem({
    required this.id,
    this.sessionId,
    required this.audioPath,
    required this.durationSeconds,
    required this.mode,
    required this.topicOrQuestion,
    required this.createdAt,
    this.retryCount = 0,
    this.lastError,
  });

  PendingUploadItem copyWith({int? retryCount, String? lastError}) {
    return PendingUploadItem(
      id: id,
      sessionId: sessionId,
      audioPath: audioPath,
      durationSeconds: durationSeconds,
      mode: mode,
      topicOrQuestion: topicOrQuestion,
      createdAt: createdAt,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'session_id': sessionId,
    'audio_path': audioPath,
    'duration_seconds': durationSeconds,
    'mode': mode,
    'topic_or_question': topicOrQuestion,
    'created_at': createdAt.toIso8601String(),
    'retry_count': retryCount,
    'last_error': lastError,
  };

  factory PendingUploadItem.fromJson(Map<String, dynamic> json) =>
      PendingUploadItem(
        id: json['id'] as String,
        sessionId: json['session_id'] as String?,
        audioPath: json['audio_path'] as String,
        durationSeconds: (json['duration_seconds'] as num?)?.toDouble() ?? 0.0,
        mode: json['mode'] as String? ?? 'interview',
        topicOrQuestion: json['topic_or_question'] as String? ?? '',
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.now(),
        retryCount: json['retry_count'] as int? ?? 0,
        lastError: json['last_error'] as String?,
      );
}

/// Persistent offline upload manager that retains audio files and retries uploads.
class UploadQueueService {
  UploadQueueService._();
  static final UploadQueueService instance = UploadQueueService._();

  static const String _fileName = 'pending_uploads.json';

  Future<File?> _getQueueFile() async {
    if (kIsWeb) return null;
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/$_fileName');
    } catch (_) {
      return null;
    }
  }

  /// Read all pending uploads from local disk.
  Future<List<PendingUploadItem>> getPendingUploads() async {
    final file = await _getQueueFile();
    if (file == null || !await file.exists()) return [];

    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];
      final list = jsonDecode(content) as List<dynamic>;
      return list
          .map(
            (item) => PendingUploadItem.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      debugPrint('[UploadQueueService] Error reading pending uploads: $e');
      return [];
    }
  }

  /// Saves the pending list back to disk.
  Future<void> _saveAll(List<PendingUploadItem> items) async {
    final file = await _getQueueFile();
    if (file == null) return;
    try {
      final jsonStr = jsonEncode(items.map((i) => i.toJson()).toList());
      await file.writeAsString(jsonStr, flush: true);
    } catch (e) {
      debugPrint('[UploadQueueService] Error saving pending uploads: $e');
    }
  }

  /// Enqueue an audio file when upload fails.
  Future<void> enqueue({
    String? sessionId,
    required String audioPath,
    required double durationSeconds,
    required String mode,
    required String topicOrQuestion,
    String? error,
  }) async {
    final items = await getPendingUploads();
    final id = sessionId ?? 'upload_${DateTime.now().millisecondsSinceEpoch}';

    // Remove existing with same id if already present
    items.removeWhere((i) => i.id == id);
    items.add(
      PendingUploadItem(
        id: id,
        sessionId: sessionId,
        audioPath: audioPath,
        durationSeconds: durationSeconds,
        mode: mode,
        topicOrQuestion: topicOrQuestion,
        createdAt: DateTime.now(),
        lastError: error,
      ),
    );

    await _saveAll(items);
  }

  /// Remove item and optionally delete audio file.
  Future<void> remove(String id, {bool deleteAudio = true}) async {
    final items = await getPendingUploads();
    final index = items.indexWhere((i) => i.id == id);
    if (index != -1) {
      final item = items.removeAt(index);
      await _saveAll(items);
      if (deleteAudio) {
        await deleteLocalFile(item.audioPath);
      }
    }
  }

  /// Wipes all pending upload items and deletes any associated local audio files.
  Future<void> clearQueue() async {
    final items = await getPendingUploads();
    for (final item in items) {
      try {
        await deleteLocalFile(item.audioPath);
      } catch (_) {}
    }
    final file = await _getQueueFile();
    if (file != null && await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  /// Retries uploading a specific queued item.
  Future<SessionResult> retryUpload(PendingUploadItem item) async {
    if (!await localFileExistsAndNonEmpty(item.audioPath)) {
      await remove(item.id, deleteAudio: false);
      throw StateError(
        'The saved recording file is no longer available on this device.',
      );
    }

    final api = ApiClient.instance;
    String targetSessionId = item.sessionId ?? '';

    // If no backend session was created initially, create one now
    if (targetSessionId.isEmpty) {
      final generatedId = const Uuid().v4();
      final now = DateTime.now();
      final localDate =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final tzOffsetMinutes = now.timeZoneOffset.inMinutes;
      final startData =
          await api.post(
                '/sessions/start',
                data: {
                  'session_id': generatedId,
                  'mode': item.mode,
                  'topic_or_question': item.topicOrQuestion,
                  'local_date': localDate,
                  'tz_offset_minutes': tzOffsetMinutes,
                },
              )
              as Map<String, dynamic>;
      targetSessionId = (startData['session_id'] as String?) ?? generatedId;
    }

    final audioPart = await MultipartFile.fromFile(
      item.audioPath,
      filename: 'recording.m4a',
    );

    final formData = FormData.fromMap({
      'audio_file': audioPart,
      'duration_seconds': item.durationSeconds.toString(),
    });

    final raw =
        await api.postMultipart('/sessions/$targetSessionId/finish', formData)
            as Map<String, dynamic>;

    // Upload succeeded! Remove from queue and clean up local audio file
    await remove(item.id, deleteAudio: true);

    return SessionResult.fromJson(raw);
  }
}
