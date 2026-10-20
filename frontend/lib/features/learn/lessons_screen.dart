import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/lesson_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/bottom_nav_bar.dart';
import '../../core/widgets/theme_toggle_button.dart';

class LessonsScreen extends StatefulWidget {
  final String? initialCategory;

  const LessonsScreen({super.key, this.initialCategory});

  @override
  State<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends State<LessonsScreen> {
  late String _selectedCategory;
  String _selectedLevel = 'All';

  final List<String> _categories = [
    'All',
    'Interview',
    'Presentation',
    'Speaking',
  ];

  final List<String> _levels = [
    'All',
    'Beginner',
    'Intermediate',
    'Advanced',
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory ?? 'All';
  }

  List<Lesson> get _filteredLessons {
    final cat = _selectedCategory.toLowerCase();
    final lvl = _selectedLevel.toLowerCase();
    return LessonCatalog.all.where((l) {
      final matchCat = cat == 'all' || l.category == cat;
      final matchLvl = lvl == 'all' || l.level == lvl;
      return matchCat && matchLvl;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Learn', style: AppTextStyles.headingXLOf(context)),
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.cardOf(context),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.borderOf(context),
                          ),
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          size: 20,
                          color: AppColors.primaryPurple,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const ThemeToggleButton(size: 38, compact: true),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Improve your communication skills',
                style: AppTextStyles.bodyMOf(
                  context,
                ).copyWith(color: AppColors.textSecondaryOf(context)),
              ),
            ),

            const SizedBox(height: 16),

            // Category Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      selectedColor: AppColors.primaryPurple,
                      backgroundColor: AppColors.cardOf(context),
                      labelStyle: AppTextStyles.captionOf(context).copyWith(
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
                          setState(() => _selectedCategory = cat);
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 10),

            // Difficulty Level Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: _levels.map((lvl) {
                  final isSelected = _selectedLevel == lvl;
                  final displayLabel = lvl == 'All' ? 'All Levels' : lvl;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(displayLabel),
                      selected: isSelected,
                      selectedColor: lvl == 'Beginner'
                          ? AppColors.accentGreen
                          : lvl == 'Intermediate'
                              ? AppColors.accentBlue
                              : lvl == 'Advanced'
                                  ? AppColors.primaryPurple
                                  : AppColors.primaryPurple,
                      backgroundColor: AppColors.cardOf(context),
                      labelStyle: AppTextStyles.captionOf(context).copyWith(
                        color: isSelected
                            ? Colors.white
                            : AppColors.textSecondaryOf(context),
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontSize: 11.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isSelected
                              ? Colors.transparent
                              : AppColors.borderOf(context),
                        ),
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedLevel = lvl);
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 14),

            // Lesson List
            Expanded(
              child: _filteredLessons.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.filter_list_off_rounded,
                            size: 40,
                            color: AppColors.textSecondaryOf(context),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No lessons match this filter',
                            style: AppTextStyles.bodyMOf(context).copyWith(
                              color: AppColors.textSecondaryOf(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      itemCount: _filteredLessons.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final lesson = _filteredLessons[index];
                        return _LessonCard(
                          lesson: lesson,
                          onTap: () =>
                              context.push('/lessons/detail', extra: lesson),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 0, // No dedicated nav slot; closest is Home
        onTap: (index) {
          switch (index) {
            case 0:
              context.go('/home');
              break;
            case 1:
              context.go('/history');
              break;
            case 2:
              context.push('/interview');
              break;
            case 3:
              context.go('/progress');
              break;
            case 4:
              context.go('/profile');
              break;
          }
        },
        onMicTap: () => context.push('/interview'),
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  final Lesson lesson;
  final VoidCallback onTap;

  const _LessonCard({required this.lesson, required this.onTap});

  Color get _categoryColor {
    switch (lesson.category) {
      case 'interview':
        return AppColors.primaryPurple;
      case 'presentation':
        return AppColors.accentBlue;
      default:
        return AppColors.accentGreen;
    }
  }

  Color get _levelColor {
    switch (lesson.level) {
      case 'beginner':
        return AppColors.accentGreen;
      case 'intermediate':
        return AppColors.accentBlue;
      case 'advanced':
        return AppColors.primaryPurple;
      default:
        return AppColors.accentGreen;
    }
  }

  IconData get _categoryIcon {
    switch (lesson.category) {
      case 'interview':
        return Icons.event_seat_rounded;
      case 'presentation':
        return Icons.bar_chart_rounded;
      default:
        return Icons.record_voice_over_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardOf(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderOf(context)),
          boxShadow: AppColors.softShadowOf(context),
        ),
        child: Row(
          children: [
            // Category icon
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _categoryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(_categoryIcon, color: _categoryColor, size: 26),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.title,
                    style: AppTextStyles.headingMOf(
                      context,
                    ).copyWith(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lesson.description,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _levelColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _levelColor.withValues(alpha: 0.28),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          lesson.levelLabel,
                          style: AppTextStyles.caption.copyWith(
                            color: _levelColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.play_circle_outline_rounded,
                        size: 14,
                        color: _categoryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        lesson.duration,
                        style: AppTextStyles.caption.copyWith(
                          color: _categoryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
