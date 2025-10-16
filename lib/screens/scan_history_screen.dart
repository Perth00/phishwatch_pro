import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_theme.dart';
import '../widgets/history_item_card.dart';
import 'package:provider/provider.dart';
import '../services/history_service.dart';
import '../models/history_item.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/animated_card.dart';
import '../services/sound_service.dart';

class ScanHistoryScreen extends StatefulWidget {
  const ScanHistoryScreen({super.key});

  @override
  State<ScanHistoryScreen> createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends State<ScanHistoryScreen>
    with TickerProviderStateMixin {
  late AnimationController _listController;
  late AnimationController _filterController;
  late Animation<double> _listAnimation;
  late Animation<double> _filterAnimation;

  // Filter state
  String _selectedFilter = 'All';
  String _sortBy = 'Date';
  bool _isFilterExpanded = false;
  final List<String> _filterOptions = ['All', 'Phishing', 'Safe', 'Suspicious'];
  final List<String> _sortOptions = ['Date', 'Risk Level', 'Confidence'];

  // Data now comes from HistoryService
  List<HistoryItem> _allHistoryItems = [];

  List<HistoryItem> get _filteredHistoryItems {
    // Always work on a modifiable copy
    List<HistoryItem> filtered = List<HistoryItem>.from(_allHistoryItems);

    // Apply classification filter
    if (_selectedFilter != 'All') {
      filtered =
          filtered
              .where((item) => item.classification == _selectedFilter)
              .toList();
    }

    // Apply sorting
    switch (_sortBy) {
      case 'Date':
        filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        break;
      case 'Risk Level':
        filtered.sort(
          (a, b) => _getRiskLevelPriority(
            b.riskLevel,
          ).compareTo(_getRiskLevelPriority(a.riskLevel)),
        );
        break;
      case 'Confidence':
        filtered.sort((a, b) => b.confidence.compareTo(a.confidence));
        break;
    }

    return filtered;
  }

  int _getRiskLevelPriority(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'high':
        return 3;
      case 'medium':
        return 2;
      case 'low':
        return 1;
      default:
        return 0;
    }
  }

  @override
  void initState() {
    super.initState();

    _listController = AnimationController(
      duration: AppAnimations.slowAnimation,
      vsync: this,
    );

    _filterController = AnimationController(
      duration: AppAnimations.normalAnimation,
      vsync: this,
    );

    _listAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _listController,
        curve: AppAnimations.defaultCurve,
      ),
    );

    _filterAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _filterController,
        curve: AppAnimations.defaultCurve,
      ),
    );

    // Start animation
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _listController.forward();
    });
  }

  @override
  void dispose() {
    _listController.dispose();
    _filterController.dispose();
    super.dispose();
  }

  void _onHistoryItemTap(HistoryItem item) {
    SoundService.playButtonSound();
    context.go('/scan-result', extra: item.toScanResultData());
  }

  void _toggleFilterExpansion() {
    SoundService.playButtonSound();
    setState(() {
      _isFilterExpanded = !_isFilterExpanded;
    });

    if (_isFilterExpanded) {
      _filterController.forward();
    } else {
      _filterController.reverse();
    }
  }

  void _updateFilter(String filter) {
    SoundService.playSelectionSound();
    setState(() {
      _selectedFilter = filter;
    });
  }

  void _updateSort(String sort) {
    SoundService.playSelectionSound();
    setState(() {
      _sortBy = sort;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    _allHistoryItems = context.watch<HistoryService>().items;
    final colorScheme = theme.colorScheme;
    final filteredItems = _filteredHistoryItems;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Scan History'),
        leading: IconButton(
          onPressed: () {
            SoundService.playButtonSound();
            context.go('/home');
          },
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            onPressed: _toggleFilterExpansion,
            icon: AnimatedRotation(
              turns: _isFilterExpanded ? 0.5 : 0.0,
              duration: AppAnimations.fastAnimation,
              child: const Icon(Icons.tune),
            ),
            tooltip: 'Filter & Sort',
          ),
        ],
      ),
      body: Column(
        children: [
          // Enhanced Filter Section
          AnimatedContainer(
            duration: AppAnimations.normalAnimation,
            height: _isFilterExpanded ? 120 : 0,
            child: _isFilterExpanded ? _buildFilterSection(theme) : null,
          ),

          // Results Summary
          _buildResultsSummary(theme, filteredItems),

          // History List
          Expanded(
            child: FadeTransition(
              opacity: _listAnimation,
              child:
                  filteredItems.isEmpty
                      ? _buildEmptyState(theme)
                      : _buildHistoryList(filteredItems),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 1,
        onTap: (index) {
          if (index == 0) context.go('/home');
        },
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_outlined,
            size: 64,
            color: theme.colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: AppConstants.spacingL),
          Text(
            'No scan history yet',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: AppConstants.spacingS),
          Text(
            'Your scan results will appear here',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: AppConstants.spacingXL),
          ElevatedButton.icon(
            onPressed: () => context.go('/home'),
            icon: const Icon(Icons.shield_outlined),
            label: const Text('Start Scanning'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(ThemeData theme) {
    return FadeTransition(
      opacity: _filterAnimation,
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.outline.withOpacity(0.2),
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter chips
            Text(
              'Filter by Type',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppConstants.spacingS),
            Wrap(
              spacing: AppConstants.spacingS,
              children:
                  _filterOptions.map((filter) {
                    final isSelected = filter == _selectedFilter;
                    return AnimatedContainer(
                      duration: AppAnimations.fastAnimation,
                      child: FilterChip(
                        label: Text(filter),
                        selected: isSelected,
                        onSelected: (selected) => _updateFilter(filter),
                        selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                        checkmarkColor: AppTheme.primaryColor,
                      ),
                    );
                  }).toList(),
            ),
            const SizedBox(height: AppConstants.spacingS),

            // Sort dropdown
            Row(
              children: [
                Text(
                  'Sort by',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: AppConstants.spacingM),
                DropdownButton<String>(
                  value: _sortBy,
                  items:
                      _sortOptions.map((option) {
                        return DropdownMenuItem(
                          value: option,
                          child: Text(option),
                        );
                      }).toList(),
                  onChanged: (value) {
                    if (value != null) _updateSort(value);
                  },
                  underline: Container(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsSummary(ThemeData theme, List<HistoryItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    final phishingCount = items.where((item) => item.isPhishing).length;
    final safeCount = items.length - phishingCount;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingM,
        vertical: AppConstants.spacingS,
      ),
      child: Row(
        children: [
          Text(
            '${items.length} result${items.length != 1 ? 's' : ''}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          if (_selectedFilter == 'All') ...[
            const Spacer(),
            _buildSummaryChip(
              '$phishingCount Phishing',
              AppTheme.errorColor,
              theme,
            ),
            const SizedBox(width: AppConstants.spacingS),
            _buildSummaryChip('$safeCount Safe', AppTheme.successColor, theme),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryChip(String text, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingS,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildHistoryList(List<HistoryItem> items) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return AnimatedCard(
          delay: Duration(milliseconds: index * 50),
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppConstants.spacingM),
            child: HistoryItemCard(
              item: items[index],
              onTap: () => _onHistoryItemTap(items[index]),
            ),
          ),
        );
      },
    );
  }
}

// HistoryItem model moved to lib/models/history_item.dart
