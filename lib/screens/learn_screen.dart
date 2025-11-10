import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../services/theme_service.dart';
import '../services/auth_service.dart';
import '../services/progress_service.dart';
import '../services/sound_service.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/animated_card.dart';
import '../widgets/quiz_card.dart';
import '../widgets/scenario_card.dart';
import '../widgets/progress_indicator_widget.dart';
import '../models/video_scenario.dart';
import 'video_scenario_screen.dart';
import '../widgets/video_scenario_card.dart';
import '../models/learning_content.dart';
import '../widgets/bouncy_button.dart';

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen>
    with TickerProviderStateMixin {
  late AnimationController _headerController;
  late AnimationController _contentController;
  late AnimationController _fabController;
  late Animation<double> _headerAnimation;
  late Animation<Offset> _contentSlideAnimation;
  late Animation<double> _contentFadeAnimation;
  late Animation<double> _fabAnimation;
  bool _suppressCategoryTap = false;

  int _currentNavIndex = 2; // Learn tab
  int _selectedCategoryIndex = 0;

  final List<LearningCategory> _categories = [
    LearningCategory(
      title: 'Basics',
      icon: Icons.school_outlined,
      color: AppTheme.primaryColor,
      completedLessons: 3,
      totalLessons: 5,
    ),
    LearningCategory(
      title: 'Email Security',
      icon: Icons.email_outlined,
      color: AppTheme.warningColor,
      completedLessons: 2,
      totalLessons: 4,
    ),
    LearningCategory(
      title: 'Web Safety',
      icon: Icons.web_outlined,
      color: AppTheme.successColor,
      completedLessons: 1,
      totalLessons: 3,
    ),
    LearningCategory(
      title: 'Advanced',
      icon: Icons.security_outlined,
      color: AppTheme.errorColor,
      completedLessons: 0,
      totalLessons: 6,
    ),
  ];

  final List<QuizData> _quizzes = [
    QuizData(
      id: 'quiz_1',
      title: 'Phishing Basics',
      description: 'Test your knowledge of basic phishing concepts',
      difficulty: 'Beginner',
      questions: 10,
      timeMinutes: 5,
      completedAt: DateTime.now().subtract(const Duration(days: 2)),
      score: 85,
    ),
    QuizData(
      id: 'quiz_2',
      title: 'Email Security',
      description: 'Identify suspicious emails and protect yourself',
      difficulty: 'Intermediate',
      questions: 15,
      timeMinutes: 8,
      completedAt: null,
      score: null,
    ),
    QuizData(
      id: 'quiz_3',
      title: 'Advanced Threats',
      description: 'Recognize sophisticated phishing attempts',
      difficulty: 'Advanced',
      questions: 20,
      timeMinutes: 12,
      completedAt: null,
      score: null,
    ),
  ];

  // Scenarios for Learn page are loaded from CSV dynamically per category/level

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
  }

  void _initializeAnimations() {
    _headerController = AnimationController(
      duration: AppAnimations.normalAnimation,
      vsync: this,
    );

    _contentController = AnimationController(
      duration: AppAnimations.slowAnimation,
      vsync: this,
    );

    _fabController = AnimationController(
      duration: AppAnimations.normalAnimation,
      vsync: this,
    );

    _headerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _headerController,
        curve: AppAnimations.defaultCurve,
      ),
    );

    _contentSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: AppAnimations.slideCurve,
      ),
    );

    _contentFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: AppAnimations.defaultCurve,
      ),
    );

    _fabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabController, curve: AppAnimations.bounceCurve),
    );
  }

  void _startAnimations() {
    _headerController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _contentController.forward();
        _fabController.forward();
      }
    });
  }

  @override
  void dispose() {
    _headerController.dispose();
    _contentController.dispose();
    _fabController.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    SoundService.playButtonSound();
    setState(() {
      _currentNavIndex = index;
    });

    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        _showScanDialog();
        break;
      case 2:
        // Already on learn
        break;
      case 3:
        context.go('/profile');
        break;
    }
  }

  void _showScanDialog() {
    SoundService.playButtonSound();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildScanBottomSheet(),
    );
  }

  void _onCategorySelected(int index) {
    SoundService.playButtonSound();
    setState(() {
      _selectedCategoryIndex = index;
    });
    _showLevelPicker(_categories[index].title);
  }

  Future<bool> _confirmStartDialog({
    required String title,
    required String message,
    String confirmLabel = 'Start',
  }) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(confirmLabel),
              ),
            ],
          ),
    );
    return ok == true;
  }

  void _startQuiz(QuizData quiz) {
    SoundService.playButtonSound();
    () async {
      final bool ok = await _confirmStartDialog(
        title: 'Start quiz?',
        message: 'You are about to start ${quiz.title} • ${quiz.difficulty}.',
      );
      if (!ok) return;
      _guardedNavigateToQuiz(quiz.id);
    }();
  }

  void _startScenario(ScenarioData scenario) {
    SoundService.playButtonSound();
    () async {
      final bool ok = await _confirmStartDialog(
        title: 'Start scenario?',
        message:
            'You are about to start ${scenario.title} • ${scenario.difficulty}.',
      );
      if (!ok) return;
      _guardedNavigateToScenario();
    }();
  }

  Future<void> _guardedNavigateToQuiz([String? targetQuizId]) async {
    final auth = context.read<AuthService>();
    if (!auth.isAuthenticated) {
      _showAuthRequiredDialog();
      return;
    }
    if (!(auth.currentUser?.emailVerified ?? false)) {
      _showVerifyDialog();
      return;
    }
    // Choose quiz based on selected category and construct per-category id
    final String category = _categories[_selectedCategoryIndex].title;
    String? level = await context.read<ProgressService>().getCategoryLevel(
      category,
    );
    level ??= 'Beginner';
    final String resolvedQuizId =
        'quiz_' +
        category.toLowerCase().replaceAll(' ', '_') +
        '_' +
        level.toLowerCase();
    context.go(
      '/quiz/$resolvedQuizId',
      extra: {
        'overrideCategory': category,
        'overrideLevel': level,
        'overrideTitle': '$category • $level',
      },
    );
  }

  Future<void> _guardedNavigateToScenario() async {
    final auth = context.read<AuthService>();
    if (!auth.isAuthenticated) {
      _showAuthRequiredDialog();
      return;
    }
    if (!(auth.currentUser?.emailVerified ?? false)) {
      _showVerifyDialog();
      return;
    }
    final String category = _categories[_selectedCategoryIndex].title;
    String? level = await context.read<ProgressService>().getCategoryLevel(
      category,
    );
    level ??= 'Beginner';
    final String targetScenarioId =
        'scenario_' +
        category.toLowerCase().replaceAll(' ', '_') +
        '_' +
        level.toLowerCase();
    context.go(
      '/scenario/$targetScenarioId',
      extra: {
        'overrideCategory': category,
        'overrideLevel': level,
        'overrideTitle': '$category • $level',
      },
    );
  }

  void _showAuthRequiredDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Sign in required'),
            content: const Text(
              'Please sign in or create an account to start learning and save your progress.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.go('/login');
                },
                child: const Text('Sign in'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.go('/register');
                },
                child: const Text('Create account'),
              ),
            ],
          ),
    );
  }

  void _showVerifyDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Verify your email'),
            content: const Text(
              'We sent a verification link to your email. Please verify to continue.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await context.read<AuthService>().sendEmailVerification();
                    if (!mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Verification email sent')),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to send: $e')),
                    );
                  }
                },
                child: const Text('Resend link'),
              ),
            ],
          ),
    );
  }

  void _showLevelPicker(String category) async {
    final theme = Theme.of(context);
    final auth = context.read<AuthService>();
    String? current =
        auth.isAuthenticated
            ? await context.read<ProgressService>().getCategoryLevel(category)
            : null;
    // Preload unlock states
    final canIntermediate = await context
        .read<ProgressService>()
        .canSelectLevel(category: category, targetLevel: 'Intermediate');
    final canAdvanced = await context.read<ProgressService>().canSelectLevel(
      category: category,
      targetLevel: 'Advanced',
    );
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (_) {
        return Container(
          margin: const EdgeInsets.all(AppConstants.spacingM),
          padding: const EdgeInsets.all(AppConstants.spacingL),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppConstants.borderRadius * 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Choose level for $category',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Tooltip(
                    message:
                        'To move up, pass the category quiz. Long-press the card to see this hint again.',
                    triggerMode: TooltipTriggerMode.tap,
                    child: const Icon(Icons.info_outline, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _levelButton('Beginner', current == 'Beginner', true, () async {
                await _setCategoryLevel(category, 'Beginner');
                if (mounted) Navigator.pop(context);
              }),
              const SizedBox(height: 8),
              _levelButton(
                'Intermediate',
                current == 'Intermediate',
                canIntermediate,
                () async {
                  if (!canIntermediate) return;
                  await _setCategoryLevel(category, 'Intermediate');
                  if (mounted) Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
              _levelButton(
                'Advanced',
                current == 'Advanced',
                canAdvanced,
                () async {
                  if (!canAdvanced) return;
                  await _setCategoryLevel(category, 'Advanced');
                  if (mounted) Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _levelButton(
    String label,
    bool selected,
    bool enabled,
    VoidCallback onPressed,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // Improve contrast for dark and light themes
    final Color background =
        selected
            ? colorScheme.primaryContainer
            : (enabled
                ? colorScheme.surfaceVariant.withOpacity(
                  theme.brightness == Brightness.dark ? 0.40 : 0.85,
                )
                : colorScheme.surfaceVariant.withOpacity(
                  theme.brightness == Brightness.dark ? 0.25 : 0.60,
                ));
    final Color foreground =
        selected
            ? colorScheme.onPrimaryContainer
            : (enabled
                ? colorScheme.onSurface
                : colorScheme.onSurface.withOpacity(0.55));

    return BouncyButton(
      background: background,
      foreground: foreground,
      onPressed: enabled ? onPressed : () {},
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (!enabled)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(Icons.lock_outline, size: 16, color: foreground),
                ),
              Text(label, style: TextStyle(color: foreground)),
            ],
          ),
          if (selected) const Icon(Icons.check, color: AppTheme.successColor),
        ],
      ),
    );
  }

  Future<void> _setCategoryLevel(String category, String level) async {
    final auth = context.read<AuthService>();
    if (!auth.isAuthenticated) {
      _showAuthRequiredDialog();
      return;
    }
    await context.read<ProgressService>().setCategoryLevel(
      category: category,
      level: level,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return WillPopScope(
      onWillPop: () async {
        context.go('/home');
        return false;
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        extendBody: true,
        body: SafeArea(
          child: Column(
            children: [
            // Header
            FadeTransition(
              opacity: _headerAnimation,
              child: _buildHeader(theme),
            ),

            // Content
            Expanded(
              child: SlideTransition(
                position: _contentSlideAnimation,
                child: FadeTransition(
                  opacity: _contentFadeAnimation,
                  child: _buildContent(theme),
                ),
              ),
            ),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavBar(
          currentIndex: _currentNavIndex,
          onTap: _onNavTap,
          onProfileTap: () => context.go('/profile'),
        ),
        floatingActionButton: ScaleTransition(
          scale: _fabAnimation,
          child: FloatingActionButton.extended(
            onPressed: () {
              SoundService.playButtonSound();
              context.go('/progress');
            },
            icon: const Icon(Icons.analytics_outlined),
            label: const Text('My Progress'),
            backgroundColor: AppTheme.primaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingL),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Learn & Practice',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _buildLevelBadge(theme),
                  ),
                  Consumer<ThemeService>(
                    builder: (context, themeService, child) {
                      return IconButton(
                        onPressed: () {
                          SoundService.playButtonSound();
                          themeService.toggleTheme();
                        },
                        icon: Icon(
                          themeService.isDarkMode
                              ? Icons.light_mode_outlined
                              : Icons.dark_mode_outlined,
                        ),
                        tooltip: 'Toggle theme',
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingS),
          Text(
            'Sharpen your skills with interactive lessons and real-world scenarios',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelBadge(ThemeData theme) {
    final auth = context.watch<AuthService>();
    if (!auth.isAuthenticated) {
      return Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text('Guest'),
      );
    }
    return StreamBuilder<String>(
      stream: context.read<ProgressService>().watchOverallLevel(),
      builder: (context, snap) {
        final String level = snap.data ?? 'Beginner';
        return Tooltip(
          message:
              'Overall level reflects your unlocked levels across categories. Increase it by passing category quizzes.',
          triggerMode: TooltipTriggerMode.tap,
          child: Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.emoji_events_outlined,
                  size: 16,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 6),
                Text(
                  'Level: $level',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(ThemeData theme) {
    final double bottomSafe = MediaQuery.of(context).padding.bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppConstants.spacingL,
        AppConstants.spacingL,
        AppConstants.spacingL,
        AppConstants.spacingL + kBottomNavigationBarHeight + bottomSafe + 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Categories
          _buildCategoriesSection(theme),

          const SizedBox(height: AppConstants.spacingXL),

          // Quick Practice Section
          _buildQuickPracticeSection(theme),

          const SizedBox(height: AppConstants.spacingXL),

          // Quizzes Section
          _buildQuizzesSection(theme),

          const SizedBox(height: AppConstants.spacingXL),

          // Scenarios Section
          _buildScenariosSection(theme),

          const SizedBox(height: AppConstants.spacingXXL),
        ],
      ),
    );
  }

  Widget _buildCategoriesSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Learning Categories',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: AppConstants.spacingM),
        SizedBox(
          height: 156,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              return AnimatedCard(
                delay: Duration(milliseconds: index * 100),
                child: _buildCategoryCard(_categories[index], index, theme),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(
    LearningCategory category,
    int index,
    ThemeData theme,
  ) {
    final isSelected = index == _selectedCategoryIndex;
    // final progress = category.completedLessons / category.totalLessons; // replaced by realtime progress widget

    return GestureDetector(
      onTap: () {
        if (_suppressCategoryTap) return;
        _onCategorySelected(index);
      },
      onLongPress: () {
        final levelHint =
            'To increase your level, complete the quiz for this category.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(levelHint)));
      },
      child: AnimatedContainer(
        duration: AppAnimations.fastAnimation,
        width: 150,
        height: double.infinity,
        margin: const EdgeInsets.only(right: AppConstants.spacingM),
        padding: const EdgeInsets.all(AppConstants.spacingM),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? category.color.withOpacity(0.1)
                  : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          border: Border.all(
            color:
                isSelected
                    ? category.color
                    : theme.colorScheme.outline.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: category.color.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                  ]
                  : null,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(category.icon, color: category.color, size: 24),
                    const Spacer(),
                    // Level dropdown icon at top-right
                    InkWell(
                      onTap: () => _showLevelPicker(category.title),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: category.color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.expand_more,
                          color: category.color,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  category.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                // Per-category saved level badge
                _CategoryLevelBadge(
                  category: category.title,
                  color: category.color,
                ),
                const SizedBox(height: 6),
                // Realtime progress based on completed quizzes in Firestore
                _CategoryProgressBar(
                  category: category.title,
                  totalLessons: category.totalLessons,
                  color: category.color,
                ),
                const SizedBox(height: 2),
                _CategoryProgressText(
                  category: category.title,
                  totalLessons: category.totalLessons,
                ),
              ],
            ),
            Positioned(
              left: 80,
              bottom: -15,
              child: IconButton(
                tooltip: 'View attempts',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(Icons.info_outline, size: 18, color: category.color),
                onPressed: () => _showAttemptsBottomSheet(category.title),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widgets for per-category level and realtime progress
  // Shows 'Level: X' using ProgressService stored levels
  Widget _levelChip(String label, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // Level badge as a separate widget to allow FutureBuilder
  // ignore: unused_element
  Widget _buildLevelForCategory(String category, Color color, ThemeData theme) {
    return FutureBuilder<String?>(
      future: context.read<ProgressService>().getCategoryLevel(category),
      builder: (context, snap) {
        final level = snap.data ?? 'Beginner';
        return _levelChip('Level: $level', color, theme);
      },
    );
  }

  // Small composable to show the saved level badge inline in the card
  // Using a StatelessBuilder with FutureBuilder to keep code local
  Widget _CategoryLevelBadge({required String category, required Color color}) {
    final theme = Theme.of(context);
    return FutureBuilder<String?>(
      future: context.read<ProgressService>().getCategoryLevel(category),
      builder: (context, snap) {
        final level = snap.data ?? 'Beginner';
        return _levelChip('Level: $level', color, theme);
      },
    );
  }

  // Realtime progress bar for a given category based on quizzes completion
  Widget _CategoryProgressBar({
    required String category,
    required int totalLessons,
    required Color color,
  }) {
    final auth = context.watch<AuthService>();
    if (!auth.isAuthenticated) {
      // Fallback to static progress when unauthenticated
      return ProgressIndicatorWidget(progress: 0, color: color);
    }
    return StreamBuilder<int>(
      stream: context.read<ProgressService>().watchCompletedQuizzesCount(
        category: category,
      ),
      builder: (context, snap) {
        final completed = (snap.data ?? 0).clamp(0, totalLessons);
        final progress = totalLessons == 0 ? 0.0 : completed / totalLessons;
        return ProgressIndicatorWidget(progress: progress, color: color);
      },
    );
  }

  // Text under the bar like "3/5 lessons"
  Widget _CategoryProgressText({
    required String category,
    required int totalLessons,
  }) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthService>();
    if (!auth.isAuthenticated) {
      return Text(
        '0/$totalLessons lessons',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.6),
          fontSize: 11,
        ),
      );
    }
    return StreamBuilder<int>(
      stream: context.read<ProgressService>().watchCompletedQuizzesCount(
        category: category,
      ),
      builder: (context, snap) {
        final completed = (snap.data ?? 0).clamp(0, totalLessons);
        return Text(
          '$completed/$totalLessons lessons',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
            fontSize: 11,
          ),
        );
      },
    );
  }

  void _showAttemptsBottomSheet(String category) async {
    final theme = Theme.of(context);
    // Normalize any stale records before showing UI
    await context.read<ProgressService>().normalizeAttemptCategories();
    setState(() => _suppressCategoryTap = true);
    // Defer to next frame to avoid the original tap's up event dismissing the sheet
    await Future.delayed(const Duration(milliseconds: 80));
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => Container(
            margin: const EdgeInsets.all(AppConstants.spacingM),
            padding: const EdgeInsets.all(AppConstants.spacingL),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(
                AppConstants.borderRadius * 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$category • Attempts',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 320,
                  child: StreamBuilder(
                    stream: context.read<ProgressService>().watchAttempts(
                      category: category,
                      limit: 50,
                    ),
                    builder: (context, AsyncSnapshot snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Could not load attempts. Please try again later.',
                          ),
                        );
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      // Normalize and sort client-side by completedAt desc
                      final List<dynamic> rawDocs =
                          (snapshot.data?.docs ?? <dynamic>[]) as List<dynamic>;
                      final List<Map<String, dynamic>> attempts =
                          rawDocs
                              .map((d) => Map<String, dynamic>.from(d.data()))
                              .toList();
                      attempts.sort((a, b) {
                        final dynamic ad = a['completedAt'];
                        final dynamic bd = b['completedAt'];
                        final int at =
                            ad is Timestamp
                                ? ad.millisecondsSinceEpoch
                                : (ad is DateTime
                                    ? ad.millisecondsSinceEpoch
                                    : 0);
                        final int bt =
                            bd is Timestamp
                                ? bd.millisecondsSinceEpoch
                                : (bd is DateTime
                                    ? bd.millisecondsSinceEpoch
                                    : 0);
                        return bt.compareTo(at);
                      });
                      if (attempts.isEmpty) {
                        return const Center(child: Text('No attempts yet.'));
                      }
                      return ListView.builder(
                        itemCount: attempts.length,
                        itemBuilder: (context, i) {
                          final data = attempts[i];
                          final bool passed = (data['passed'] ?? false) as bool;
                          final int correct = (data['correct'] ?? 0) as int;
                          final int total = (data['total'] ?? 0) as int;
                          final String difficulty =
                              (data['difficulty'] ?? '') as String;
                          // Resolve and format attempt completion date
                          final dynamic completedAtRaw = data['completedAt'];
                          DateTime? completedAt;
                          if (completedAtRaw is Timestamp) {
                            completedAt = completedAtRaw.toDate();
                          } else if (completedAtRaw is DateTime) {
                            completedAt = completedAtRaw;
                          }
                          String formattedDate = '-';
                          if (completedAt != null) {
                            final DateTime d = completedAt.toLocal();
                            const List<String> months = <String>[
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
                            String two(int n) => n.toString().padLeft(2, '0');
                            formattedDate =
                                '${d.day} ${months[d.month - 1]} ${d.year} • ${two(d.hour)}:${two(d.minute)}';
                          }
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              passed ? Icons.check_circle : Icons.cancel,
                              color:
                                  passed
                                      ? AppTheme.successColor
                                      : AppTheme.errorColor,
                            ),
                            title: Text('$correct/$total correct'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Level: ' +
                                      (difficulty.isEmpty ? '-' : difficulty),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  formattedDate,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                            trailing: Tooltip(
                              message:
                                  'Tap to view details. Long-press the row too.',
                              triggerMode: TooltipTriggerMode.tap,
                              child: IconButton(
                                onPressed: () => _showAttemptDetails(data),
                                icon: const Icon(Icons.touch_app_outlined),
                                color: theme.colorScheme.primary,
                                splashRadius: 18,
                                tooltip: 'View details',
                              ),
                            ),
                            onLongPress: () => _showAttemptDetails(data),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
    );
    if (!mounted) return;
    setState(() => _suppressCategoryTap = false);
  }

  void _showAttemptDetails(Map<String, dynamic> attempt) {
    final ThemeData theme = Theme.of(context);
    final String quizId = (attempt['quizId'] ?? '') as String;
    final List<dynamic> rawAnswers =
        (attempt['answers'] ?? <dynamic>[]) as List<dynamic>;
    // Fallback options using repository if not stored
    final Quiz? quiz = LearningRepository.getQuiz(quizId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          margin: const EdgeInsets.all(AppConstants.spacingM),
          padding: const EdgeInsets.all(AppConstants.spacingL),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppConstants.borderRadius * 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Attempt Details',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: ListView.builder(
                  itemCount: rawAnswers.length,
                  itemBuilder: (context, index) {
                    final Map<String, dynamic> a = Map<String, dynamic>.from(
                      rawAnswers[index] as Map,
                    );
                    final String prompt = (a['prompt'] ?? '-') as String;
                    final List<dynamic> optsDyn = (a['options'] ?? []) as List;
                    final List<String> options =
                        optsDyn.isEmpty && quiz != null
                            ? quiz.questions
                                .firstWhere(
                                  (q) => q.id == (a['id'] ?? ''),
                                  orElse:
                                      () => const MultipleChoiceQuestion(
                                        id: 'missing',
                                        prompt: '-',
                                        options: <String>[],
                                        correctIndex: 0,
                                      ),
                                )
                                .options
                            : optsDyn.map((e) => e.toString()).toList();
                    final int userIndex = (a['userIndex'] ?? -1) as int;
                    final int correctIndex = (a['correctIndex'] ?? -1) as int;
                    final bool userCorrect =
                        (a['userCorrect'] ?? false) as bool;
                    final String userText =
                        userIndex >= 0 && userIndex < options.length
                            ? options[userIndex]
                            : 'Not answered';
                    final String correctText =
                        correctIndex >= 0 && correctIndex < options.length
                            ? options[correctIndex]
                            : '-';

                    return ListTile(
                      leading: Icon(
                        userCorrect ? Icons.check_circle : Icons.cancel,
                        color:
                            userCorrect
                                ? AppTheme.successColor
                                : AppTheme.errorColor,
                      ),
                      title: Text(prompt),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            'Your answer: ' + userText,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.8,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Correct answer: ' + correctText,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color:
                                  userCorrect
                                      ? AppTheme.successColor
                                      : AppTheme.errorColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickPracticeSection(ThemeData theme) {
    return AnimatedCard(
      delay: const Duration(milliseconds: 300),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppConstants.spacingL),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryColor.withOpacity(0.1),
              AppTheme.successColor.withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flash_on, color: AppTheme.primaryColor, size: 28),
                const SizedBox(width: AppConstants.spacingS),
                Text(
                  'Sharpen Your Skills',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              'Practice makes perfect. Improve your ability to spot phishing with these interactive exercises.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.8),
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppConstants.spacingL),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      SoundService.playButtonSound();
                      _showQuickQuizDialog();
                    },
                    icon: const Icon(Icons.quiz_outlined),
                    label: const Text(
                      'Take Quiz',
                      style: TextStyle(fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      SoundService.playButtonSound();
                      _showScenarioDialog();
                    },
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text(
                      'Scenarios',
                      style: TextStyle(fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: BorderSide(color: AppTheme.primaryColor),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizzesSection(ThemeData theme) {
    final String category = _categories[_selectedCategoryIndex].title;
    final filtered =
        _quizzes
            .where(
              (q) =>
                  q.title.contains(category) ||
                  q.difficulty ==
                      (_selectedCategoryIndex == 0
                          ? 'Beginner'
                          : _selectedCategoryIndex == 1
                          ? 'Intermediate'
                          : _selectedCategoryIndex == 2
                          ? 'Intermediate'
                          : 'Advanced'),
            )
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Interactive Quizzes',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            TextButton(
              onPressed: () {
                SoundService.playButtonSound();
                context.go('/quizzes');
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingM),
        ...List.generate(filtered.length, (index) {
          return AnimatedCard(
            delay: Duration(milliseconds: 400 + (index * 100)),
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppConstants.spacingM),
              child: QuizCard(
                quiz: filtered[index],
                onTap: () => _startQuiz(filtered[index]),
                totalLessons: _categories[_selectedCategoryIndex].totalLessons,
                category: _categories[_selectedCategoryIndex].title,
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildScenariosSection(ThemeData theme) {
    final String category = _categories[_selectedCategoryIndex].title;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Real-World Scenarios',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            TextButton(
              onPressed: () {
                SoundService.playButtonSound();
                context.go('/scenarios');
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingM),
        FutureBuilder<List<Widget>>(
          future: () async {
            final ps = context.read<ProgressService>();
            String? saved = await ps.getCategoryLevel(category);
            final String primaryLevel = saved ?? 'Beginner';
            final List<Widget> cards = <Widget>[];
            // Prefer video scenarios if available
            try {
              final vids = await ps.loadVideoScenarioCsv(
                category: category,
                level: primaryLevel,
              );
              for (final v in vids.take(2)) {
                cards.add(
                  AnimatedCard(
                    delay: const Duration(milliseconds: 600),
                    child: Padding(
                      padding: const EdgeInsets.only(
                        bottom: AppConstants.spacingM,
                      ),
                      child: VideoScenarioCard(
                        scenario: v,
                        onTap: () {
                          () async {
                            final bool ok = await _confirmStartDialog(
                              title: 'Start video scenario?',
                              message: 'Open "${v.title}" now?',
                            );
                            if (!ok) return;
                            if (!context.mounted) return;
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder:
                                    (_) => VideoScenarioScreen(scenario: v),
                              ),
                            );
                          }();
                        },
                      ),
                    ),
                  ),
                );
              }
            } catch (_) {}
            final List<(String, String, Scenario)> picks =
                <(String, String, Scenario)>[];
            try {
              final primary = await ps.loadScenarioCsv(
                category: category,
                level: primaryLevel,
              );
              if (primary.isNotEmpty) {
                for (final sc in primary.take(2)) {
                  picks.add((category, primaryLevel, sc));
                }
              }
            } catch (_) {}
            if (picks.isEmpty && primaryLevel != 'Beginner') {
              try {
                final alt = await ps.loadScenarioCsv(
                  category: category,
                  level: 'Beginner',
                );
                if (alt.isNotEmpty) {
                  for (final sc in alt.take(2)) {
                    picks.add((category, 'Beginner', sc));
                  }
                }
              } catch (_) {}
            }
            if (picks.isEmpty) {
              const others = <String>[
                'Basics',
                'Email Security',
                'Web Safety',
                'Advanced',
              ];
              for (final cat in others) {
                if (cat == category) continue;
                try {
                  final alt = await ps.loadScenarioCsv(
                    category: cat,
                    level: 'Beginner',
                  );
                  if (alt.isNotEmpty) picks.add((cat, 'Beginner', alt.first));
                  if (picks.length >= 2) break;
                } catch (_) {}
              }
            }
            // Build text scenario cards until we have 1-2 total
            for (int i = 0; i < picks.length && cards.length < 2; i++) {
              final entry = picks[i];
              final String cat = entry.$1;
              final String lvl = entry.$2;
              final Scenario sc = entry.$3;
              cards.add(
                AnimatedCard(
                  delay: Duration(milliseconds: 600 + (i * 100)),
                  child: Padding(
                    padding: const EdgeInsets.only(
                      bottom: AppConstants.spacingM,
                    ),
                    child: ScenarioCard(
                      scenario: ScenarioData(
                        id: sc.id,
                        title: sc.title,
                        description: sc.description,
                        difficulty: lvl,
                        estimatedTime: 5,
                        completedAt: null,
                        score: null,
                      ),
                      category: cat,
                      onTap:
                          () => _startScenario(
                            ScenarioData(
                              id: sc.id,
                              title: sc.title,
                              description: sc.description,
                              difficulty: lvl,
                              estimatedTime: 5,
                              completedAt: null,
                              score: null,
                            ),
                          ),
                    ),
                  ),
                ),
              );
            }
            return cards;
          }(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final cards = snapshot.data ?? <Widget>[];
            if (cards.isEmpty) {
              return Text(
                'No scenarios available for $category yet.',
                style: theme.textTheme.bodyMedium,
              );
            }
            return Column(children: cards.take(2).toList());
          },
        ),
      ],
    );
  }

  Widget _buildScanBottomSheet() {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(AppConstants.spacingM),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius * 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppConstants.spacingL),
            Text(
              'Choose Scan Type',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppConstants.spacingXL),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  SoundService.playButtonSound();
                  Navigator.pop(context);
                  context.go('/scan-result');
                },
                icon: const Icon(Icons.message_outlined),
                label: const Text('Scan Message'),
              ),
            ),
            const SizedBox(height: AppConstants.spacingM),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  SoundService.playButtonSound();
                  Navigator.pop(context);
                  context.go('/scan-result');
                },
                icon: const Icon(Icons.link_outlined),
                label: const Text('Scan URL'),
              ),
            ),
            const SizedBox(height: AppConstants.spacingL),
          ],
        ),
      ),
    );
  }

  void _showQuickQuizDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Quick Quiz'),
            content: const Text(
              'Start a 5-minute quiz to test your phishing knowledge?',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  SoundService.playButtonSound();
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  SoundService.playButtonSound();
                  Navigator.pop(context);
                  // Route to a synthetic id per category+level so results
                  // and duration are tracked per category correctly
                  final String category =
                      _categories[_selectedCategoryIndex].title;
                  String? level = await context
                      .read<ProgressService>()
                      .getCategoryLevel(category);
                  level ??= 'Beginner';
                  final String targetQuizId =
                      'quiz_${category.toLowerCase().replaceAll(' ', '_')}_${level.toLowerCase()}';
                  context.go(
                    '/quiz/$targetQuizId',
                    extra: {
                      'overrideCategory': category,
                      'overrideLevel': level,
                      'overrideTitle': '$category • $level',
                    },
                  );
                },
                child: const Text('Start Quiz'),
              ),
            ],
          ),
    );
  }

  void _showScenarioDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Real-World Scenario'),
            content: const Text('Practice with a realistic phishing scenario?'),
            actions: [
              TextButton(
                onPressed: () {
                  SoundService.playButtonSound();
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  SoundService.playButtonSound();
                  Navigator.pop(context);
                  final String category =
                      _categories[_selectedCategoryIndex].title;
                  String? level = await context
                      .read<ProgressService>()
                      .getCategoryLevel(category);
                  level ??= 'Beginner';
                  final String targetScenarioId =
                      'scenario_${category.toLowerCase().replaceAll(' ', '_')}_${level.toLowerCase()}';
                  context.go(
                    '/scenario/$targetScenarioId',
                    extra: {
                      'overrideCategory': category,
                      'overrideLevel': level,
                      'overrideTitle': '$category • $level',
                    },
                  );
                },
                child: const Text('Start Scenario'),
              ),
            ],
          ),
    );
  }

  // removed old inline progress dialog util
}

// Data Models
class LearningCategory {
  final String title;
  final IconData icon;
  final Color color;
  final int completedLessons;
  final int totalLessons;

  LearningCategory({
    required this.title,
    required this.icon,
    required this.color,
    required this.completedLessons,
    required this.totalLessons,
  });
}

class QuizData {
  final String id;
  final String title;
  final String description;
  final String difficulty;
  final int questions;
  final int timeMinutes;
  final DateTime? completedAt;
  final int? score;

  QuizData({
    required this.id,
    required this.title,
    required this.description,
    required this.difficulty,
    required this.questions,
    required this.timeMinutes,
    this.completedAt,
    this.score,
  });
}

class ScenarioData {
  final String id;
  final String title;
  final String description;
  final String difficulty;
  final int estimatedTime;
  final DateTime? completedAt;
  final int? score;

  ScenarioData({
    required this.id,
    required this.title,
    required this.description,
    required this.difficulty,
    required this.estimatedTime,
    this.completedAt,
    this.score,
  });
}
