import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../repositories/auth_repository.dart';
import '../repositories/firebase_auth_repository.dart';
import '../repositories/session_repository.dart';
import '../services/api_client.dart';
import '../services/local_database_service.dart';
import '../services/notification_service.dart';
import '../services/sync_service.dart';
import '../services/upload_queue_service.dart';

enum AuthState { loading, unauthenticated, guest, authenticated, error }

/// UserProfile — keeps the same shape as before so all screens compile unchanged.
class UserProfile {
  String id;
  String name;
  String email;
  String role;
  String targetGoal;
  String experienceLevel;
  String targetIndustry;
  String feedbackTone;
  bool isGuest;
  bool darkMode;
  String? avatarUrl;
  DateTime? createdAt;
  Map<String, dynamic>? settings;

  // Stats are now fetched separately via StatsProvider; keep as fallback defaults
  int sessionsCompleted;
  double avgScore;
  String memberSince;

  UserProfile({
    this.id = '',
    required this.name,
    required this.email,
    required this.role,
    required this.targetGoal,
    required this.experienceLevel,
    required this.targetIndustry,
    required this.feedbackTone,
    this.isGuest = false,
    this.darkMode = false,
    this.avatarUrl,
    this.createdAt,
    this.settings,
    this.sessionsCompleted = 0,
    this.avgScore = 0.0,
    this.memberSince = '',
  });

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'PC';
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  bool get isPro =>
      settings?['is_pro'] == true || role.toLowerCase().contains('pro');

  String? get fullAvatarUrl {
    if (avatarUrl == null || avatarUrl!.isEmpty) return null;
    if (avatarUrl!.startsWith('http')) return avatarUrl;
    final base = ApiClient.instance.dio.options.baseUrl.replaceAll(
      RegExp(r'/+$'),
      '',
    );
    final path = avatarUrl!.startsWith('/') ? avatarUrl! : '/$avatarUrl';
    return '$base$path';
  }

  /// Build from API /me response JSON.
  factory UserProfile.fromJson(Map<String, dynamic> j) {
    DateTime? created;
    if (j['created_at'] != null) {
      created = DateTime.tryParse(j['created_at'].toString());
    }

    String formattedMemberSince = '';
    if (created != null) {
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      formattedMemberSince = '${months[created.month - 1]} ${created.year}';
    } else {
      formattedMemberSince = 'Recently';
    }

    return UserProfile(
      id: j['id'] as String? ?? '',
      name: j['full_name'] as String? ?? 'User',
      email: j['email'] as String? ?? '',
      role: j['role_occupation'] as String? ?? '',
      targetGoal: j['primary_objective'] as String? ?? '',
      experienceLevel: j['experience_level'] as String? ?? 'Intermediate',
      targetIndustry: j['target_industry'] as String? ?? '',
      feedbackTone:
          j['feedback_style'] as String? ?? 'Encouraging & Constructive',
      isGuest: j['is_guest'] as bool? ?? false,
      darkMode: j['dark_mode'] as bool? ?? false,
      avatarUrl: j['avatar_url'] as String?,
      createdAt: created,
      settings: j['settings'] as Map<String, dynamic>?,
      memberSince: formattedMemberSince,
    );
  }
}

/// UserProvider — wires all auth operations to the real API **and** Firebase.
/// Public interface (getters/method signatures) is unchanged so screens recompile.
class UserProvider extends ChangeNotifier {
  final _auth = AuthRepository.instance;
  final _firebaseAuth = FirebaseAuthRepository.instance;
  static const _storage = FlutterSecureStorage();
  static const _darkModeKey = 'pitch_coach_dark_mode';

  UserProfile _user = UserProfile(
    name: 'Guest',
    email: '',
    role: '',
    targetGoal: '',
    experienceLevel: 'Beginner',
    targetIndustry: '',
    feedbackTone: 'Encouraging & Constructive',
  );

  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _error;
  bool _localThemeLoaded = false;

  UserProfile get user => _user;
  bool get isLoggedIn => _isLoggedIn;
  bool get isGuest => _isLoggedIn && _user.isGuest;
  AuthState get authState => _isLoading
      ? AuthState.loading
      : _error != null
      ? AuthState.error
      : !_isLoggedIn
      ? AuthState.unauthenticated
      : _user.isGuest
      ? AuthState.guest
      : AuthState.authenticated;
  bool get isLoading => _isLoading;
  String? get error => _error;
  ThemeMode get themeMode => _user.darkMode ? ThemeMode.dark : ThemeMode.light;

  /// Apply API/Firebase profile without clobbering the locally chosen theme.
  void _adoptUser(Map<String, dynamic> data) {
    final keptDark = _user.darkMode;
    _user = UserProfile.fromJson(data);
    _user.darkMode = keptDark;
    _isLoggedIn = true;

    // Switch local SQLite database to the authenticated user and trigger background pull sync
    if (_user.id.isNotEmpty && !_user.isGuest) {
      LocalDatabaseService.instance
          .initForUser(_user.id)
          .then((_) {
            SyncService.instance.pull(userId: _user.id);
          })
          .catchError((_) {});
    }
  }

  Future<void> _loadLocalTheme() async {
    if (_localThemeLoaded) return;
    try {
      final raw = await _storage.read(key: _darkModeKey);
      if (raw != null) {
        _user.darkMode = raw == 'true';
        notifyListeners();
      }
    } catch (_) {
      // Storage unavailable — keep in-memory default.
    } finally {
      _localThemeLoaded = true;
    }
  }

  Future<void> _persistLocalTheme(bool enabled) async {
    try {
      await _storage.write(key: _darkModeKey, value: enabled.toString());
    } catch (_) {
      // Non-fatal — theme still works for this session.
    }
  }

  // ── App startup: try to restore session ──────────────────────────────────

  /// Restores an existing Firebase session (persisted by the Firebase SDK).
  /// Call this from main() so the app skips onboarding on restart.
  Future<bool> tryRestoreFirebaseSession() async {
    final userData = _firebaseAuth.currentUserMap;
    if (userData == null) return false;
    _adoptUser(userData);
    notifyListeners();
    if (!await _auth.hasStoredTokens) await _syncBackend();
    return true;
  }

  /// Exchanges the Firebase ID token for backend JWTs and adopts the stored
  /// profile. Best effort: if the backend is unreachable the Firebase profile
  /// is kept and protected API calls will retry on the next launch/login.
  Future<void> _syncBackend() async {
    try {
      final idToken = await _firebaseAuth.getIdToken();
      if (idToken == null) return;
      _adoptUser(await _auth.loginWithFirebaseToken(idToken));
      notifyListeners();
    } catch (_) {
      // Backend offline — keep the Firebase-derived profile.
    }
  }

  Future<bool> tryRestoreSession() async {
    await _loadLocalTheme();
    // First try Firebase (preferred flow going forward)
    if (await tryRestoreFirebaseSession()) return true;
    // Fallback: legacy JWT token from the REST API
    if (!await _auth.hasStoredTokens) return false;
    // Try to fetch /me — if it fails the token is expired
    final userData = await _auth.getMe();
    if (userData == null) {
      await _auth.logout();
      return false;
    }
    _adoptUser(userData);
    notifyListeners();
    return true;
  }

  // ── Login / Signup ────────────────────────────────────────────────────────

  Future<bool> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    try {
      final userData = await _auth.signup(
        email: email,
        password: password,
        fullName: name,
      );
      _adoptUser(userData);
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _extractErrorMessage(e);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> login({required String email, required String password}) async {
    _setLoading(true);
    try {
      final userData = await _auth.login(email: email, password: password);
      _adoptUser(userData);
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _extractErrorMessage(e);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Firebase auth methods ─────────────────────────────────────────────────

  /// Sign up via Firebase email/password.
  Future<bool> firebaseSignUp({
    required String name,
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    try {
      final userData = await _firebaseAuth.signUpWithEmail(
        email: email,
        password: password,
        displayName: name,
      );
      _adoptUser(userData);
      await _syncBackend();
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Sign in via Firebase email/password.
  Future<bool> firebaseLogin({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    try {
      final userData = await _firebaseAuth.signInWithEmail(
        email: email,
        password: password,
      );
      _adoptUser(userData);
      await _syncBackend();
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Sign in via Google using Firebase.
  /// Returns true on success, false if the user cancelled, throws on error.
  Future<bool> firebaseSignInWithGoogle() async {
    _setLoading(true);
    try {
      final userData = await _firebaseAuth.signInWithGoogle();
      if (userData == null) {
        // User cancelled the Google flow
        return false;
      }
      _adoptUser(userData);
      await _syncBackend();
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Signs out from Firebase (and Google if used). Also clears legacy tokens.
  Future<void> firebaseLogout() async {
    await _firebaseAuth.signOut();
    await _auth.logout(); // also clear any legacy JWT tokens
    await LocalDatabaseService.instance.close();
    final keptDark = _user.darkMode;
    _isLoggedIn = false;
    _user = UserProfile(
      name: 'Guest',
      email: '',
      role: '',
      targetGoal: '',
      experienceLevel: 'Beginner',
      targetIndustry: '',
      feedbackTone: 'Encouraging & Constructive',
      darkMode: keptDark,
    );
    _error = null;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> loginAsGuest() async {
    // Guest is a local demo identity. It has no token and never calls protected APIs.
    await _auth.logout();
    await LocalDatabaseService.instance.close();
    final keptDark = _user.darkMode;
    _user = UserProfile(
      id: 'demo-guest',
      name: 'Guest',
      email: '',
      role: 'Student',
      targetGoal: 'Build confidence',
      experienceLevel: 'Beginner',
      targetIndustry: '',
      feedbackTone: 'Encouraging & Constructive',
      isGuest: true,
      sessionsCompleted: 5,
      avgScore: 82,
      darkMode: keptDark,
    );
    _isLoggedIn = true;
    _error = null;
    notifyListeners();
    return true;
  }

  // ── Profile update ────────────────────────────────────────────────────────

  Future<void> updateProfile({
    String? name,
    String? email,
    String? role,
    String? targetGoal,
    String? experienceLevel,
    String? targetIndustry,
    String? feedbackTone,
  }) async {
    final fields = <String, dynamic>{};
    if (name != null && name.trim().isNotEmpty) {
      fields['full_name'] = name.trim();
      _user.name = name.trim();
    }
    if (role != null && role.trim().isNotEmpty) {
      fields['role_occupation'] = role.trim();
      _user.role = role.trim();
    }
    if (targetGoal != null && targetGoal.trim().isNotEmpty) {
      fields['primary_objective'] = targetGoal.trim();
      _user.targetGoal = targetGoal.trim();
    }
    if (experienceLevel != null && experienceLevel.trim().isNotEmpty) {
      fields['experience_level'] = experienceLevel.trim();
      _user.experienceLevel = experienceLevel.trim();
    }
    if (targetIndustry != null && targetIndustry.trim().isNotEmpty) {
      fields['target_industry'] = targetIndustry.trim();
      _user.targetIndustry = targetIndustry.trim();
    }
    if (feedbackTone != null && feedbackTone.trim().isNotEmpty) {
      fields['feedback_style'] = feedbackTone.trim();
      _user.feedbackTone = feedbackTone.trim();
    }

    notifyListeners(); // optimistic UI update
    if (_user.isGuest || !_isLoggedIn) return;
    if (!await _auth.hasStoredTokens) return;
    if (fields.isNotEmpty) {
      try {
        final updated = await _auth.updateMe(fields);
        _adoptUser(updated);
        notifyListeners();
      } catch (_) {
        // If API fails, local values remain — not critical
      }
    }
  }

  Future<void> patchUser(Map<String, dynamic> data) async {
    try {
      if (!_user.isGuest && _isLoggedIn && await _auth.hasStoredTokens) {
        final updated = await _auth.updateMe(data);
        _adoptUser(updated);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setDarkMode(bool enabled) async {
    _user.darkMode = enabled;
    notifyListeners();
    await _persistLocalTheme(enabled);

    // Best-effort backend sync only for authenticated REST users.
    // Never revert local theme if sync fails (onboarding / Firebase / offline).
    if (!_isLoggedIn || _user.isGuest) return;
    if (!await _auth.hasStoredTokens) return;
    try {
      await _auth.updateMe({'dark_mode': enabled});
    } catch (_) {
      // Keep the local preference — backend sync is optional.
    }
  }

  // ── Avatar Upload & Remove ────────────────────────────────────────────────

  Future<bool> uploadAvatar(
    String filePath, {
    void Function(double)? onProgress,
  }) async {
    _setLoading(true);
    try {
      final updated = await _auth.uploadAvatar(
        filePath,
        onProgress: (sent, total) {
          if (total > 0 && onProgress != null) {
            onProgress(sent / total);
          }
        },
      );
      _adoptUser(updated);
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _extractErrorMessage(e);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Refreshes user profile from backend
  Future<void> fetchUserProfile() async {
    try {
      if (!_user.isGuest && _isLoggedIn && await _auth.hasStoredTokens) {
        final userData = await _auth.getMe();
        if (userData != null) {
          _adoptUser(userData);
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  Future<bool> removeAvatar() async {
    _setLoading(true);
    try {
      _user.avatarUrl = null;
      notifyListeners();
      if (!_user.isGuest && await _auth.hasStoredTokens) {
        final updated = await _auth.updateMe({'avatar_url': ''});
        _adoptUser(updated);
      }
      return true;
    } catch (e) {
      _error = _extractErrorMessage(e);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Logout & Account Deletion ─────────────────────────────────────────────

  Future<void> logout() async {
    try {
      await _firebaseAuth.signOut();
    } catch (_) {}

    try {
      await NotificationService.instance.cancelDailyReminder();
    } catch (_) {}

    try {
      await _storage.deleteAll();
    } catch (_) {}

    await _auth.logout();
    await LocalDatabaseService.instance.close();
    final keptDark = _user.darkMode;
    _isLoggedIn = false;
    _user = UserProfile(
      name: 'Guest',
      email: '',
      role: '',
      targetGoal: '',
      experienceLevel: 'Beginner',
      targetIndustry: '',
      feedbackTone: 'Encouraging & Constructive',
      darkMode: keptDark,
    );
    _error = null;
    notifyListeners();
  }

  Future<bool> deleteAccount() async {
    _setLoading(true);
    try {
      final userId = _user.id;
      if (!_user.isGuest && await _auth.hasStoredTokens) {
        await _auth.deleteAccount();
      }
      // Purge all local user databases (both user and guest)
      await LocalDatabaseService.instance.wipeAllLocalDatabases(userId);
      // Purge offline queue and staged audio files
      await UploadQueueService.instance.clearQueue();
      // Purge all local recordings and session audio files
      await SessionRepository.instance.clearAllLocalAudioFiles();
      await logout();
      return true;
    } catch (e) {
      _error = _extractErrorMessage(e);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  String _extractErrorMessage(Object e) {
    if (e is DioException) {
      final detail = (e.response?.data as Map?)?['detail'];
      if (detail is String && detail.isNotEmpty) {
        return detail;
      }
      if (detail is List && detail.isNotEmpty) {
        return 'Please check the highlighted registration details.';
      }
      if (e.response?.statusCode == 409) {
        return 'An account with this email already exists.';
      }
      if (e.response?.statusCode == 400) {
        return 'Please check your details and try again.';
      }
      if (e.response?.statusCode != null) {
        return 'The server could not complete your request. Please try again.';
      }
    }
    final str = e.toString();
    // Dio DioException message often contains the backend detail string
    if (str.contains('detail')) {
      final match = RegExp(r'"detail"\s*:\s*"([^"]+)"').firstMatch(str);
      if (match != null) return match.group(1)!;
    }
    if (str.contains('SocketException') || str.contains('connection')) {
      return 'Cannot connect to server. Make sure the backend is running.';
    }
    return 'Something went wrong. Please try again.';
  }
}
