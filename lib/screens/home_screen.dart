import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../constants/app_theme.dart';
import '../widgets/scan_button.dart';
import '../widgets/recent_result_card.dart';
import '../widgets/bottom_nav_bar.dart';
import '../services/theme_service.dart';
import '../services/sound_service.dart';
import '../services/hugging_face_service.dart';
import '../models/scan_result_data.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _headerController;
  late AnimationController _contentController;
  late Animation<double> _headerAnimation;
  late Animation<Offset> _contentSlideAnimation;
  late Animation<double> _contentFadeAnimation;

  int _currentNavIndex = 0;
  final HuggingFaceService _hf = HuggingFaceService();

  @override
  void initState() {
    super.initState();

    _headerController = AnimationController(
      duration: AppAnimations.normalAnimation,
      vsync: this,
    );

    _contentController = AnimationController(
      duration: AppAnimations.slowAnimation,
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

    // Start animations with delay
    _headerController.forward();
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _contentController.forward();
    });
  }

  @override
  void dispose() {
    _headerController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    SoundService.playButtonSound();
    setState(() {
      _currentNavIndex = index;
    });

    // Navigate based on index
    switch (index) {
      case 0:
        // Already on home
        break;
      case 1:
        _showScanDialog();
        break;
      case 2:
        context.go('/learn');
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

  void _scanMessage() {
    SoundService.playButtonSound();
    _promptAndScanMessage();
  }

  void _scanUrl() {
    SoundService.playButtonSound();
    context.go('/scan-result');
  }

  void _viewHistory() {
    SoundService.playButtonSound();
    context.go('/scan-history');
  }

  Future<void> _promptAndScanMessage() async {
    final theme = Theme.of(context);
    final TextEditingController controller = TextEditingController();
    final String? text = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          ),
          title: const Text('Enter message to scan'),
          content: TextField(
            controller: controller,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Paste email/SMS content here...',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Scan'),
            ),
          ],
        );
      },
    );
    if (text == null || text.isEmpty) return;

    // Show progress
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Analyzing...'),
              ],
            ),
          ),
        );
      },
    );

    try {
      final Map<String, dynamic> result = await _hf.classifyText(text: text);
      Navigator.of(context).pop();

      final String rawLabel = (result['label'] as String).toUpperCase();
      final double score = (result['score'] as num).toDouble();
      final bool isPhishing =
          rawLabel.contains('PHISH') || rawLabel == 'LABEL_1';

      final ScanResultData data = ScanResultData(
        isPhishing: isPhishing,
        confidence: score,
        classification: isPhishing ? 'Phishing' : 'Legitimate',
        riskLevel: ScanResultData.riskFromConfidence(
          score,
          isPhishing: isPhishing,
        ),
        source: 'User input',
        message: text,
      );

      context.go('/scan-result', extra: data);
    } catch (e) {
      Navigator.of(context).pop();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Scan failed: ' + e.toString())));
    }
  }

  void _viewSecurityTips() {
    SoundService.playButtonSound();
    context.go('/learn');
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'PhishWatch Pro',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
          ),
          Consumer<ThemeService>(
            builder: (context, themeService, child) {
              return IconButton(
                onPressed: themeService.toggleTheme,
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
    );
  }

  Widget _buildContent(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and description
          _buildTitleSection(theme),

          const SizedBox(height: AppConstants.spacingXL),

          // Scan buttons
          _buildScanButtons(),

          const SizedBox(height: AppConstants.spacingXL),

          // Recent result
          _buildRecentResult(theme),

          const SizedBox(height: AppConstants.spacingXL),

          // Quick actions
          _buildQuickActions(theme),
        ],
      ),
    );
  }

  Widget _buildTitleSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Detect Phishing Attempts',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onBackground,
          ),
        ),
        const SizedBox(height: AppConstants.spacingS),
        Text(
          'Scan messages or URLs to check if they\'re legitimate or potentially harmful.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onBackground.withOpacity(0.7),
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildScanButtons() {
    return Column(
      children: [
        ScanButton(
          icon: Icons.message_outlined,
          label: 'Scan Message',
          onPressed: _scanMessage,
        ),
        const SizedBox(height: AppConstants.spacingM),
        ScanButton(
          icon: Icons.link_outlined,
          label: 'Scan URL',
          onPressed: _scanUrl,
        ),
      ],
    );
  }

  Widget _buildRecentResult(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Result',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onBackground,
          ),
        ),
        const SizedBox(height: AppConstants.spacingM),
        const RecentResultCard(),
      ],
    );
  }

  Widget _buildQuickActions(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: TextButton(
            onPressed: _viewHistory,
            child: const Text('View History'),
          ),
        ),
        const SizedBox(width: AppConstants.spacingM),
        Expanded(
          child: TextButton(
            onPressed: _viewSecurityTips,
            child: const Text('Security Tips'),
          ),
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

            ScanButton(
              icon: Icons.message_outlined,
              label: 'Scan Message',
              onPressed: () {
                Navigator.pop(context);
                _scanMessage();
              },
            ),

            const SizedBox(height: AppConstants.spacingM),

            ScanButton(
              icon: Icons.link_outlined,
              label: 'Scan URL',
              onPressed: () {
                Navigator.pop(context);
                _scanUrl();
              },
            ),

            const SizedBox(height: AppConstants.spacingL),
          ],
        ),
      ),
    );
  }
}
