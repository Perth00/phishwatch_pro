import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../services/theme_service.dart';
import '../services/sound_service.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/animated_card.dart';
import '../widgets/quiz_card.dart';
import '../widgets/scenario_card.dart';
import '../widgets/progress_indicator_widget.dart';

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

  final List<ScenarioData> _scenarios = [
    ScenarioData(
      id: 'scenario_1',
      title: 'Banking Email',
      description: 'You receive an urgent email from your bank...',
      difficulty: 'Beginner',
      estimatedTime: 3,
      completedAt: DateTime.now().subtract(const Duration(days: 1)),
      score: 92,
    ),
    ScenarioData(
      id: 'scenario_2',
      title: 'Social Media Alert',
      description: 'Your social media account security is at risk...',
      difficulty: 'Intermediate',
      estimatedTime: 5,
      completedAt: null,
      score: null,
    ),
    ScenarioData(
      id: 'scenario_3',
      title: 'CEO Fraud',
      description: 'Your boss urgently needs you to transfer money...',
      difficulty: 'Advanced',
      estimatedTime: 8,
      completedAt: null,
      score: null,
    ),
  ];

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
  }

  void _startQuiz(QuizData quiz) {
    SoundService.playButtonSound();
    context.go('/quiz/${quiz.id}');
  }

  void _startScenario(ScenarioData scenario) {
    SoundService.playButtonSound();
    context.go('/scenario/${scenario.id}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
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
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabAnimation,
        child: FloatingActionButton.extended(
          onPressed: () {
            SoundService.playButtonSound();
            _showProgressDialog();
          },
          icon: const Icon(Icons.analytics_outlined),
          label: const Text('My Progress'),
          backgroundColor: AppTheme.primaryColor,
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Learn & Practice',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
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

  Widget _buildContent(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.spacingL),
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
            color: theme.colorScheme.onBackground,
          ),
        ),
        const SizedBox(height: AppConstants.spacingM),
        SizedBox(
          height: 120,
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
    final progress = category.completedLessons / category.totalLessons;

    return GestureDetector(
      onTap: () => _onCategorySelected(index),
      child: AnimatedContainer(
        duration: AppAnimations.fastAnimation,
        width: 140,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(category.icon, color: category.color, size: 32),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              category.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            ProgressIndicatorWidget(progress: progress, color: category.color),
            const SizedBox(height: AppConstants.spacingXS),
            Text(
              '${category.completedLessons}/${category.totalLessons} lessons',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
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
                    color: theme.colorScheme.onBackground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              'Practice makes perfect. Improve your ability to spot phishing with these interactive exercises.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onBackground.withOpacity(0.8),
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
                    label: const Text('Take a Quiz'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: AppConstants.spacingM),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      SoundService.playButtonSound();
                      _showScenarioDialog();
                    },
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Real-World Scenarios'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: BorderSide(color: AppTheme.primaryColor),
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
                color: theme.colorScheme.onBackground,
              ),
            ),
            TextButton(
              onPressed: () {
                SoundService.playButtonSound();
                // Navigate to all quizzes
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingM),
        ...List.generate(_quizzes.length, (index) {
          return AnimatedCard(
            delay: Duration(milliseconds: 400 + (index * 100)),
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppConstants.spacingM),
              child: QuizCard(
                quiz: _quizzes[index],
                onTap: () => _startQuiz(_quizzes[index]),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildScenariosSection(ThemeData theme) {
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
                color: theme.colorScheme.onBackground,
              ),
            ),
            TextButton(
              onPressed: () {
                SoundService.playButtonSound();
                // Navigate to all scenarios
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingM),
        ...List.generate(_scenarios.length, (index) {
          return AnimatedCard(
            delay: Duration(milliseconds: 600 + (index * 100)),
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppConstants.spacingM),
              child: ScenarioCard(
                scenario: _scenarios[index],
                onTap: () => _startScenario(_scenarios[index]),
              ),
            ),
          );
        }),
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
                onPressed: () {
                  SoundService.playButtonSound();
                  Navigator.pop(context);
                  context.go('/quiz/quick');
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
                onPressed: () {
                  SoundService.playButtonSound();
                  Navigator.pop(context);
                  context.go('/scenario/random');
                },
                child: const Text('Start Scenario'),
              ),
            ],
          ),
    );
  }

  void _showProgressDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Your Progress'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildProgressItem('Quizzes Completed', '3/10', 0.3),
                const SizedBox(height: AppConstants.spacingM),
                _buildProgressItem('Scenarios Completed', '2/8', 0.25),
                const SizedBox(height: AppConstants.spacingM),
                _buildProgressItem('Overall Progress', '15/50', 0.3),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  SoundService.playButtonSound();
                  Navigator.pop(context);
                },
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () {
                  SoundService.playButtonSound();
                  Navigator.pop(context);
                  // Navigate to detailed progress screen
                },
                child: const Text('View Details'),
              ),
            ],
          ),
    );
  }

  Widget _buildProgressItem(String title, String value, double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: AppConstants.spacingS),
        ProgressIndicatorWidget(
          progress: progress,
          color: AppTheme.primaryColor,
        ),
      ],
    );
  }
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
