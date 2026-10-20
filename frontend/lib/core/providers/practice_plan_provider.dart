import 'package:flutter/foundation.dart';
import '../models/practice_drill.dart';
import '../repositories/practice_plan_repository.dart';

/// Provider for managing personalized practice plans, targeted drills,
/// dropdown visibility, and drill completions across Home and Progress screens.
class PracticePlanProvider extends ChangeNotifier {
  final _repo = PracticePlanRepository.instance;
  PracticePlan? _plan;
  bool _isLoading = false;
  bool _isCollapsed = false; // Dropdown expanded by default

  PracticePlanProvider() {
    _plan = _repo.cachedPlan;
    _repo.planNotifier.addListener(_onRepoPlanChanged);
  }

  void _onRepoPlanChanged() {
    _plan = _repo.planNotifier.value;
    notifyListeners();
  }

  @override
  void dispose() {
    _repo.planNotifier.removeListener(_onRepoPlanChanged);
    super.dispose();
  }

  PracticePlan? get plan => _plan ?? _repo.cachedPlan;
  bool get isLoading => _isLoading;
  bool get isCollapsed => _isCollapsed;

  List<PracticeDrill> get allDrills => plan?.drills ?? [];
  List<PracticeDrill> get pendingDrills =>
      (plan?.drills ?? []).where((d) => !d.isCompleted).toList();
  List<PracticeDrill> get completedDrills =>
      (plan?.drills ?? []).where((d) => d.isCompleted).toList();

  bool get hasPendingDrills => pendingDrills.isNotEmpty;
  bool get hasCompletedDrills => completedDrills.isNotEmpty;
  bool get allCompleted => allDrills.isNotEmpty && pendingDrills.isEmpty;

  void toggleCollapsed() {
    _isCollapsed = !_isCollapsed;
    notifyListeners();
  }

  void setCollapsed(bool value) {
    if (_isCollapsed != value) {
      _isCollapsed = value;
      notifyListeners();
    }
  }

  Future<void> loadPlan({
    bool forceRefresh = false,
    bool isGuest = false,
  }) async {
    if (isGuest) {
      _plan = PracticePlanRepository.defaultFallbackPlan;
      _isLoading = false;
      notifyListeners();
      return;
    }

    if (_plan == null) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final fetched = await _repo.getPracticePlan(forceRefresh: forceRefresh);
      _plan = fetched;
    } catch (_) {
      _plan ??= PracticePlanRepository.defaultFallbackPlan;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> completeDrill(
    String drillId, {
    String? sessionId,
    bool syncToBackend = true,
  }) async {
    final success = await _repo.completeDrill(
      drillId,
      sessionId: sessionId,
      syncToBackend: syncToBackend,
    );
    _plan = _repo.cachedPlan;
    notifyListeners();
    return success;
  }

  /// Resets practice plan cache and in-memory state.
  void reset() {
    _plan = null;
    _isLoading = false;
    _isCollapsed = false;
    _repo.resetPlan();
    notifyListeners();
  }
}
