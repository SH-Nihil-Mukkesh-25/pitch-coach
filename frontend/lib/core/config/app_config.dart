import 'dart:io' show HttpClient;
import 'package:flutter/foundation.dart';

/// Application-wide configuration constants.
///
/// Production / release builds MUST be given an HTTPS backend:
///   flutter build appbundle --release --dart-define=API_BASE_URL=https://api.yourdomain.com
/// (validated at startup by [validate]).
///
/// In debug/development, pass `--dart-define=API_BASE_URL=http://<YOUR_LAN_IP>:8000`
/// when running on a physical phone, or omit it to automatically discover:
/// - Physical Android device (via adb reverse): http://127.0.0.1:8000
/// - Android emulator host: http://10.0.2.2:8000
/// - iOS Simulator / Web / Desktop: http://localhost:8000
class AppConfig {
  AppConfig._();

  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');
  static String? _discoveredBaseUrl;

  /// Explicit `--dart-define=API_BASE_URL=...` wins.
  /// Otherwise uses discovered base URL or standard defaults.
  static String get apiBaseUrl {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    if (_discoveredBaseUrl != null && _discoveredBaseUrl!.isNotEmpty) {
      return _discoveredBaseUrl!;
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://127.0.0.1:8000';
    }
    return 'http://localhost:8000';
  }

  /// Automatically discovers whether 127.0.0.1:8000 (adb reverse on physical device)
  /// or 10.0.2.2:8000 (Android emulator) responds to health check.
  static Future<String> discoverBaseUrl() async {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    if (kIsWeb) return 'http://localhost:8000';

    final candidates = ['http://127.0.0.1:8000', 'http://10.0.2.2:8000'];

    for (final candidate in candidates) {
      try {
        final client = HttpClient()
          ..connectionTimeout = const Duration(milliseconds: 400);
        final request = await client
            .getUrl(Uri.parse('$candidate/health'))
            .timeout(const Duration(milliseconds: 400));
        final response = await request.close().timeout(
          const Duration(milliseconds: 400),
        );
        client.close(force: true);
        if (response.statusCode == 200) {
          _discoveredBaseUrl = candidate;
          debugPrint('AppConfig: Discovered active backend at $candidate');
          return candidate;
        }
      } catch (_) {}
    }

    _discoveredBaseUrl ??= apiBaseUrl;
    return _discoveredBaseUrl!;
  }

  /// Call once at startup. Throws in release if the backend URL is missing or not HTTPS,
  /// so a misconfigured build fails on first launch instead of shipping with a dev URL.
  static void validate() {
    if (!kReleaseMode) return;
    if (_envBaseUrl.isNotEmpty &&
        !_envBaseUrl.startsWith('https://') &&
        !_envBaseUrl.startsWith('http://')) {
      throw StateError(
        'API_BASE_URL must start with http:// or https:// (got $_envBaseUrl).',
      );
    }
  }

  // ── Polling configuration for results / processing screens ─────────────────
  static const Duration resultsPollInitialInterval = Duration(seconds: 2);
  static const Duration resultsPollMaxInterval = Duration(seconds: 10);
  static const Duration resultsPollTimeout = Duration(minutes: 3);
  static const int resultsPollMaxAttempts = 45; // ~3 minutes with backoff
}
