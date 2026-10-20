import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/slide_coach_models.dart';
import '../repositories/slide_coach_repository.dart';
import '../services/notification_service.dart';
import 'settings_provider.dart';

class SlideCoachProvider extends ChangeNotifier {
  final _repo = SlideCoachRepository.instance;
  static const String _storageActiveDeckKey = 'active_processing_deck_id';
  final _storage = const FlutterSecureStorage();

  // ── Upload State ──
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _uploadError;

  bool get isUploading => _isUploading;
  double get uploadProgress => _uploadProgress;
  String? get uploadError => _uploadError;

  // ── Processing / Polling State ──
  String? _activeDeckId;
  SlideDeckStatusModel? _status;
  bool _isPolling = false;
  String? _pollError;
  Timer? _pollTimer;

  // Completed announcement modal trigger
  SlideDeckModel? _completedDeckToAnnounce;
  SlideDeckModel? get completedDeckToAnnounce => _completedDeckToAnnounce;

  String? get activeDeckId => _activeDeckId;
  SlideDeckStatusModel? get status => _status;
  bool get isPolling => _isPolling;
  String? get pollError => _pollError;
  bool get hasActiveBackgroundProcessing =>
      _isPolling || (_status != null && _status!.isProcessing);

  void dismissCompletedAnnouncement() {
    _completedDeckToAnnounce = null;
    notifyListeners();
  }

  // ── Saved Decks / History State ──
  List<SlideDeckModel> _savedDecks = [];
  bool _isLoadingSavedDecks = false;
  String? _savedDecksError;

  List<SlideDeckModel> get savedDecks => _savedDecks;
  bool get isLoadingSavedDecks => _isLoadingSavedDecks;
  String? get savedDecksError => _savedDecksError;

  Future<void> loadSavedDecks({bool forceRefresh = false}) async {
    _isLoadingSavedDecks = true;
    _savedDecksError = null;
    notifyListeners();

    try {
      _savedDecks = await _repo.listDecks();
      _isLoadingSavedDecks = false;
      notifyListeners();
    } catch (e) {
      _isLoadingSavedDecks = false;
      _savedDecksError = e.toString();
      notifyListeners();
    }
  }

  Future<void> triggerReanalysis(String deckId) async {
    try {
      await _repo.reanalyzeDeck(deckId);
      startPolling(deckId);
    } catch (e) {
      _pollError = e.toString();
      notifyListeners();
    }
  }

  // ── Active Deck Review State ──
  SlideDeckModel? _deck;
  int _currentSlideIndex = 0;
  bool _isLoadingDeck = false;

  SlideDeckModel? get deck => _deck;
  int get currentSlideIndex => _currentSlideIndex;
  bool get isLoadingDeck => _isLoadingDeck;

  SlideCoachingModel? get currentSlide {
    if (_deck == null || _deck!.slides.isEmpty) return null;
    if (_currentSlideIndex < 0 || _currentSlideIndex >= _deck!.slides.length) {
      return _deck!.slides.first;
    }
    return _deck!.slides[_currentSlideIndex];
  }

  @visibleForTesting
  void setDeckForTesting(SlideDeckModel deck) {
    _deck = deck;
    _currentSlideIndex = 0;
    notifyListeners();
  }

  // ── Rehearsal State ──
  bool _isRehearsing = false;
  final List<Map<String, dynamic>> _rehearsalTimestamps = [];
  DateTime? _rehearsalStartTime;
  bool _isAnalyzingRehearsal = false;
  DeckRehearsalResponseModel? _latestRehearsalResult;
  String? _rehearsalError;

  bool get isRehearsing => _isRehearsing;
  bool get isAnalyzingRehearsal => _isAnalyzingRehearsal;
  DeckRehearsalResponseModel? get latestRehearsalResult =>
      _latestRehearsalResult;
  String? get rehearsalError => _rehearsalError;

  // ── Q&A State ──
  List<QaQuestionModel> _qaQuestions = [];
  bool _isLoadingQuestions = false;
  int _currentQaIndex = 0;
  bool _isEvaluatingAnswer = false;
  QaEvaluationModel? _latestQaEvaluation;
  String? _qaError;

  List<QaQuestionModel> get qaQuestions => _qaQuestions;
  bool get isLoadingQuestions => _isLoadingQuestions;
  int get currentQaIndex => _currentQaIndex;
  bool get isEvaluatingAnswer => _isEvaluatingAnswer;
  QaEvaluationModel? get latestQaEvaluation => _latestQaEvaluation;
  String? get qaError => _qaError;

  QaQuestionModel? get currentQuestion {
    if (_qaQuestions.isEmpty) return null;
    if (_currentQaIndex < 0 || _currentQaIndex >= _qaQuestions.length) {
      return _qaQuestions.first;
    }
    return _qaQuestions[_currentQaIndex];
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Restore State on App Launch or Return
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> restoreActiveDeckIfProcessing() async {
    try {
      final storedId = await _storage.read(key: _storageActiveDeckKey);
      if (storedId == null || storedId.trim().isEmpty) return;
      if (_isPolling && _activeDeckId == storedId) return;

      _activeDeckId = storedId;
      final st = await _repo.getStatus(storedId);
      _status = st;

      if (st.status == 'done') {
        await _storage.delete(key: _storageActiveDeckKey);
        await loadDeck(storedId);
        if (_deck != null) {
          _completedDeckToAnnounce = _deck;
          final alertEnabled =
              await SettingsProvider.isSlideDeckReadyAlertEnabled();
          if (alertEnabled) {
            try {
              await NotificationService.instance.showInstantNotification(
                'Slide Deck Ready',
                'Your presentation "${_deck!.fileName}" has been analyzed and is ready for rehearsal.',
              );
            } catch (e) {
              debugPrint('Failed to send instant notification: $e');
            }
          }
        }
        notifyListeners();
      } else if (st.status == 'failed') {
        await _storage.delete(key: _storageActiveDeckKey);
        _pollError = st.error ?? 'Analysis failed';
        notifyListeners();
      } else {
        // Still in progress (rendering / reading_slides / writing_coaching)
        startPolling(storedId);
      }
    } catch (e) {
      debugPrint('Error restoring active deck: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Upload & Polling Actions
  // ─────────────────────────────────────────────────────────────────────────

  Future<String?> uploadAndStartAnalysis({
    required String filePath,
    required String fileName,
    required String audience,
    required int timeLimitSeconds,
    required String goal,
  }) async {
    _isUploading = true;
    _uploadProgress = 0.0;
    _uploadError = null;
    notifyListeners();

    try {
      final res = await _repo.uploadDeck(
        filePath: filePath,
        fileName: fileName,
        audience: audience,
        timeLimitSeconds: timeLimitSeconds,
        goal: goal,
        onProgress: (sent, total) {
          if (total > 0) {
            _uploadProgress = sent / total;
            notifyListeners();
          }
        },
      );

      final deckId = res['deck_id'] as String;
      _activeDeckId = deckId;
      _isUploading = false;
      await _storage.write(key: _storageActiveDeckKey, value: deckId);
      notifyListeners();

      // Start status polling
      startPolling(deckId);
      return deckId;
    } catch (e) {
      _isUploading = false;
      _uploadError = e.toString();
      notifyListeners();
      return null;
    }
  }

  void startPolling(String deckId) {
    _activeDeckId = deckId;
    _pollTimer?.cancel();
    _isPolling = true;
    _pollError = null;
    _storage.write(key: _storageActiveDeckKey, value: deckId);
    notifyListeners();

    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final st = await _repo.getStatus(deckId);
        _status = st;
        notifyListeners();

        if (st.status == 'done') {
          timer.cancel();
          _isPolling = false;
          await _storage.delete(key: _storageActiveDeckKey);
          await loadDeck(deckId);
          if (_deck != null) {
            _completedDeckToAnnounce = _deck;
            final alertEnabled =
                await SettingsProvider.isSlideDeckReadyAlertEnabled();
            if (alertEnabled) {
              try {
                await NotificationService.instance.showInstantNotification(
                  'Slide Deck Ready',
                  'Your presentation "${_deck!.fileName}" has been analyzed and is ready for rehearsal.',
                );
              } catch (e) {
                debugPrint('Failed to send notification: $e');
              }
            }
          }
          notifyListeners();
        } else if (st.status == 'failed') {
          timer.cancel();
          _isPolling = false;
          await _storage.delete(key: _storageActiveDeckKey);
          _pollError = st.error ?? 'Analysis failed';
          notifyListeners();
        }
      } catch (e) {
        _pollError = e.toString();
        notifyListeners();
      }
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _isPolling = false;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Deck Loading & Slide Editing
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> loadDeck(String deckId) async {
    _isLoadingDeck = true;
    _activeDeckId = deckId;
    notifyListeners();

    try {
      _deck = await _repo.getDeck(deckId);
      _currentSlideIndex = 0;
      _isLoadingDeck = false;
      notifyListeners();
    } catch (e) {
      _isLoadingDeck = false;
      _pollError = e.toString();
      notifyListeners();
    }
  }

  void selectSlide(int index) {
    if (_deck == null || index < 0 || index >= _deck!.slides.length) return;
    _currentSlideIndex = index;
    notifyListeners();
  }

  Timer? _patchDebounce;

  void updateCurrentSlideTalkingPoints(List<String> points) {
    final cur = currentSlide;
    if (cur == null || _activeDeckId == null) return;
    cur.talkingPoints = points;
    notifyListeners();

    _patchDebounce?.cancel();
    _patchDebounce = Timer(const Duration(milliseconds: 800), () {
      _repo.patchSlide(_activeDeckId!, cur.slideNumber, talkingPoints: points);
    });
  }

  void updateCurrentSlideScript(String script) {
    final cur = currentSlide;
    if (cur == null || _activeDeckId == null) return;
    cur.suggestedScript = script;
    notifyListeners();

    _patchDebounce?.cancel();
    _patchDebounce = Timer(const Duration(milliseconds: 800), () {
      _repo.patchSlide(
        _activeDeckId!,
        cur.slideNumber,
        suggestedScript: script,
      );
    });
  }

  void updateCurrentSlideTargetDuration(int seconds) {
    final cur = currentSlide;
    if (cur == null || _activeDeckId == null) return;
    cur.targetDurationSeconds = seconds;
    notifyListeners();

    _patchDebounce?.cancel();
    _patchDebounce = Timer(const Duration(milliseconds: 800), () {
      _repo.patchSlide(
        _activeDeckId!,
        cur.slideNumber,
        targetDurationSeconds: seconds,
      );
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Rehearsal Mode Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  void startRehearsal() {
    _isRehearsing = true;
    _rehearsalTimestamps.clear();
    _rehearsalStartTime = DateTime.now();
    _latestRehearsalResult = null;
    _rehearsalError = null;

    // Log slide 1 entered at 0ms
    _rehearsalTimestamps.add({
      'slide_number': _deck?.slides.first.slideNumber ?? 1,
      'entered_at_ms': 0,
    });
    notifyListeners();
  }

  void recordSlideTransition(int nextSlideNumber) {
    if (!_isRehearsing || _rehearsalStartTime == null) return;
    final elapsedMs = DateTime.now()
        .difference(_rehearsalStartTime!)
        .inMilliseconds;
    _rehearsalTimestamps.add({
      'slide_number': nextSlideNumber,
      'entered_at_ms': elapsedMs,
    });
  }

  Future<DeckRehearsalResponseModel?> finishRehearsal(String audioPath) async {
    if (_activeDeckId == null) return null;
    _isRehearsing = false;
    _isAnalyzingRehearsal = true;
    _rehearsalError = null;
    notifyListeners();

    try {
      final res = await _repo.rehearse(
        deckId: _activeDeckId!,
        audioPath: audioPath,
        slideTimestamps: _rehearsalTimestamps,
      );
      _latestRehearsalResult = res;
      _isAnalyzingRehearsal = false;
      notifyListeners();
      return res;
    } catch (e) {
      _isAnalyzingRehearsal = false;
      _rehearsalError = e.toString();
      notifyListeners();
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Q&A Mode Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> loadQaQuestions() async {
    if (_activeDeckId == null) return;
    _isLoadingQuestions = true;
    _qaError = null;
    _latestQaEvaluation = null;
    notifyListeners();

    try {
      _qaQuestions = await _repo.getQaQuestions(_activeDeckId!);
      _currentQaIndex = 0;
      _isLoadingQuestions = false;
      notifyListeners();
    } catch (e) {
      _isLoadingQuestions = false;
      _qaError = e.toString();
      notifyListeners();
    }
  }

  void nextQuestion() {
    if (_currentQaIndex < _qaQuestions.length - 1) {
      _currentQaIndex++;
      _latestQaEvaluation = null;
      notifyListeners();
    }
  }

  void prevQuestion() {
    if (_currentQaIndex > 0) {
      _currentQaIndex--;
      _latestQaEvaluation = null;
      notifyListeners();
    }
  }

  Future<QaEvaluationModel?> submitAnswer(String audioPath) async {
    final q = currentQuestion;
    if (_activeDeckId == null || q == null) return null;

    _isEvaluatingAnswer = true;
    _qaError = null;
    notifyListeners();

    try {
      final res = await _repo.submitQaAnswer(
        deckId: _activeDeckId!,
        questionId: q.id,
        audioPath: audioPath,
      );
      _latestQaEvaluation = res;
      _isEvaluatingAnswer = false;
      notifyListeners();
      return res;
    } catch (e) {
      _isEvaluatingAnswer = false;
      _qaError = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Cancels polling, clears cached decks and in-memory state, and wipes saved active deck ID.
  Future<void> reset() async {
    _pollTimer?.cancel();
    _patchDebounce?.cancel();
    _isUploading = false;
    _uploadProgress = 0.0;
    _uploadError = null;
    _activeDeckId = null;
    _status = null;
    _isPolling = false;
    _pollError = null;
    _completedDeckToAnnounce = null;
    _savedDecks = [];
    _isLoadingSavedDecks = false;
    _savedDecksError = null;
    _deck = null;
    _currentSlideIndex = 0;
    _isLoadingDeck = false;
    _qaQuestions = [];
    _currentQaIndex = 0;
    _isLoadingQuestions = false;
    _latestQaEvaluation = null;
    _isEvaluatingAnswer = false;
    _qaError = null;
    try {
      await _storage.delete(key: _storageActiveDeckKey);
    } catch (_) {}
    notifyListeners();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _patchDebounce?.cancel();
    super.dispose();
  }
}
