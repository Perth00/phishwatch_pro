import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_theme.dart';
import '../widgets/scan_button.dart';
import '../widgets/recent_result_card.dart';
import '../widgets/bottom_nav_bar.dart';
import '../services/theme_service.dart';
import '../services/sound_service.dart';
import '../services/hugging_face_service.dart';
import '../services/gemini_service.dart';
import '../models/scan_result_data.dart';
import '../services/history_service.dart';
import 'package:provider/provider.dart';

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
  final GeminiService _gemini = GeminiService();
  static const int _minWordCount = 15; // Require at least 15 words for scanning
  DateTime? _lastBackPressedAt; // For double-back to exit

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

  void _scanMessage() {
    SoundService.playButtonSound();
    _promptAndScanMessage();
  }

  void _scanUrl() {
    SoundService.playButtonSound();
    _promptAndScanUrl();
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
        return StatefulBuilder(
          builder: (context, setState) {
            String trimmed = controller.text.trim();
            final List<String> words =
                trimmed
                    .split(RegExp(r'\s+'))
                    .where((w) => w.isNotEmpty)
                    .toList();
            final int wordCount = words.length;
            final bool meetsRequirement = wordCount >= _minWordCount;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              ),
              title: const Text('Enter message to scan'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    minLines: 5,
                    maxLines: 10,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Paste email/SMS content here...',
                      helperText:
                          'Provide at least $_minWordCount words for better accuracy',
                      errorText:
                          trimmed.isEmpty
                              ? null
                              : (meetsRequirement
                                  ? null
                                  : 'Please add more details (min $_minWordCount words).'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        meetsRequirement
                            ? Icons.check_circle
                            : Icons.error_outline,
                        size: 16,
                        color:
                            meetsRequirement
                                ? Colors.green
                                : theme.colorScheme.error,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Words: $wordCount/$_minWordCount',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color:
                              meetsRequirement
                                  ? Colors.green
                                  : theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final String value = controller.text.trim();
                    final int wc =
                        value
                            .split(RegExp(r'\s+'))
                            .where((w) => w.isNotEmpty)
                            .length;
                    if (wc < _minWordCount) {
                      SoundService.playErrorSound();
                      setState(() {});
                      return;
                    }
                    Navigator.pop(context, value);
                  },
                  child: const Text('Scan'),
                ),
              ],
            );
          },
        );
      },
    );
    if (text == null || text.isEmpty) return;

    // Show nicer analyzing dialog with animation and sound
    SoundService.playNotificationSound();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => const _AnalyzingDialog(message: 'Analyzing message...'),
    );

    try {
      final Map<String, dynamic> result = await _hf.classifyText(text: text);
      Navigator.of(context).pop();
      SoundService.playSuccessSound();

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

      // Save to history immediately (without Gemini analysis)
      final historyService = context.read<HistoryService>();
      await historyService.addFromScanResult(data);
      final String? savedId = historyService.latest?.id;
      debugPrint('💾 Initial scan saved to history (id: $savedId)');

      // Start Gemini analysis in background (non-blocking)
      debugPrint('🤖 Starting Gemini analysis in background...');
      final Future<GeminiAnalysis?> geminiAnalysisFuture = _gemini
          .analyzeContent(
            content: text,
            isPhishing: isPhishing,
            confidence: score,
            isUrl: false,
          )
          .then<GeminiAnalysis?>((analysis) {
            debugPrint('✅ Gemini analysis successful!');

            // Update the SAME history entry by id with Gemini analysis
            if (savedId != null) {
              historyService.updateGeminiById(savedId, analysis);
              debugPrint(
                '📝 History updated with Gemini analysis (id: $savedId)',
              );
            }

            return analysis;
          })
          .catchError((e) {
            debugPrint('❌ Gemini analysis failed: $e');
            debugPrint(
              '💡 Make sure you ran: flutter run --dart-define-from-file=env.json',
            );
            return null as GeminiAnalysis?;
          });

      final dataWithFuture = ScanResultData(
        isPhishing: isPhishing,
        confidence: score,
        classification: isPhishing ? 'Phishing' : 'Legitimate',
        riskLevel: ScanResultData.riskFromConfidence(
          score,
          isPhishing: isPhishing,
        ),
        source: 'User input',
        message: text,
        geminiAnalysisFuture: geminiAnalysisFuture,
      );

      // Navigate immediately
      if (mounted) {
        context.go('/scan-result', extra: dataWithFuture);
      }
    } catch (e) {
      Navigator.of(context).pop();
      SoundService.playErrorSound();
      if (!mounted) return;
      final String errorMessage = HuggingFaceService.extractErrorMessage(e);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }

  Future<void> _promptAndScanUrl() async {
    final theme = Theme.of(context);
    final TextEditingController controller = TextEditingController();

    String? url = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final String input = controller.text.trim();
            final bool looksLikeUrl = _isValidUrl(input);
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              ),
              title: const Text('Enter URL to scan'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 3,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'https://example.com/login',
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        looksLikeUrl ? Icons.check_circle : Icons.error_outline,
                        size: 16,
                        color:
                            looksLikeUrl
                                ? Colors.green
                                : theme.colorScheme.error,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        looksLikeUrl
                            ? 'Valid URL'
                            : 'Enter a valid URL (http/https)'.toString(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color:
                              looksLikeUrl
                                  ? Colors.green
                                  : theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final String value = controller.text.trim();
                    if (!_isValidUrl(value)) {
                      SoundService.playErrorSound();
                      setState(() {});
                      return;
                    }
                    Navigator.pop(context, value);
                  },
                  child: const Text('Scan'),
                ),
              ],
            );
          },
        );
      },
    );

    if (url == null || url.isEmpty) return;

    SoundService.playNotificationSound();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _AnalyzingDialog(message: 'Analyzing URL...'),
    );

    try {
      final Map<String, dynamic> result = await _hf.classifyUrl(url: url);
      Navigator.of(context).pop();
      SoundService.playSuccessSound();

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
        source: 'URL',
        message: url,
      );

      // Save to history immediately (without Gemini analysis)
      final historyService = context.read<HistoryService>();
      await historyService.addFromScanResult(data);
      final String? savedId = historyService.latest?.id;
      debugPrint('💾 Initial scan saved to history (id: $savedId)');

      // Start Gemini analysis in background (non-blocking)
      debugPrint('🤖 Starting Gemini analysis for URL in background...');
      final Future<GeminiAnalysis?> geminiAnalysisFuture = _gemini
          .analyzeContent(
            content: url,
            isPhishing: isPhishing,
            confidence: score,
            isUrl: true,
          )
          .then<GeminiAnalysis?>((analysis) {
            debugPrint('✅ Gemini analysis successful!');

            // Update the SAME history entry by id with Gemini analysis
            if (savedId != null) {
              historyService.updateGeminiById(savedId, analysis);
              debugPrint(
                '📝 History updated with Gemini analysis (id: $savedId)',
              );
            }

            return analysis;
          })
          .catchError((e) {
            debugPrint('❌ Gemini analysis failed: $e');
            debugPrint(
              '💡 Make sure you ran: flutter run --dart-define-from-file=env.json',
            );
            return null as GeminiAnalysis?;
          });

      final dataWithFuture = ScanResultData(
        isPhishing: isPhishing,
        confidence: score,
        classification: isPhishing ? 'Phishing' : 'Legitimate',
        riskLevel: ScanResultData.riskFromConfidence(
          score,
          isPhishing: isPhishing,
        ),
        source: 'URL',
        message: url,
        geminiAnalysisFuture: geminiAnalysisFuture,
      );

      if (mounted) {
        context.go('/scan-result', extra: dataWithFuture);
      }
    } catch (e) {
      Navigator.of(context).pop();
      SoundService.playErrorSound();
      if (!mounted) return;
      final String errorMessage = HuggingFaceService.extractErrorMessage(e);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }

  bool _isValidUrl(String value) {
    if (value.isEmpty) return false;
    final Uri? uri = Uri.tryParse(value);
    if (uri == null) return false;
    if (!(uri.isScheme('http') || uri.isScheme('https'))) return false;
    return uri.host.isNotEmpty;
  }

  void _viewSecurityTips() {
    SoundService.playButtonSound();
    context.go('/learn');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return WillPopScope(
      onWillPop: () async {
        final DateTime now = DateTime.now();
        if (_lastBackPressedAt == null ||
            now.difference(_lastBackPressedAt!) > const Duration(seconds: 2)) {
          _lastBackPressedAt = now;
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Press back again to exit')),
          );
          return false; // don't exit yet
        }
        return true; // exit app
      },
      child: Scaffold(
      backgroundColor: colorScheme.surface,
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
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: AppConstants.spacingS),
        Text(
          'Scan messages or URLs to check if they\'re legitimate or potentially harmful.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
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
            color: theme.colorScheme.onSurface,
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

class _AnalyzingDialog extends StatefulWidget {
  const _AnalyzingDialog({required this.message});

  final String message;

  @override
  State<_AnalyzingDialog> createState() => _AnalyzingDialogState();
}

class _AnalyzingDialogState extends State<_AnalyzingDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius * 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RotationTransition(
              turns: Tween<double>(begin: 0, end: 0.5).animate(
                CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
              ),
              child: Icon(
                Icons.hourglass_top_rounded,
                size: 56,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(widget.message, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            LinearProgressIndicator(minHeight: 4, color: AppTheme.primaryColor),
          ],
        ),
      ),
    );
  }
}
