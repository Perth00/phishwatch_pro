import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_theme.dart';
import '../widgets/confidence_meter.dart';
import '../widgets/explanation_card.dart';
import '../widgets/animated_card.dart';
import '../services/sound_service.dart';
import '../models/scan_result_data.dart';

class ScanResultScreen extends StatefulWidget {
  const ScanResultScreen({super.key, this.data});

  final ScanResultData? data;

  @override
  State<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends State<ScanResultScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Result data (dynamic)
  late final bool _isPhishing;
  late final double _confidence;
  late final String _classification;
  late final String _riskLevel;
  late final String _source;
  late final String _message;

  @override
  void initState() {
    super.initState();

    final ScanResultData? data = widget.data;
    if (data != null) {
      _isPhishing = data.isPhishing;
      _confidence = data.confidence;
      _classification = data.classification;
      _riskLevel = data.riskLevel;
      _source = data.source;
      _message = data.message;
    } else {
      // Fallback sample data when navigated directly
      _isPhishing = true;
      _confidence = 0.924;
      _classification = 'Phishing';
      _riskLevel = 'High';
      _source = 'unknown@securebank-verify.com';
      _message =
          'Your account will be suspended unless you verify your information within 24 hours. '
          'Click here to verify: https://securebank-verify.com/verify-account\n\n'
          'This is an urgent matter. Your account security is at risk.';
    }

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
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _slideController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Color get _resultColor {
    return _isPhishing ? AppTheme.errorColor : AppTheme.successColor;
  }

  IconData get _resultIcon {
    return _isPhishing ? Icons.dangerous : Icons.verified;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        title: const Text('Scan Result'),
        leading: IconButton(
          onPressed: () => context.go('/home'),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.spacingL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Result header
                _buildResultHeader(theme),

                const SizedBox(height: AppConstants.spacingXL),

                // Confidence meter
                ConfidenceMeter(
                  confidence: _confidence,
                  isPhishing: _isPhishing,
                ),

                const SizedBox(height: AppConstants.spacingXL),

                // Source information
                _buildSourceInfo(theme),

                const SizedBox(height: AppConstants.spacingXL),

                // Message content
                _buildMessageContent(theme),

                const SizedBox(height: AppConstants.spacingXL),

                // Explanation
                ExplanationCard(
                  isPhishing: _isPhishing,
                  confidence: _confidence,
                  suspiciousElements: const [
                    'Urgency tactics',
                    'Suspicious domain',
                    'Request for credentials',
                    'Impersonation attempt',
                  ],
                ),

                const SizedBox(height: AppConstants.spacingXL),

                // Action buttons
                _buildActionButtons(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultHeader(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spacingL),
      decoration: BoxDecoration(
        color: _resultColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border: Border.all(color: _resultColor.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          Icon(_resultIcon, size: 64, color: _resultColor),
          const SizedBox(height: AppConstants.spacingM),
          Text(
            _classification,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: _resultColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppConstants.spacingS),
          Text(
            'Risk Level: $_riskLevel',
            style: theme.textTheme.titleMedium?.copyWith(
              color: _resultColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceInfo(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Source Information',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Row(
              children: [
                Icon(
                  Icons.email_outlined,
                  size: 20,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                const SizedBox(width: AppConstants.spacingS),
                Expanded(
                  child: Text(
                    _source,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
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

  Widget _buildMessageContent(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Message Content',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppConstants.spacingM),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(AppConstants.spacingS),
              ),
              child: Text(
                _message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Column(
      children: [
        // Test Your Knowledge Section
        AnimatedCard(
          delay: const Duration(milliseconds: 600),
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
                    Icon(
                      Icons.quiz_outlined,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: AppConstants.spacingS),
                    Text(
                      'Test Your Knowledge',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onBackground,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingS),
                Text(
                  'Practice identifying similar threats with interactive scenarios',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onBackground.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: AppConstants.spacingM),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          SoundService.playButtonSound();
                          _showQuizDialog();
                        },
                        icon: const Icon(Icons.psychology_outlined),
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
                        icon: const Icon(Icons.play_circle_outline),
                        label: const Text(
                          'Scenario',
                          style: TextStyle(fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
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
        ),

        const SizedBox(height: AppConstants.spacingL),

        // Navigation Buttons
        AnimatedCard(
          delay: const Duration(milliseconds: 700),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    SoundService.playButtonSound();
                    context.go('/scan-history');
                  },
                  icon: const Icon(Icons.history),
                  label: const Text('View History'),
                ),
              ),
              const SizedBox(height: AppConstants.spacingM),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        SoundService.playButtonSound();
                        context.go('/home');
                      },
                      icon: const Icon(Icons.home),
                      label: const Text('Home'),
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingM),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        SoundService.playButtonSound();
                        _showScanDialog();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text(
                        'Scan Again',
                        style: TextStyle(fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showQuizDialog() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            ),
            title: Row(
              children: [
                Icon(Icons.quiz_outlined, color: AppTheme.primaryColor),
                const SizedBox(width: AppConstants.spacingS),
                const Text('Phishing Quiz'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Test your ability to identify phishing attempts similar to this one.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppConstants.spacingM),
                _buildQuizOption(
                  'Quick Quiz (5 questions)',
                  '~3 minutes',
                  Icons.flash_on,
                  theme,
                ),
                const SizedBox(height: AppConstants.spacingS),
                _buildQuizOption(
                  'Comprehensive Quiz (15 questions)',
                  '~8 minutes',
                  Icons.assignment,
                  theme,
                ),
              ],
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
                  context.go('/learn');
                },
                child: const Text('Go to Learn'),
              ),
            ],
          ),
    );
  }

  void _showScenarioDialog() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            ),
            title: Row(
              children: [
                Icon(Icons.play_circle_outline, color: AppTheme.successColor),
                const SizedBox(width: AppConstants.spacingS),
                const Text('Interactive Scenario'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Practice with realistic phishing scenarios to improve your detection skills.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppConstants.spacingM),
                _buildScenarioOption(
                  'Similar Email Scenario',
                  'Based on this result',
                  Icons.email,
                  theme,
                ),
                const SizedBox(height: AppConstants.spacingS),
                _buildScenarioOption(
                  'Random Scenario',
                  'Mixed difficulty',
                  Icons.shuffle,
                  theme,
                ),
              ],
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
                  context.go('/learn');
                },
                child: const Text('Start Practice'),
              ),
            ],
          ),
    );
  }

  void _showScanDialog() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            margin: const EdgeInsets.all(AppConstants.spacingM),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(
                AppConstants.borderRadius * 2,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spacingL),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                        // Stay on result screen with new scan
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
                        // Stay on result screen with new scan
                      },
                      icon: const Icon(Icons.link_outlined),
                      label: const Text('Scan URL'),
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingL),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildQuizOption(
    String title,
    String duration,
    IconData icon,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 20),
          const SizedBox(width: AppConstants.spacingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  duration,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScenarioOption(
    String title,
    String description,
    IconData icon,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.successColor, size: 20),
          const SizedBox(width: AppConstants.spacingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
