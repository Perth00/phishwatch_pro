import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:animations/animations.dart';

import '../constants/app_theme.dart';
import '../widgets/animated_page_indicator.dart';
import '../widgets/feature_showcase.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  int _currentPage = 0;

  final List<FeatureData> _features = [
    FeatureData(
      icon: Icons.message_outlined,
      title: 'Scan Messages',
      description:
          'Simply copy suspicious messages and open the app to automatically scan for phishing attempts.',
      color: AppTheme.primaryColor,
    ),
    FeatureData(
      icon: Icons.link_outlined,
      title: 'Analyze URLs',
      description:
          'Paste any suspicious link and we\'ll check it against our database of known phishing sites.',
      color: AppTheme.successColor,
    ),
    FeatureData(
      icon: Icons.analytics_outlined,
      title: 'View Results',
      description:
          'Get instant feedback on potential threats with detailed explanations of why something might be dangerous.',
      color: AppTheme.warningColor,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    _fadeController = AnimationController(
      duration: AppAnimations.normalAnimation,
      vsync: this,
    );

    _slideController = AnimationController(
      duration: AppAnimations.slowAnimation,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: AppAnimations.defaultCurve,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: AppAnimations.slideCurve,
      ),
    );

    // Start animations
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _getStarted() {
    context.go('/home');
  }

  void _skipTutorial() {
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spacingL),
              child: Column(
                children: [
                  // Header
                  _buildHeader(theme),

                  // Feature showcase
                  Expanded(child: _buildFeatureShowcase()),

                  // Page indicator
                  _buildPageIndicator(),

                  const SizedBox(height: AppConstants.spacingXL),

                  // Action buttons
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      children: [
        Text(
          'Welcome to PhishWatch Pro',
          style: theme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onBackground,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppConstants.spacingS),
        Text(
          'Your personal security assistant',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onBackground.withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFeatureShowcase() {
    return PageView.builder(
      controller: _pageController,
      onPageChanged: _onPageChanged,
      itemCount: _features.length,
      itemBuilder: (context, index) {
        return AnimatedBuilder(
          animation: _pageController,
          builder: (context, child) {
            double value = 1.0;
            if (_pageController.position.haveDimensions) {
              value = _pageController.page! - index;
              value = (1 - (value.abs() * 0.3)).clamp(0.0, 1.0);
            }

            return Transform.scale(
              scale: value,
              child: Opacity(
                opacity: value,
                child: FeatureShowcase(
                  feature: _features[index],
                  isActive: index == _currentPage,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPageIndicator() {
    return AnimatedPageIndicator(
      currentPage: _currentPage,
      pageCount: _features.length,
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _getStarted,
            child: const Text('Get Started'),
          ),
        ),
        const SizedBox(height: AppConstants.spacingM),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: _skipTutorial,
            child: const Text('Skip Tutorial'),
          ),
        ),
      ],
    );
  }
}

class FeatureData {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  FeatureData({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}
