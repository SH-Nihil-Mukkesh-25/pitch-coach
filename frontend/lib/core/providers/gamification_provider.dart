import 'package:flutter/material.dart';
import '../models/gamification_models.dart';
import '../repositories/gamification_repository.dart';

/// State management for Feature 11: Weekly Challenges and Privacy-Preserving Leaderboard.
class GamificationProvider extends ChangeNotifier {
  final GamificationRepository _repo;

  GamificationProvider({GamificationRepository? repo})
      : _repo = repo ?? GamificationRepository.instance;

  List<WeeklyChallenge> _challenges = [];
  LeaderboardResponse _leaderboard = LeaderboardResponse.empty;
  bool _isLoading = false;
  bool _isClaiming = false;
  String? _error;
  int _earnedPoints = 0;

  List<WeeklyChallenge> get challenges => _challenges;
  LeaderboardResponse get leaderboard => _leaderboard;
  bool get isLoading => _isLoading;
  bool get isClaiming => _isClaiming;
  String? get error => _error;
  int get earnedPoints => _earnedPoints;
  bool get isOptedIn => _leaderboard.userOptedIn;

  Future<void> loadGamificationData({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }
    _error = null;

    try {
      final results = await Future.wait([
        _repo.getChallenges(),
        _repo.getLeaderboard(),
      ]);

      _challenges = results[0] as List<WeeklyChallenge>;
      _leaderboard = results[1] as LeaderboardResponse;

      // Sum points of claimed challenges
      _earnedPoints = _challenges
          .where((c) => c.isClaimed)
          .fold(0, (sum, c) => sum + c.rewardPoints);
    } catch (e) {
      _error = e.toString();
      // Provide fallback mock challenges if offline or guest mode
      if (_challenges.isEmpty) {
        _challenges = const [
          WeeklyChallenge(
            id: 'zero_fillers',
            title: 'Zero Fillers Take',
            description: 'Complete a session (min 30s) with 0 filler words.',
            icon: 'shield-check',
            currentProgress: 0,
            target: 1,
            isCompleted: false,
            isClaimed: false,
            rewardPoints: 100,
          ),
          WeeklyChallenge(
            id: 'pacing_pro',
            title: 'Pacing Pro',
            description:
                'Deliver a speech within the optimal 120-160 WPM pace band (min 30s).',
            icon: 'speed',
            currentProgress: 0,
            target: 1,
            isCompleted: false,
            isClaimed: false,
            rewardPoints: 150,
          ),
          WeeklyChallenge(
            id: 'consistency_streak',
            title: 'Consistency Streak',
            description: 'Complete 3 practice sessions during this week.',
            icon: 'calendar-check',
            currentProgress: 0,
            target: 3,
            isCompleted: false,
            isClaimed: false,
            rewardPoints: 200,
          ),
        ];
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> claimChallenge(String challengeId) async {
    _isClaiming = true;
    notifyListeners();

    try {
      final res = await _repo.claimChallenge(challengeId);
      if (res.success) {
        // Update local challenge state
        _challenges = _challenges.map((c) {
          if (c.id == challengeId) {
            return c.copyWith(isClaimed: true);
          }
          return c;
        }).toList();

        _earnedPoints = res.totalClaimedPoints;
        _isClaiming = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _error = e.toString();
    }

    _isClaiming = false;
    notifyListeners();
    return false;
  }

  Future<void> toggleLeaderboardOptIn(bool optIn) async {
    try {
      final updatedBoard = await _repo.getLeaderboard(optIn: optIn);
      _leaderboard = updatedBoard;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Resets challenges, leaderboard, and points in memory.
  void reset() {
    _challenges = [];
    _leaderboard = LeaderboardResponse.empty;
    _isLoading = false;
    _isClaiming = false;
    _error = null;
    _earnedPoints = 0;
    notifyListeners();
  }
}
