import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../providers/user_provider.dart';
import '../repositories/auth_repository.dart';
import '../repositories/firebase_auth_repository.dart';
import '../repositories/session_repository.dart';
import '../services/local_database_service.dart';
import '../services/notification_service.dart';
import '../services/upload_queue_service.dart';

/// Immutable state for user authentication and profile data.
class UserState extends Equatable {
  final UserProfile user;
  final AuthState authState;
  final String? errorMessage;
  final bool isLoading;

  const UserState({
    required this.user,
    this.authState = AuthState.unauthenticated,
    this.errorMessage,
    this.isLoading = false,
  });

  bool get isAuthenticated => authState == AuthState.authenticated;
  bool get isGuest => authState == AuthState.guest || user.isGuest;
  bool get isLoggedIn =>
      authState == AuthState.authenticated || authState == AuthState.guest;

  factory UserState.initial() {
    return UserState(
      user: UserProfile(
        name: 'Guest',
        email: '',
        role: 'Founder',
        targetGoal: 'Pitch to investors',
        experienceLevel: 'Intermediate',
        targetIndustry: 'Technology / SaaS',
        feedbackTone: 'Direct & actionable',
      ),
      authState: AuthState.unauthenticated,
    );
  }

  UserState copyWith({
    UserProfile? user,
    AuthState? authState,
    String? errorMessage,
    bool? isLoading,
  }) {
    return UserState(
      user: user ?? this.user,
      authState: authState ?? this.authState,
      errorMessage: errorMessage,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [
    user.id,
    user.email,
    user.name,
    user.role,
    user.sessionsCompleted,
    user.avgScore,
    user.isGuest,
    user.avatarUrl,
    authState,
    errorMessage,
    isLoading,
  ];
}

/// Cubit managing user profile, authentication state, and session restoration.
class UserCubit extends Cubit<UserState> {
  final AuthRepository _authRepo;
  final FirebaseAuthRepository _firebaseAuth;

  UserCubit({
    AuthRepository? authRepository,
    FirebaseAuthRepository? firebaseAuthRepository,
  }) : _authRepo = authRepository ?? AuthRepository.instance,
       _firebaseAuth =
           firebaseAuthRepository ?? FirebaseAuthRepository.instance,
       super(UserState.initial());

  Future<bool> tryRestoreFirebaseSession() async {
    final userData = _firebaseAuth.currentUserMap;
    if (userData == null) return false;
    final profile = UserProfile.fromJson(userData);
    emit(
      state.copyWith(
        user: profile,
        authState: AuthState.authenticated,
        isLoading: false,
      ),
    );
    if (!await _authRepo.hasStoredTokens) {
      try {
        final idToken = await _firebaseAuth.getIdToken();
        if (idToken != null) {
          final res = await _authRepo.loginWithFirebaseToken(idToken);
          emit(state.copyWith(user: UserProfile.fromJson(res)));
        }
      } catch (_) {}
    }
    return true;
  }

  Future<bool> tryRestoreSession() async {
    emit(state.copyWith(isLoading: true, authState: AuthState.loading));
    try {
      if (await tryRestoreFirebaseSession()) return true;

      if (!await _authRepo.hasStoredTokens) {
        emit(
          state.copyWith(
            authState: AuthState.unauthenticated,
            isLoading: false,
          ),
        );
        return false;
      }

      final userData = await _authRepo.getMe();
      if (userData != null) {
        final profile = UserProfile.fromJson(userData);
        emit(
          state.copyWith(
            user: profile,
            authState: profile.isGuest
                ? AuthState.guest
                : AuthState.authenticated,
            isLoading: false,
          ),
        );
        return true;
      } else {
        await _authRepo.logout();
        emit(
          state.copyWith(
            authState: AuthState.unauthenticated,
            isLoading: false,
          ),
        );
        return false;
      }
    } catch (e) {
      emit(
        state.copyWith(
          authState: AuthState.unauthenticated,
          isLoading: false,
          errorMessage: e.toString(),
        ),
      );
      return false;
    }
  }

  Future<bool> login({required String email, required String password}) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      final data = await _authRepo.login(email: email, password: password);
      final profile = UserProfile.fromJson(data);
      emit(
        state.copyWith(
          user: profile,
          authState: AuthState.authenticated,
          isLoading: false,
        ),
      );
      return true;
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: e.toString(),
          authState: AuthState.error,
        ),
      );
      return false;
    }
  }

  Future<bool> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      final data = await _authRepo.signup(
        email: email,
        password: password,
        fullName: name,
      );
      final profile = UserProfile.fromJson(data);
      emit(
        state.copyWith(
          user: profile,
          authState: AuthState.authenticated,
          isLoading: false,
        ),
      );
      return true;
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: e.toString(),
          authState: AuthState.error,
        ),
      );
      return false;
    }
  }

  Future<bool> loginAsGuest() async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      try {
        await _authRepo.logout();
      } catch (_) {}
      try {
        await LocalDatabaseService.instance.close();
      } catch (_) {}
      final guest = UserProfile(
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
      );
      emit(
        state.copyWith(
          user: guest,
          authState: AuthState.guest,
          isLoading: false,
        ),
      );
      return true;
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
      return false;
    }
  }

  void setUser(UserProfile profile) {
    emit(
      state.copyWith(
        user: profile,
        authState: profile.isGuest ? AuthState.guest : AuthState.authenticated,
      ),
    );
  }

  void setGuest() {
    loginAsGuest();
  }

  Future<void> logout() async {
    emit(state.copyWith(isLoading: true));
    try {
      await _firebaseAuth.signOut();
    } catch (_) {}
    try {
      await NotificationService.instance.cancelDailyReminder();
    } catch (_) {}
    try {
      await _authRepo.logout();
    } catch (_) {}
    try {
      await LocalDatabaseService.instance.close();
    } catch (_) {}
    emit(UserState.initial());
  }

  Future<bool> deleteAccount() async {
    emit(state.copyWith(isLoading: true));
    final userId = state.user.id;
    bool backendSuccess = true;
    try {
      if (!state.isGuest && await _authRepo.hasStoredTokens) {
        try {
          await _authRepo.deleteAccount();
        } catch (be) {
          backendSuccess = false;
        }
      }
      await LocalDatabaseService.instance.wipeAllLocalDatabases(userId);
      await UploadQueueService.instance.clearQueue();
      await SessionRepository.instance.clearAllLocalAudioFiles();
      await const FlutterSecureStorage().deleteAll();
      await logout();
      return backendSuccess;
    } catch (e) {
      try {
        await LocalDatabaseService.instance.wipeAllLocalDatabases(userId);
        await UploadQueueService.instance.clearQueue();
        await SessionRepository.instance.clearAllLocalAudioFiles();
        await const FlutterSecureStorage().deleteAll();
        await logout();
      } catch (_) {}
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
      return false;
    }
  }

  Future<void> updateProfile({
    String? name,
    String? email,
    String? role,
    String? targetGoal,
    String? experienceLevel,
    String? targetIndustry,
    String? feedbackTone,
  }) async {
    final current = state.user;
    final updated = UserProfile(
      id: current.id,
      name: name ?? current.name,
      email: email ?? current.email,
      role: role ?? current.role,
      targetGoal: targetGoal ?? current.targetGoal,
      experienceLevel: experienceLevel ?? current.experienceLevel,
      targetIndustry: targetIndustry ?? current.targetIndustry,
      feedbackTone: feedbackTone ?? current.feedbackTone,
      isGuest: current.isGuest,
      darkMode: current.darkMode,
      avatarUrl: current.avatarUrl,
      createdAt: current.createdAt,
      settings: current.settings,
      sessionsCompleted: current.sessionsCompleted,
      avgScore: current.avgScore,
      memberSince: current.memberSince,
    );
    emit(state.copyWith(user: updated));

    if (state.isGuest || !state.isAuthenticated) {
      return;
    }
    final fields = <String, dynamic>{};
    if (name != null && name.trim().isNotEmpty) {
      fields['full_name'] = name.trim();
    }
    if (role != null && role.trim().isNotEmpty) {
      fields['role_occupation'] = role.trim();
    }
    if (targetGoal != null && targetGoal.trim().isNotEmpty) {
      fields['primary_objective'] = targetGoal.trim();
    }
    if (experienceLevel != null && experienceLevel.trim().isNotEmpty) {
      fields['experience_level'] = experienceLevel.trim();
    }
    if (targetIndustry != null && targetIndustry.trim().isNotEmpty) {
      fields['target_industry'] = targetIndustry.trim();
    }
    if (feedbackTone != null && feedbackTone.trim().isNotEmpty) {
      fields['feedback_style'] = feedbackTone.trim();
    }

    if (fields.isNotEmpty) {
      try {
        final serverData = await _authRepo.updateMe(fields);
        emit(state.copyWith(user: UserProfile.fromJson(serverData)));
      } catch (_) {}
    }
  }

  Future<bool> uploadAvatar(String filePath) async {
    emit(state.copyWith(isLoading: true));
    try {
      final updated = await _authRepo.uploadAvatar(filePath);
      emit(
        state.copyWith(user: UserProfile.fromJson(updated), isLoading: false),
      );
      return true;
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
      return false;
    }
  }
}
