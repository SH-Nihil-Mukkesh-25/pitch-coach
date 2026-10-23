import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../../core/models/lesson_model.dart';
import '../../core/providers/gamification_provider.dart';
import '../../core/providers/practice_plan_provider.dart';
import '../../core/providers/session_results_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/providers/slide_coach_provider.dart';
import '../../core/providers/stats_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_atmosphere.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/settings_section.dart';
import '../../core/widgets/settings_skeleton.dart';
import '../../core/widgets/settings_tile.dart';
import '../../core/widgets/theme_toggle_button.dart';
import 'widgets/about_pitch_coach_dialog.dart';
import 'widgets/language_picker_sheet.dart';
import 'widgets/practice_goals_sheet.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploadingAvatar = false;
  double _avatarUploadProgress = 0.0;
  String _appVersionString = 'Pitch Coach';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAllData();
    });
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersionString =
              'Pitch Coach v${info.version} (${info.buildNumber})';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _appVersionString = 'Pitch Coach v1.0.0';
        });
      }
    }
  }

  Future<void> _refreshAllData() async {
    final userProvider = context.read<UserProvider>();
    final statsProvider = context.read<StatsProvider>();
    final settingsProvider = context.read<SettingsProvider>();

    await Future.wait([
      userProvider.fetchUserProfile(),
      statsProvider.loadAll(force: true),
      settingsProvider.initialize(),
    ]);
  }

  // ── Avatar Management ─────────────────────────────────────────────────────

  void _showAvatarOptionsSheet() {
    final user = context.read<UserProvider>().user;
    final hasAvatar = user.avatarUrl != null && user.avatarUrl!.isNotEmpty;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppColors.cardOf(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.textSecondaryOf(
                        context,
                      ).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Profile Photo',
                  style: AppTextStyles.headingM.copyWith(
                    fontSize: 18,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  leading: const AppIcon(
                    AppIcons.camera,
                    color: AppColors.primaryPurpleLight,
                    size: 22,
                  ),
                  title: Text(
                    'Take Photo',
                    style: AppTextStyles.bodyM.copyWith(
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _pickAndUploadAvatar(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const AppIcon(
                    AppIcons.slides,
                    color: AppColors.primaryPurpleLight,
                    size: 22,
                  ),
                  title: Text(
                    'Choose from Gallery',
                    style: AppTextStyles.bodyM.copyWith(
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _pickAndUploadAvatar(ImageSource.gallery);
                  },
                ),
                if (hasAvatar)
                  ListTile(
                    leading: const AppIcon(
                      AppIcons.trash,
                      color: AppColors.errorRed,
                      size: 22,
                    ),
                    title: const Text(
                      'Remove Photo',
                      style: TextStyle(color: AppColors.errorRed),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _removeAvatar();
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (picked == null || !mounted) return;

      setState(() {
        _isUploadingAvatar = true;
        _avatarUploadProgress = 0.05;
      });

      final userProvider = context.read<UserProvider>();
      final success = await userProvider.uploadAvatar(
        picked.path,
        onProgress: (progress) {
          if (mounted) {
            setState(() => _avatarUploadProgress = progress);
          }
        },
      );

      if (mounted) {
        if (success) {
          AppToast.success(context, 'Profile picture updated');
        } else {
          AppToast.error(
            context,
            userProvider.error ?? 'Failed to upload photo',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Permission denied or invalid image');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
          _avatarUploadProgress = 0.0;
        });
      }
    }
  }

  Future<void> _removeAvatar() async {
    final userProvider = context.read<UserProvider>();
    final success = await userProvider.removeAvatar();
    if (mounted) {
      if (success) {
        AppToast.info(context, 'Profile picture removed');
      } else {
        AppToast.error(
          context,
          userProvider.error ?? 'Failed to remove picture',
        );
      }
    }
  }

  // ── Ratings & App Actions ─────────────────────────────────────────────────

  Future<void> _handleRateApp() async {
    final settings = context.read<SettingsProvider>();
    if (!settings.canPromptForReview()) {
      AppToast.info(
        context,
        'Thank you for rating Pitch Coach! You can submit store reviews anytime.',
      );
      return;
    }

    final inAppReview = InAppReview.instance;
    try {
      if (await inAppReview.isAvailable()) {
        await inAppReview.requestReview();
      } else {
        await inAppReview.openStoreListing();
      }
      await settings.recordReviewPrompt();
    } catch (_) {
      try {
        await inAppReview.openStoreListing();
      } catch (_) {}
    }
  }

  // ── Auth & Account Cleanup ────────────────────────────────────────────────

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.elevatedCardOf(dialogCtx),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.borderOf(dialogCtx)),
        ),
        title: Text('Log Out', style: AppTextStyles.headingMOf(dialogCtx)),
        content: Text(
          'Are you sure you want to log out of Pitch Coach?',
          style: AppTextStyles.bodyMOf(dialogCtx),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondaryOf(dialogCtx)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (shouldLogout != true || !mounted) return;

    try {
      await NotificationService.instance.cancelPracticeReminders();
      if (!mounted) return;
      await context.read<UserProvider>().logout();
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Error during logout: $e');
      }
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isMatch = confirmController.text.trim() == 'DELETE';
          final isDark = AppColors.isDark(dialogCtx);
          return AlertDialog(
            backgroundColor: AppColors.elevatedCardOf(dialogCtx),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: AppColors.borderOf(dialogCtx)),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.dangerRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const AppIcon(
                    AppIcons.trash,
                    color: AppColors.dangerRed,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Delete Account',
                  style: AppTextStyles.headingMOf(dialogCtx).copyWith(
                    color: isDark ? AppColors.textOnDark : AppColors.textPrimaryDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This action is irreversible. All speech recordings, scores, slide decks, and settings will be permanently erased.',
                  style: AppTextStyles.bodyMOf(dialogCtx).copyWith(
                    color: AppColors.textSecondaryOf(dialogCtx),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                RichText(
                  text: TextSpan(
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? AppColors.textSecondaryOnDark
                          : AppColors.textSecondary,
                    ),
                    children: const [
                      TextSpan(text: 'Type '),
                      TextSpan(
                        text: 'DELETE',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.dangerRed,
                          letterSpacing: 0.8,
                        ),
                      ),
                      TextSpan(text: ' to confirm:'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmController,
                  autofocus: true,
                  cursorColor: AppColors.dangerRed,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF111111),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    fontSize: 15,
                  ),
                  onChanged: (_) => setDialogState(() {}),
                  decoration: InputDecoration(
                    hintText: 'DELETE',
                    hintStyle: TextStyle(
                      color: isDark
                          ? const Color(0xFF8E8E93)
                          : const Color(0xFF636366),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      fontSize: 15,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF1C1C1E)
                        : const Color(0xFFF2F2F7),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isMatch
                            ? AppColors.dangerRed
                            : (isDark
                                ? const Color(0xFF38383A)
                                : const Color(0xFFD1D1D6)),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isMatch
                            ? AppColors.dangerRed
                            : (isDark
                                ? const Color(0xFF38383A)
                                : const Color(0xFFD1D1D6)),
                        width: isMatch ? 1.5 : 1.0,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isMatch
                            ? AppColors.dangerRed
                            : (isDark
                                ? Colors.white38
                                : const Color(0xFF8E8E93)),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: AppColors.textSecondaryOf(dialogCtx),
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: isMatch
                    ? () => Navigator.pop(dialogCtx, true)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.dangerRed,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: isDark
                      ? const Color(0xFF2C2C2E)
                      : const Color(0xFFE5E5EA),
                  disabledForegroundColor: isDark
                      ? Colors.white38
                      : const Color(0xFF8E8E93),
                  elevation: isMatch ? 1.5 : 0,
                  shadowColor: AppColors.dangerRed.withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Delete Forever',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final stats = context.read<StatsProvider>();
      final practicePlan = context.read<PracticePlanProvider>();
      final slideCoach = context.read<SlideCoachProvider>();
      final gamification = context.read<GamificationProvider>();
      final sessionResults = context.read<SessionResultsProvider>();
      final settings = context.read<SettingsProvider>();
      final user = context.read<UserProvider>();

      await NotificationService.instance.cancelPracticeReminders();

      try {
        stats.reset();
      } catch (_) {}
      try {
        practicePlan.reset();
      } catch (_) {}
      try {
        await slideCoach.reset();
      } catch (_) {}
      try {
        gamification.reset();
      } catch (_) {}
      try {
        await sessionResults.reset();
      } catch (_) {}
      try {
        await settings.clearAllSettings(preserveTheme: true);
      } catch (_) {}

      final success = await user.deleteAccount();
      if (mounted) {
        // Always navigate to the initial screen ('/' -> OnboardingScreen)
        context.go('/');
        if (success) {
          AppToast.success(context, 'Account and all data successfully deleted');
        } else {
          AppToast.info(context, 'Account data wiped from device.');
        }
      }
    } catch (e) {
      if (mounted) {
        context.go('/');
        AppToast.info(context, 'Account data cleared from device.');
      }
    }
  }

  // ── Build Method ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final userProvider = context.watch<UserProvider>();
    final statsProvider = context.watch<StatsProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final user = userProvider.user;

    // Selected language native name
    final langNative = switch (settingsProvider.locale) {
      'ta' => 'தமிழ்',
      'hi' => 'हिन्दी',
      'es' => 'Español',
      _ => 'English',
    };

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AppAtmosphere(
        child: RefreshIndicator(
          onRefresh: _refreshAllData,
          color: AppColors.primaryPurple,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 14.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row
                    SizedBox(
                      height: 48,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(
                            'Profile',
                            style: AppTextStyles.headingXL.copyWith(
                              color: AppColors.textPrimaryOf(context),
                              fontSize: 22,
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const ThemeToggleButton(size: 40, compact: true),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () async {
                                  final refreshed = await context.push(
                                    '/profile-setup',
                                  );
                                  if (refreshed == true && mounted) {
                                    _refreshAllData();
                                  }
                                },
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.glassOf(context),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.borderOf(context),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: AppIcon(
                                    AppIcons.settings,
                                    size: 20,
                                    color: AppColors.textPrimaryOf(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Hero Profile Card
                    _buildHeroCard(user),

                    const SizedBox(height: 16),

                    // Stats Row
                    _buildStatsRow(user, statsProvider),

                    const SizedBox(height: 22),

                    // Account Section
                    SettingsSection(
                      title: 'Account',
                      children: [
                        SettingsTile(
                          leadingIcon: AppIcons.person,
                          title: 'Personal Information',
                          subtitle:
                              'Name, industry, speaking goals & feedback style',
                          trailingType: SettingsTileTrailing.value,
                          trailingText: user.name,
                          onTap: () async {
                            final res = await context.push('/profile-setup');
                            if (res == true && mounted) _refreshAllData();
                          },
                        ),
                        SettingsTile(
                          leadingIcon: AppIcons.clock,
                          title: 'Notification Preferences',
                          subtitle:
                              'Practice alerts, slide deck ready notifications',
                          trailingType: SettingsTileTrailing.chevron,
                          onTap: () => context.push('/profile/notifications'),
                        ),
                        SettingsTile(
                          leadingIcon: AppIcons.award,
                          title: 'Practice Goals & Reminders',
                          subtitle:
                              '${settingsProvider.weeklyGoal} sessions/wk • ${settingsProvider.reminderTime.format(context)}',
                          trailingType: SettingsTileTrailing.chevron,
                          onTap: () => PracticeGoalsSheet.show(context),
                        ),
                        SettingsTile(
                          leadingIcon: AppIcons.crown,
                          title: 'Subscription / Upgrade to Pro',
                          subtitle: user.isPro
                              ? 'Pro Membership active'
                              : 'Unlimited AI analyses & advanced acoustics',
                          badge: 'PRO',
                          trailingType: SettingsTileTrailing.chevron,
                          onTap: () => context.push('/profile/pro'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Learn Section
                    SettingsSection(
                      title: 'Learn',
                      children: [
                        SettingsTile(
                          leadingIcon: AppIcons.book,
                          title: 'Communication Lessons',
                          subtitle:
                              'Speech delivery and public speaking courses',
                          trailingType: SettingsTileTrailing.value,
                          trailingText: '${LessonCatalog.all.length} lessons',
                          onTap: () => context.push('/lessons'),
                        ),
                        SettingsTile(
                          leadingIcon: AppIcons.video,
                          title: 'Watch: Reduce Filler Words',
                          subtitle: '4-minute deep dive on pausing and rhythm',
                          trailingType: SettingsTileTrailing.chevron,
                          onTap: () {
                            try {
                              final lesson = LessonCatalog.all.firstWhere(
                                (l) => l.weakAreaTag == 'filler_words',
                                orElse: () => LessonCatalog.all.first,
                              );
                              context.push('/lessons/detail', extra: lesson);
                            } catch (_) {
                              context.push('/lessons');
                            }
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Preferences Section
                    SettingsSection(
                      title: 'Preferences',
                      children: [
                        SettingsTile(
                          leadingIcon: settingsProvider.isDarkMode(context)
                              ? AppIcons.moon
                              : AppIcons.sun,
                          title: 'Dark Mode',
                          subtitle: 'Toggle dark or light theme interface',
                          trailingType: SettingsTileTrailing.toggle,
                          toggleValue: settingsProvider.isDarkMode(context),
                          onToggle: (_) =>
                              settingsProvider.toggleDarkMode(context),
                        ),
                        SettingsTile(
                          leadingIcon: AppIcons.timer,
                          title: 'Ambient Live Pacing Cues',
                          subtitle: 'Subtle color glow around timer indicating speech pace',
                          trailingType: SettingsTileTrailing.toggle,
                          toggleValue: settingsProvider.ambientLiveCues,
                          onToggle: (val) =>
                              settingsProvider.setAmbientLiveCues(val),
                        ),
                        SettingsTile(
                          leadingIcon: AppIcons.globe,
                          title: 'Language',
                          subtitle: 'Transcription & interface language',
                          trailingType: SettingsTileTrailing.value,
                          trailingText: langNative,
                          onTap: () => LanguagePickerSheet.show(context),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Support Section
                    SettingsSection(
                      title: 'Support',
                      children: [
                        SettingsTile(
                          leadingIcon: AppIcons.help,
                          title: 'Help Center',
                          subtitle: 'Frequently asked questions and guides',
                          trailingType: SettingsTileTrailing.chevron,
                          onTap: () => context.push('/profile/help'),
                        ),
                        SettingsTile(
                          leadingIcon: AppIcons.chat,
                          title: 'Send Feedback',
                          subtitle: 'Report a bug or suggest improvements',
                          trailingType: SettingsTileTrailing.chevron,
                          onTap: () => context.push('/profile/feedback'),
                        ),
                        SettingsTile(
                          leadingIcon: AppIcons.star,
                          title: 'Rate the App',
                          subtitle: 'Share your feedback on the App Store',
                          trailingType: SettingsTileTrailing.chevron,
                          onTap: _handleRateApp,
                        ),
                        SettingsTile(
                          leadingIcon: AppIcons.info,
                          title: 'About Pitch Coach',
                          subtitle: 'Version info, privacy policy, and terms',
                          trailingType: SettingsTileTrailing.chevron,
                          onTap: () => AboutPitchCoachDialog.show(context),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // Log Out Button
                    GradientButton(
                      text: 'Log Out',
                      variant: GradientButtonVariant.tertiary,
                      borderColor: AppColors.dangerRed.withValues(alpha: 0.5),
                      textColor: AppColors.dangerRed,
                      height: 50,
                      onPressed: _confirmLogout,
                    ),

                    const SizedBox(height: 12),

                    // Delete Account Button (Low-emphasis destructive)
                    Center(
                      child: TextButton(
                        onPressed: _confirmDeleteAccount,
                        child: Text(
                          'Delete Account',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.errorRed.withValues(alpha: 0.75),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // App Version Footer
                    Center(
                      child: Text(
                        _appVersionString,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondaryOf(
                            context,
                          ).withValues(alpha: 0.6),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Hero Card ─────────────────────────────────────────────────────────────

  Widget _buildHeroCard(UserProfile user) {
    final isDark = AppColors.isDark(context);
    final avatarUrl = user.fullAvatarUrl;

    return GlassSurface(
      elevated: true,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      borderRadius: BorderRadius.circular(24),
      gradient: isDark
          ? LinearGradient(
              colors: [
                AppColors.primaryPurple.withValues(alpha: 0.22),
                AppColors.cardDarkElevated,
                AppColors.cardDark,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : null,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar Stack with Camera Badge and Progress Ring
            GestureDetector(
              onTap: _showAvatarOptionsSheet,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.auroraGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryPurple.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: avatarUrl != null
                          ? Image.network(
                              avatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Center(
                                    child: Text(
                                      user.initials,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 30,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                            )
                          : Center(
                              child: Text(
                                user.initials,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                    ),
                  ),

                  // Upload Progress Overlay
                  if (_isUploadingAvatar)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.5),
                        ),
                        child: Center(
                          child: CircularProgressIndicator(
                            value: _avatarUploadProgress > 0
                                ? _avatarUploadProgress
                                : null,
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        ),
                      ),
                    ),

                  // Camera Badge
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const AppIcon(
                        AppIcons.camera,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // User Name & Optional Pro Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    user.name,
                    style: AppTextStyles.headingL.copyWith(
                      color: AppColors.textPrimaryOf(context),
                      fontSize: 20,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
                if (user.isPro) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'PRO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 4),

            // User Role Headline
            Text(
              user.role.isEmpty ? 'Pitch Coach member' : user.role,
              style: AppTextStyles.bodyM.copyWith(
                color: AppColors.textSecondaryOf(context),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // Edit Profile Button
            SizedBox(
              height: 38,
              child: OutlinedButton(
                onPressed: () async {
                  final refreshed = await context.push('/profile-setup');
                  if (refreshed == true && mounted) {
                    _refreshAllData();
                  }
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: AppColors.primaryPurple.withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 0,
                  ),
                ),
                child: Text(
                  'Edit Profile',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primaryPurpleLight,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Quick Stats Row ───────────────────────────────────────────────────────

  Widget _buildStatsRow(UserProfile user, StatsProvider stats) {
    if (stats.isLoading && !stats.hasData) {
      return const SettingsSkeleton(height: 72);
    }

    final totalSessions = stats.summary.totalSessions;
    final avgScore = stats.summary.avgScore ?? 0.0;
    final hasSessions = totalSessions > 0 && avgScore > 0;

    // Score color coding
    final Color scoreColor;
    if (!hasSessions) {
      scoreColor = AppColors.textSecondaryOf(context);
    } else if (avgScore >= 80) {
      scoreColor = AppColors.successGreen;
    } else if (avgScore >= 60) {
      scoreColor = AppColors.primaryPurpleLight;
    } else {
      scoreColor = AppColors.errorRed;
    }

    // Trend indicator if trend points available
    Widget? trendWidget;
    if (stats.trend.length >= 2) {
      final latest = stats.trend.last.confidence;
      final prior = stats.trend[stats.trend.length - 2].confidence;
      final diff = latest - prior;
      if (diff > 0) {
        trendWidget = Text(
          '+${diff.toStringAsFixed(0)}',
          style: const TextStyle(
            color: AppColors.successGreen,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        );
      } else if (diff < 0) {
        trendWidget = Text(
          diff.toStringAsFixed(0),
          style: const TextStyle(
            color: AppColors.errorRed,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        );
      }
    }

    final memberSinceText = user.memberSince.isNotEmpty
        ? user.memberSince
        : 'Oct 2026';

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => context.go('/history'),
            borderRadius: BorderRadius.circular(16),
            child: _buildProfileStatTile(
              label: 'Sessions',
              value: '$totalSessions',
              context: context,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: InkWell(
            onTap: () => context.go('/progress'),
            borderRadius: BorderRadius.circular(16),
            child: _buildProfileStatTile(
              label: 'Avg Score',
              value: hasSessions ? '${avgScore.toInt()}%' : '--',
              valueColor: scoreColor,
              trailingWidget: trendWidget,
              hint: !hasSessions ? 'Complete a session' : null,
              context: context,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildProfileStatTile(
            label: 'Member Since',
            value: memberSinceText,
            context: context,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileStatTile({
    required String label,
    required String value,
    required BuildContext context,
    Color? valueColor,
    Widget? trailingWidget,
    String? hint,
  }) {
    return GlassSurface(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: AppTextStyles.headingM.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: valueColor ?? AppColors.textPrimaryOf(context),
                ),
              ),
              if (trailingWidget != null) ...[
                const SizedBox(width: 4),
                trailingWidget,
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            hint ?? label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 10.5,
              color: AppColors.textSecondaryOf(context),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
