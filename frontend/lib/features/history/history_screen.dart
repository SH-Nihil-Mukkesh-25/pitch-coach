import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/models/slide_coach_models.dart';
import '../../core/providers/slide_coach_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/repositories/demo_repository.dart';
import '../../core/models/session_result.dart';
import '../../core/repositories/session_repository.dart';
import '../../core/services/outbox_worker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/circular_gauge_painter.dart';
import '../../core/widgets/theme_toggle_button.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  String _searchQuery = '';
  DateTime? _selectedDate; // DatePicker filter (Unit 2)

  // Real data from API
  List<SessionSummary> _sessions = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _pendingOutboxCount = 0;
  bool _isSyncingOutbox = false;

  final List<String> _filterChips = [
    'All',
    'Interview',
    'Presentation',
    'Free Talk',
    'Slide Decks',
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final cached = SessionRepository.instance.cachedSessions;
    if (cached != null && cached.isNotEmpty) {
      _sessions = cached;
      _isLoading = false;
    }
    _loadSessions(isInitial: cached == null || cached.isEmpty);
    _checkOutboxCount();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<SlideCoachProvider>().loadSavedDecks();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSessions({
    bool isInitial = false,
    bool force = false,
  }) async {
    if (_selectedFilter == 'Slide Decks') {
      if (mounted) setState(() => _isLoading = false);
      await context.read<SlideCoachProvider>().loadSavedDecks(
        forceRefresh: force,
      );
      return;
    }

    if (isInitial && _sessions.isEmpty) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      if (context.read<UserProvider>().isGuest) {
        if (mounted) {
          setState(() => _sessions = DemoRepository.instance.sessions);
        }
        return;
      }
      // Map filter chip → API mode value
      final modeParam = _selectedFilter == 'All'
          ? null
          : _selectedFilter == 'Interview'
          ? 'interview'
          : _selectedFilter == 'Presentation'
          ? 'presentation'
          : 'free_talk';

      final sessions = await SessionRepository.instance.listSessions(
        mode: modeParam,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        limit: 50,
        forceRefresh: force,
      );

      if (mounted) {
        setState(() {
          _sessions = sessions;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted && _sessions.isEmpty) {
        setState(
          () => _errorMessage = 'Could not load sessions. Pull to retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
      _checkOutboxCount();
    }
  }

  Future<void> _checkOutboxCount() async {
    if (!mounted) return;
    try {
      final user = context.read<UserProvider>().user;
      if (user.id.isNotEmpty && user.id != 'guest') {
        final count = await OutboxWorker.instance.getPendingCount(
          userId: user.id,
        );
        if (mounted) {
          setState(() => _pendingOutboxCount = count);
        }
      }
    } catch (_) {}
  }

  Future<void> _syncPendingOutbox() async {
    if (_isSyncingOutbox) return;
    setState(() => _isSyncingOutbox = true);
    try {
      final user = context.read<UserProvider>().user;
      await OutboxWorker.instance.process(userId: user.id);
      await _checkOutboxCount();
      await _loadSessions(force: true);
    } finally {
      if (mounted) {
        setState(() => _isSyncingOutbox = false);
      }
    }
  }

  Widget _buildOutboxBanner() {
    if (_pendingOutboxCount == 0) return const SizedBox.shrink();
    return Container(
      key: const Key('history_outbox_banner'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warningAmber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.warningAmber.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_upload_outlined,
            color: AppColors.warningAmber,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_pendingOutboxCount recording${_pendingOutboxCount > 1 ? 's' : ''} pending sync',
                  style: AppTextStyles.bodyMOf(context).copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
                Text(
                  'Saved locally. Will sync automatically when online.',
                  style: AppTextStyles.captionOf(context).copyWith(
                    color: AppColors.textSecondaryOf(context),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            key: const Key('history_sync_now_button'),
            onPressed: _isSyncingOutbox ? null : _syncPendingOutbox,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: AppColors.primaryPurple,
            ),
            child: _isSyncingOutbox
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primaryPurple,
                      ),
                    ),
                  )
                : const Text(
                    'Sync Now',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
          ),
        ],
      ),
    );
  }

  /// Group sessions by relative date label ("Today", "Yesterday", "This Week", older date strings).
  Map<String, List<SessionSummary>> get _groupedSessions {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));

    final Map<String, List<SessionSummary>> groups = {};

    for (final s in _sessions) {
      final d = s.createdAt.toLocal();
      final sessionDay = DateTime(d.year, d.month, d.day);

      String label;
      if (sessionDay == today) {
        label = 'Today';
      } else if (sessionDay == yesterday) {
        label = 'Yesterday';
      } else if (sessionDay.isAfter(weekAgo)) {
        label = 'This Week';
      } else {
        label = s.dateFormatted; // e.g. "Mon, Sep 15"
      }

      groups.putIfAbsent(label, () => []).add(s);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'History',
                    style: AppTextStyles.headingXL.copyWith(
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                  // Theme Toggle & DatePicker filter button (Unit 2)
                  Row(
                    children: [
                      const ThemeToggleButton(size: 38, compact: true),
                      const SizedBox(width: 8),
                      if (_selectedDate != null)
                        TextButton(
                          onPressed: () {
                            setState(() => _selectedDate = null);
                            _loadSessions();
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Clear',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.primaryPurple,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: _selectedDate != null
                                ? AppColors.primaryPurple
                                : AppColors.cardOf(context),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.borderOf(context),
                            ),
                          ),
                          child: Icon(
                            Icons.calendar_month_rounded,
                            size: 20,
                            color: _selectedDate != null
                                ? Colors.white
                                : AppColors.textPrimaryOf(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 2. Search Bar
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.cardOf(context),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.borderOf(context)),
                  boxShadow: AppColors.softShadowOf(context),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() => _searchQuery = val);
                  },
                  onSubmitted: (_) => _loadSessions(),
                  style: AppTextStyles.bodyM.copyWith(
                    color: AppColors.textPrimaryOf(context),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search sessions...',
                    hintStyle: AppTextStyles.bodyM.copyWith(
                      color: AppColors.textSecondaryOf(
                        context,
                      ).withValues(alpha: 0.7),
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: AppColors.textSecondaryOf(context),
                      size: 20,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                              _loadSessions();
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 3. Filter Chips Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _filterChips.map((chip) {
                    final isSelected = _selectedFilter == chip;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(chip),
                        selected: isSelected,
                        selectedColor: AppColors.primaryPurple,
                        backgroundColor: AppColors.cardOf(context),
                        labelStyle: AppTextStyles.caption.copyWith(
                          color: isSelected
                              ? Colors.white
                              : AppColors.textPrimaryOf(context),
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.primaryPurple
                                : AppColors.borderOf(context),
                          ),
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedFilter = chip);
                            if (chip == 'Slide Decks') {
                              context
                                  .read<SlideCoachProvider>()
                                  .loadSavedDecks();
                            } else {
                              _loadSessions();
                            }
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 16),
              _buildOutboxBanner(),

              // 4. Session List / Loading / Error / Empty State
              Expanded(
                child: _selectedFilter == 'Slide Decks'
                    ? _buildSlideDeckSection(context)
                    : _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primaryPurple,
                          ),
                        ),
                      )
                    : _errorMessage != null
                    ? _buildErrorState()
                    : _sessions.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: () => _loadSessions(force: true),
                        color: AppColors.primaryPurple,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: _groupedSessions.keys.length,
                          itemBuilder: (context, index) {
                            final groupKey = _groupedSessions.keys.elementAt(
                              index,
                            );
                            final sessionsInGroup = _groupedSessions[groupKey]!;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8.0,
                                  ),
                                  child: Text(
                                    groupKey,
                                    style: AppTextStyles.headingMOf(context)
                                        .copyWith(
                                          fontSize: 15,
                                          color: AppColors.textSecondaryOf(
                                            context,
                                          ),
                                        ),
                                  ),
                                ),
                                ...sessionsInGroup.map(
                                  (s) => Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 12.0,
                                    ),
                                    child: _buildSessionCard(context, s),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionCard(BuildContext context, SessionSummary session) {
    final score = session.overallScore;
    final scoreColor = score >= 80
        ? AppColors.successGreen
        : score >= 60
        ? AppColors.warningAmber
        : AppColors.dangerRed;

    final icon = session.mode == 'presentation'
        ? Icons.bar_chart_rounded
        : session.mode == 'free_talk'
        ? Icons.mic_rounded
        : Icons.event_seat_rounded;
    final iconBg = session.mode == 'presentation'
        ? AppColors.accentBlue
        : session.mode == 'free_talk'
        ? AppColors.accentGreen
        : AppColors.primaryPurple;

    return InkWell(
      onTap: () => context.push('/results', extra: session.id),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardOf(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderOf(context)),
          boxShadow: AppColors.softShadowOf(context),
        ),
        // Use ListTile for session cards (Unit 1)
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 8,
          ),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconBg, size: 24),
          ),
          title: Text(
            session.topicOrQuestion,
            style: AppTextStyles.headingMOf(
              context,
            ).copyWith(fontSize: 15, fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(
                session.modeLabel,
                style: AppTextStyles.captionOf(
                  context,
                ).copyWith(color: AppColors.textSecondaryOf(context)),
              ),
              const SizedBox(height: 2),
              Text(
                '${session.createdAt.toLocal().hour.toString().padLeft(2, '0')}:'
                '${session.createdAt.toLocal().minute.toString().padLeft(2, '0')}'
                ' · ${session.durationFormatted}',
                style: AppTextStyles.captionOf(context).copyWith(
                  color: AppColors.textSecondaryOf(
                    context,
                  ).withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          trailing: session.analysisFailed
              ? const Tooltip(
                  message: 'Analysis failed — tap to retry',
                  child: Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.warningAmber,
                    size: 30,
                  ),
                )
              : !session.isAnalyzed
              ? Container(
                  key: Key('pending_indicator_${session.id}'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warningAmber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_upload_outlined,
                        size: 14,
                        color: AppColors.warningAmber,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Pending',
                        style: TextStyle(
                          color: AppColors.warningAmber,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              : CircularGauge(
                  value: score,
                  size: 46,
                  strokeWidth: 4.5,
                  centerBigText: '${score.round()}%',
                  gradientColors: [scoreColor, scoreColor],
                ),
          isThreeLine: true,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Image.asset illustration (Unit 1)
          Image.asset(
            'assets/images/empty_history.png',
            height: 160,
            errorBuilder: (_, _, _) => Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mic_none_rounded,
                size: 54,
                color: AppColors.primaryPurple,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('No sessions found', style: AppTextStyles.headingLOf(context)),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'No results for "$_searchQuery". Try a different search.'
                : _selectedDate != null
                ? 'No sessions on the selected date.'
                : 'Start practicing to build your session history.',
            style: AppTextStyles.bodyMOf(
              context,
            ).copyWith(color: AppColors.textSecondaryOf(context)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => context.push('/interview'),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start Practicing'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off_rounded,
            size: 48,
            color: AppColors.textSecondaryOf(context),
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'Something went wrong.',
            style: AppTextStyles.bodyMOf(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadSessions,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  /// Show the DatePicker and reload sessions filtered to that date (Unit 2).
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: AppColors.primaryPurple,
                    onPrimary: Colors.white,
                    surface: AppColors.cardDark,
                    onSurface: AppColors.textOnDark,
                  )
                : const ColorScheme.light(
                    primary: AppColors.primaryPurple,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: AppColors.textPrimaryDark,
                  ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadSessions();
    }
  }

  Widget _buildSlideDeckSection(BuildContext context) {
    final slideProvider = context.watch<SlideCoachProvider>();
    if (slideProvider.isLoadingSavedDecks && slideProvider.savedDecks.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryPurple),
        ),
      );
    }

    if (slideProvider.savedDecksError != null &&
        slideProvider.savedDecks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 48,
              color: AppColors.textSecondaryOf(context),
            ),
            const SizedBox(height: 16),
            Text(
              slideProvider.savedDecksError ?? 'Could not load slide decks.',
              style: AppTextStyles.bodyMOf(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context
                  .read<SlideCoachProvider>()
                  .loadSavedDecks(forceRefresh: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final query = _searchQuery.toLowerCase().trim();
    var decks = slideProvider.savedDecks;
    if (query.isNotEmpty) {
      decks = decks
          .where(
            (d) =>
                d.filename.toLowerCase().contains(query) ||
                d.goal.toLowerCase().contains(query) ||
                d.audience.toLowerCase().contains(query),
          )
          .toList();
    }
    if (_selectedDate != null) {
      decks = decks.where((d) {
        final dt = d.createdDateTime;
        if (dt == null) return false;
        return dt.year == _selectedDate!.year &&
            dt.month == _selectedDate!.month &&
            dt.day == _selectedDate!.day;
      }).toList();
    }

    if (decks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.picture_as_pdf_rounded,
                size: 54,
                color: AppColors.primaryPurple,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No slide decks found',
              style: AppTextStyles.headingLOf(context),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _searchQuery.isNotEmpty
                    ? 'No presentations matching "$_searchQuery".'
                    : _selectedDate != null
                    ? 'No presentation decks found on selected date.'
                    : 'Upload a PDF presentation to generate instant visual coaching, talking points, and pitch scripts.',
                style: AppTextStyles.bodyMOf(
                  context,
                ).copyWith(color: AppColors.textSecondaryOf(context)),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => context.push('/slide-coach'),
              icon: const Icon(Icons.cloud_upload_rounded),
              label: const Text('Upload Presentation'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          context.read<SlideCoachProvider>().loadSavedDecks(forceRefresh: true),
      color: AppColors.primaryPurple,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: decks.length,
        itemBuilder: (context, index) {
          final deck = decks[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: _buildSlideDeckCard(context, deck),
          );
        },
      ),
    );
  }

  Widget _buildSlideDeckCard(BuildContext context, SlideDeckModel deck) {
    final score = deck.deckSummary?.overallScore ?? 0;
    final scoreColor = score >= 80
        ? AppColors.successGreen
        : score >= 60
        ? AppColors.warningAmber
        : AppColors.dangerRed;

    final isDone = deck.status == 'done';
    final isProcessing = deck.status == 'processing';

    final slideCount = deck.slides.isNotEmpty
        ? deck.slides.length
        : deck.pageCount;
    final timeMin = (deck.timeLimitSeconds / 60).round();
    final audienceFormatted = deck.audience
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '',
        )
        .join(' ');

    return InkWell(
      onTap: () async {
        final provider = context.read<SlideCoachProvider>();
        if (isDone) {
          await provider.loadDeck(deck.id);
          if (context.mounted) context.push('/slide-coach/review');
        } else if (isProcessing) {
          provider.startPolling(deck.id);
          context.push('/slide-coach/processing');
        } else {
          _showReanalyzePrompt(context, deck);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardOf(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderOf(context)),
          boxShadow: AppColors.softShadowOf(context),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 8,
          ),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.picture_as_pdf_rounded,
              color: AppColors.primaryPurple,
              size: 24,
            ),
          ),
          title: Text(
            deck.filename,
            style: AppTextStyles.headingMOf(
              context,
            ).copyWith(fontSize: 15, fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(
                '$slideCount slides · $timeMin min · $audienceFormatted',
                style: AppTextStyles.captionOf(context).copyWith(
                  color: AppColors.textSecondaryOf(context),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${deck.timeFormatted} · ${deck.dateFormatted}',
                style: AppTextStyles.captionOf(context).copyWith(
                  color: AppColors.textSecondaryOf(
                    context,
                  ).withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isDone)
                CircularGauge(
                  value: score.toDouble(),
                  size: 46,
                  strokeWidth: 4.5,
                  centerBigText: '$score%',
                  gradientColors: [scoreColor, scoreColor],
                )
              else if (isProcessing)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryPurple,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${deck.progress}%',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primaryPurple,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              else
                const Tooltip(
                  message: 'Analysis failed — tap to re-analyze',
                  child: Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.dangerRed,
                    size: 28,
                  ),
                ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: AppColors.textSecondaryOf(context),
                  size: 20,
                ),
                color: AppColors.cardOf(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: AppColors.borderOf(context)),
                ),
                onSelected: (value) async {
                  final provider = context.read<SlideCoachProvider>();
                  if (value == 'review') {
                    await provider.loadDeck(deck.id);
                    if (context.mounted) context.push('/slide-coach/review');
                  } else if (value == 'rehearsal') {
                    await provider.loadDeck(deck.id);
                    if (context.mounted) context.push('/slide-coach/rehearsal');
                  } else if (value == 'qa') {
                    await provider.loadDeck(deck.id);
                    if (context.mounted) context.push('/slide-coach/qa');
                  } else if (value == 'reanalyze') {
                    _showReanalyzePrompt(context, deck);
                  }
                },
                itemBuilder: (context) => [
                  if (isDone) ...[
                    const PopupMenuItem(
                      value: 'review',
                      child: Row(
                        children: [
                          Icon(
                            Icons.dashboard_outlined,
                            size: 18,
                            color: AppColors.primaryPurple,
                          ),
                          SizedBox(width: 10),
                          Text('Open Review & Script'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'rehearsal',
                      child: Row(
                        children: [
                          Icon(
                            Icons.mic_outlined,
                            size: 18,
                            color: AppColors.accentBlue,
                          ),
                          SizedBox(width: 10),
                          Text('Practice Rehearsal'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'qa',
                      child: Row(
                        children: [
                          Icon(
                            Icons.question_answer_outlined,
                            size: 18,
                            color: AppColors.auroraCyan,
                          ),
                          SizedBox(width: 10),
                          Text('Audience Q&A Prep'),
                        ],
                      ),
                    ),
                  ],
                  const PopupMenuItem(
                    value: 'reanalyze',
                    child: Row(
                      children: [
                        Icon(
                          Icons.refresh_rounded,
                          size: 18,
                          color: AppColors.warningAmber,
                        ),
                        SizedBox(width: 10),
                        Text('Re-analyze with AI'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          isThreeLine: true,
        ),
      ),
    );
  }

  void _showReanalyzePrompt(BuildContext context, SlideDeckModel deck) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardOf(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.borderOf(context)),
        ),
        title: Text(
          'Re-compute with AI?',
          style: AppTextStyles.headingMOf(context),
        ),
        content: Text(
          'This will re-run the vision and speech coaching pipeline on "${deck.filename}". Any saved scripts will be regenerated.',
          style: AppTextStyles.bodyTextOf(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondaryOf(context)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final provider = context.read<SlideCoachProvider>();
              await provider.triggerReanalysis(deck.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Re-analysis started in background...'),
                  ),
                );
                context.push('/slide-coach/processing');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Re-analyze'),
          ),
        ],
      ),
    );
  }
}
