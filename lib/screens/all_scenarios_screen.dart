import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../models/learning_content.dart';
import '../services/progress_service.dart';
import '../widgets/scenario_card.dart';
import 'learn_screen.dart';
import '../widgets/locked_overlay.dart';
import '../widgets/filter_bar.dart';
import '../models/video_scenario.dart';
import '../widgets/video_scenario_card.dart';
import 'video_scenario_screen.dart';

class AllScenariosScreen extends StatefulWidget {
  const AllScenariosScreen({super.key});

  @override
  State<AllScenariosScreen> createState() => _AllScenariosScreenState();
}

class _AllScenariosScreenState extends State<AllScenariosScreen> {
  Map<String, String> _levels = <String, String>{};
  String _filterCategory = 'All';
  String _filterLevel = 'All';
  String _filterType = 'All'; // All, Scenario, Video scenario
  static const List<String> _order = <String>[
    'Beginner',
    'Intermediate',
    'Advanced',
  ];
  int _idx(String level) => _order.indexOf(level).clamp(0, _order.length - 1);

  @override
  void initState() {
    super.initState();
    _loadLevels();
  }

  Future<void> _loadLevels() async {
    final Map<String, String> lvls =
        await context.read<ProgressService>().getCategoryLevels();
    if (!mounted) return;
    setState(() => _levels = lvls);
  }

  @override
  Widget build(BuildContext context) {
    final scenarios = LearningRepository.scenarios;
    // Build from fixed categories to ensure all appear
    const List<String> categories = [
      'Basics',
      'Email Security',
      'Web Safety',
      'Advanced',
    ];
    Scenario _pickBase(String cat) {
      try {
        return scenarios.firstWhere((s) => s.category == cat);
      } catch (_) {
        return scenarios.first; // fallback
      }
    }

    final List<({String type, String category, String level, Scenario base})>
    entries = <({String type, String category, String level, Scenario base})>[];
    for (final cat in categories) {
      final base = _pickBase(cat);
      for (final level in ['Beginner', 'Intermediate', 'Advanced']) {
        entries.add((
          type: 'Scenario',
          category: cat,
          level: level,
          base: base,
        ));
        entries.add((
          type: 'Video scenario',
          category: cat,
          level: level,
          base: base,
        ));
      }
    }
    const List<String> catOrder = [
      'Basics',
      'Email Security',
      'Web Safety',
      'Advanced',
    ];
    const List<String> levelOrder = ['Beginner', 'Intermediate', 'Advanced'];
    entries.sort((a, b) {
      final ai = catOrder.indexOf(a.category);
      final bi = catOrder.indexOf(b.category);
      if (ai != bi) return ai.compareTo(bi);
      final al = levelOrder.indexOf(a.level);
      final bl = levelOrder.indexOf(b.level);
      if (al != bl) return al.compareTo(bl);
      if (a.type != b.type) return a.type.compareTo(b.type);
      return 0;
    });
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Scenarios'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            final popped = await Navigator.of(context).maybePop();
            if (!popped && context.mounted) context.go('/learn');
          },
        ),
      ),
      body: Column(
        children: [
          _buildFiltersTop(),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(AppConstants.spacingL),
              itemCount:
                  entries
                      .where(
                        (e) =>
                            _filterCategory == 'All'
                                ? true
                                : e.category == _filterCategory,
                      )
                      .where(
                        (e) =>
                            _filterLevel == 'All'
                                ? true
                                : e.level == _filterLevel,
                      )
                      .where(
                        (e) =>
                            _filterType == 'All' ? true : e.type == _filterType,
                      )
                      .length,
              separatorBuilder:
                  (_, __) => const SizedBox(height: AppConstants.spacingM),
              itemBuilder: (context, i) {
                final filtered =
                    entries
                        .where(
                          (e) =>
                              _filterCategory == 'All'
                                  ? true
                                  : e.category == _filterCategory,
                        )
                        .where(
                          (e) =>
                              _filterLevel == 'All'
                                  ? true
                                  : e.level == _filterLevel,
                        )
                        .where(
                          (e) =>
                              _filterType == 'All'
                                  ? true
                                  : e.type == _filterType,
                        )
                        .toList();
                final e = filtered[i];
                final category = e.category;
                final level = e.level;
                final s = e.base;
                final String userLevel = _levels[category] ?? 'Beginner';
                final bool locked = _idx(level) > _idx(userLevel);
                if (e.type == 'Scenario') {
                  return FutureBuilder<List<Scenario>>(
                    future: context.read<ProgressService>().loadScenarioCsv(
                      category: category,
                      level: level,
                    ),
                    builder: (context, snapshot) {
                      final Scenario? csvScenario =
                          (snapshot.data != null && snapshot.data!.isNotEmpty)
                              ? snapshot.data!.first
                              : null;
                      final String displayTitle = csvScenario?.title ?? s.title;
                      final String displayDesc =
                          csvScenario?.description ?? s.description;
                      final String displayId = csvScenario?.id ?? s.id;
                      final card = ScenarioCard(
                        scenario: ScenarioData(
                          id: displayId,
                          title: displayTitle,
                          description: displayDesc,
                          difficulty: level,
                          estimatedTime: 5,
                          completedAt: null,
                          score: null,
                        ),
                        category: category,
                        onTap: () {
                          if (locked) {
                            _showLockedHint(context, category, level);
                            return;
                          }
                          () async {
                            final bool? ok = await showDialog<bool>(
                              context: context,
                              barrierDismissible: true,
                              builder:
                                  (ctx) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    title: const Text('Start scenario?'),
                                    content: Text(
                                      'Start $category • $level now?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed:
                                            () => Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed:
                                            () => Navigator.pop(ctx, true),
                                        child: const Text('Start'),
                                      ),
                                    ],
                                  ),
                            );
                            if (ok != true) return;
                            if (!context.mounted) return;
                            context.go(
                              '/scenario/${s.id}',
                              extra: {
                                'overrideCategory': category,
                                'overrideLevel': level,
                                'overrideTitle': '$displayTitle • $level',
                              },
                            );
                          }();
                        },
                      );
                      if (!locked) return card;
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppConstants.borderRadius,
                        ),
                        child: Stack(
                          children: [
                            ColorFiltered(
                              colorFilter: const ColorFilter.mode(
                                Colors.grey,
                                BlendMode.saturation,
                              ),
                              child: card,
                            ),
                            const LockedOverlay(),
                            Positioned.fill(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(
                                    AppConstants.borderRadius,
                                  ),
                                  onTap:
                                      () => _showLockedHint(
                                        context,
                                        category,
                                        level,
                                      ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }
                // Video scenario header card -> opens full list sheet
                final header = VideoScenario(
                  id: 'video_list_${category}_$level',
                  title: 'Video scenarios',
                  videoUrl: '',
                  question: 'Watch and answer',
                  options: const ['A', 'B', 'C', 'D'],
                  correctIndex: 0,
                  explanation: '',
                  category: category,
                  difficulty: level,
                );
                final card = VideoScenarioCard(
                  scenario: header,
                  onTap:
                      () => _showVideoScenarioSheet(
                        category: category,
                        level: level,
                      ),
                );
                return card;
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showVideoScenarioSheet({
    required String category,
    required String level,
  }) async {
    final theme = Theme.of(context);
    final ps = context.read<ProgressService>();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: FutureBuilder<List<VideoScenario>>(
              future: ps.loadVideoScenarioCsv(category: category, level: level),
              builder: (context, snap) {
                final items = snap.data ?? const <VideoScenario>[];
                if (items.isEmpty) {
                  return const SizedBox(
                    height: 180,
                    child: Center(child: Text('No video scenarios available')),
                  );
                }
                return StatefulBuilder(
                  builder: (context, setLocal) {
                    Future<Set<String>> _fetchDone() async {
                      return ps.getCompletedScenarioIds(
                        scenarioIds: items.map((e) => e.id).toList(),
                      );
                    }

                    return FutureBuilder<Set<String>>(
                      future: _fetchDone(),
                      builder: (context, doneSnap) {
                        final done = doneSnap.data ?? <String>{};
                        // Progressive unlock: first 2 unlocked, then +1 for each completed
                        final int unlockedCount = (2 + done.length).clamp(
                          0,
                          items.length,
                        );
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TweenAnimationBuilder<double>(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOut,
                              tween: Tween(begin: 0.0, end: 1.0),
                              builder:
                                  (context, t, child) => Opacity(
                                    opacity: t,
                                    child: Transform.translate(
                                      offset: Offset(0, (1 - t) * 12),
                                      child: child,
                                    ),
                                  ),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppTheme.primaryColor.withOpacity(0.10),
                                      AppTheme.accentColor.withOpacity(0.10),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: theme.colorScheme.outline
                                        .withOpacity(0.2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.accentColor.withOpacity(
                                          0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.ondemand_video,
                                        color: AppTheme.accentColor,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Video scenarios',
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 6,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.primaryColor
                                                      .withOpacity(0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: AppTheme.primaryColor
                                                        .withOpacity(0.3),
                                                  ),
                                                ),
                                                child: Text(
                                                  category,
                                                  style: theme
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                        color:
                                                            AppTheme
                                                                .primaryColor,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.accentColor
                                                      .withOpacity(0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: AppTheme.accentColor
                                                        .withOpacity(0.3),
                                                  ),
                                                ),
                                                child: Text(
                                                  level,
                                                  style: theme
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                        color:
                                                            AppTheme
                                                                .accentColor,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    TweenAnimationBuilder<double>(
                                      duration: const Duration(
                                        milliseconds: 350,
                                      ),
                                      tween: Tween(begin: 0.9, end: 1.0),
                                      curve: Curves.easeOutBack,
                                      builder:
                                          (context, scale, child) =>
                                              Transform.scale(
                                                scale: scale,
                                                child: child,
                                              ),
                                      child: InkWell(
                                        onTap: () => Navigator.pop(context),
                                        borderRadius: BorderRadius.circular(20),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color:
                                                theme
                                                    .colorScheme
                                                    .surfaceVariant,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            border: Border.all(
                                              color: theme.colorScheme.outline
                                                  .withOpacity(0.25),
                                            ),
                                          ),
                                          child: const Icon(Icons.close),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: ListView.separated(
                                itemCount: items.length,
                                separatorBuilder:
                                    (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, i) {
                                  final v = items[i];
                                  final bool locked =
                                      i >= unlockedCount &&
                                      !done.contains(v.id);
                                  final content = VideoScenarioCard(
                                    scenario: v,
                                    onTap: () async {
                                      if (locked) {
                                        await showDialog<void>(
                                          context: context,
                                          barrierDismissible: true,
                                          builder:
                                              (ctx) => AlertDialog(
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                                title: const Text('Locked'),
                                                content: const Text(
                                                  'Complete the first 2 to start unlocking one-by-one.',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed:
                                                        () =>
                                                            Navigator.pop(ctx),
                                                    child: const Text('Got it'),
                                                  ),
                                                ],
                                              ),
                                        );
                                        return;
                                      }
                                      final bool? ok = await showDialog<bool>(
                                        context: context,
                                        barrierDismissible: true,
                                        builder:
                                            (dctx) => AlertDialog(
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              title: const Text(
                                                'Start video scenario?',
                                              ),
                                              content: Text(
                                                'Open "${v.title}" now?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed:
                                                      () => Navigator.pop(
                                                        dctx,
                                                        false,
                                                      ),
                                                  child: const Text('Cancel'),
                                                ),
                                                ElevatedButton(
                                                  onPressed:
                                                      () => Navigator.pop(
                                                        dctx,
                                                        true,
                                                      ),
                                                  child: const Text('Start'),
                                                ),
                                              ],
                                            ),
                                      );
                                      if (ok != true) return;
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder:
                                              (_) => VideoScenarioScreen(
                                                scenario: v,
                                              ),
                                        ),
                                      );
                                      setLocal(() {});
                                    },
                                  );
                                  final animated =
                                      TweenAnimationBuilder<double>(
                                        duration: Duration(
                                          milliseconds: 260 + i * 40,
                                        ),
                                        curve: Curves.easeOut,
                                        tween: Tween(begin: 0.0, end: 1.0),
                                        child: content,
                                        builder:
                                            (context, t, child) => Opacity(
                                              opacity: t,
                                              child: Transform.translate(
                                                offset: Offset(0, (1 - t) * 10),
                                                child: child,
                                              ),
                                            ),
                                      );
                                  if (!locked) return animated;
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      AppConstants.borderRadius,
                                    ),
                                    child: Stack(
                                      children: [
                                        ColorFiltered(
                                          colorFilter: const ColorFilter.mode(
                                            Colors.grey,
                                            BlendMode.saturation,
                                          ),
                                          child: animated,
                                        ),
                                        const LockedOverlay(),
                                        Positioned.fill(
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: () async {
                                                await showDialog<void>(
                                                  context: context,
                                                  barrierDismissible: true,
                                                  builder:
                                                      (ctx) => AlertDialog(
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                16,
                                                              ),
                                                        ),
                                                        title: const Text(
                                                          'Locked',
                                                        ),
                                                        content: const Text(
                                                          'Complete the first 2 to start unlocking one-by-one.',
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed:
                                                                () =>
                                                                    Navigator.pop(
                                                                      ctx,
                                                                    ),
                                                            child: const Text(
                                                              'Got it',
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showLockedHint(BuildContext context, String category, String level) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Unlock $level in $category by passing more attempts.'),
      ),
    );
  }

  Widget _buildFiltersTop() {
    return AnimatedFilterBar(
      categories: const [
        'All',
        'Basics',
        'Email Security',
        'Web Safety',
        'Advanced',
      ],
      levels: const ['All', 'Beginner', 'Intermediate', 'Advanced'],
      selectedCategory: _filterCategory,
      selectedLevel: _filterLevel,
      onChanged: (cat, lvl) {
        setState(() {
          _filterCategory = cat ?? 'All';
          _filterLevel = lvl ?? 'All';
        });
      },
      gradientStart: AppTheme.warningColor,
      gradientEnd: AppTheme.primaryColor,
      types: const ['All', 'Scenario', 'Video scenario'],
      selectedType: _filterType,
      onTypeChanged: (t) => setState(() => _filterType = t ?? 'All'),
    );
  }
}
