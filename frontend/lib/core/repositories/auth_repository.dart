import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import '../services/api_client.dart';

/// Handles authentication API calls and token/user persistence.
/// UserProvider delegates to this class for all auth operations.
class AuthRepository {
  AuthRepository._();
  static final AuthRepository instance = AuthRepository._();

  static const _storage = FlutterSecureStorage();
  final _api = ApiClient.instance;

  // ── Sign up ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> signup({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final data = await _api.post(
      '/auth/signup',
      data: {'email': email, 'password': password, 'full_name': fullName},
    );
    await _persistAuth(data);
    return data['user'] as Map<String, dynamic>;
  }

  // ── Login ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final data = await _api.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    await _persistAuth(data);
    return data['user'] as Map<String, dynamic>;
  }

  // ── Firebase → backend token exchange ─────────────────────────────────────

  /// Trades a Firebase ID token for backend JWTs so protected endpoints work.
  Future<Map<String, dynamic>> loginWithFirebaseToken(String idToken) async {
    final data = await _api.post('/auth/firebase', data: {'id_token': idToken});
    await _persistAuth(data);
    return data['user'] as Map<String, dynamic>;
  }

  // ── Guest login ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> loginAsGuest() async {
    final data = await _api.post('/auth/guest');
    await _persistAuth(data);
    return data['user'] as Map<String, dynamic>;
  }

  // ── Upgrade guest → full account ─────────────────────────────────────────

  Future<Map<String, dynamic>> upgradeGuest({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final data = await _api.post(
      '/auth/upgrade-guest',
      data: {'email': email, 'password': password, 'full_name': fullName},
    );
    await _persistAuth(data);
    return data['user'] as Map<String, dynamic>;
  }

  // ── Get profile ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getMe() async {
    try {
      final data = await _api.get('/users/me');
      await _cacheUser(data as Map<String, dynamic>);
      return data;
    } catch (_) {
      return null;
    }
  }

  // ── Update profile ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> updateMe(Map<String, dynamic> fields) async {
    final data =
        await _api.patch('/users/me', data: fields) as Map<String, dynamic>;
    await _cacheUser(data);
    return data;
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> logout() => ApiClient.clearTokens();

  // ── Check if user is already logged in (token in storage) ────────────────

  Future<bool> get hasStoredTokens async {
    final token = await ApiClient.getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // ── Load cached user from secure storage ─────────────────────────────────

  Future<Map<String, dynamic>?> getCachedUser() async {
    final raw = await _storage.read(key: 'user_data');
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Upload an avatar image file to backend
  Future<Map<String, dynamic>> uploadAvatar(
    String filePath, {
    void Function(int, int)? onProgress,
  }) async {
    final fileName = p.basename(filePath);
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    final data = await _api.postMultipart(
      '/users/me/avatar',
      formData,
      onSendProgress: onProgress,
    );
    final user = data as Map<String, dynamic>;
    await _cacheUser(user);
    return user;
  }

  /// Delete user account permanently
  Future<void> deleteAccount() async {
    try {
      try {
        await _api.dio.delete('/users/me');
      } catch (_) {
        await _api.dio.delete('/account');
      }
    } finally {
      await logout();
    }
  }

  /// Submit user feedback
  Future<Map<String, dynamic>> submitFeedback({
    required String category,
    required String message,
    Map<String, dynamic>? metadata,
  }) async {
    final data = await _api.post(
      '/feedback',
      data: {
        'category': category,
        'message': message,
        'metadata': metadata ?? {},
      },
    );
    return data as Map<String, dynamic>;
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  Future<void> _persistAuth(dynamic data) async {
    await ApiClient.saveTokens(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
    );
    if (data['user'] != null) {
      await _cacheUser(data['user'] as Map<String, dynamic>);
    }
  }

  Future<void> _cacheUser(Map<String, dynamic> user) async {
    await _storage.write(key: 'user_data', value: jsonEncode(user));
  }
}
