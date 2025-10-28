import 'package:flutter/material.dart';
import '../constants/app_theme.dart';

typedef OnFilterChanged = void Function(String? category, String? level);
typedef OnTypeChanged = void Function(String? type);

class AnimatedFilterBar extends StatefulWidget {
  final List<String> categories;
  final List<String> levels;
  final String selectedCategory;
  final String selectedLevel;
  final OnFilterChanged onChanged;
  final Color? gradientStart;
  final Color? gradientEnd;
  final List<String>? types;
  final String? selectedType;
  final OnTypeChanged? onTypeChanged;

  const AnimatedFilterBar({
    super.key,
    required this.categories,
    required this.levels,
    required this.selectedCategory,
    required this.selectedLevel,
    required this.onChanged,
    this.gradientStart,
    this.gradientEnd,
    this.types,
    this.selectedType,
    this.onTypeChanged,
  });

  @override
  State<AnimatedFilterBar> createState() => _AnimatedFilterBarState();
}

class _AnimatedFilterBarState extends State<AnimatedFilterBar> {
  String? _hoveredCat;
  String? _hoveredLvl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color start = widget.gradientStart ?? AppTheme.gradientStart;
    final Color end = widget.gradientEnd ?? AppTheme.gradientEnd;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [start.withOpacity(0.17), end.withOpacity(0.17)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel('Category', theme),
          const SizedBox(height: 8),
          _buildScrollableChips(
            items: widget.categories,
            selected: widget.selectedCategory,
            hovered: _hoveredCat,
            onHover: (v) => setState(() => _hoveredCat = v),
            onSelect: (v) => widget.onChanged(v, widget.selectedLevel),
          ),
          const SizedBox(height: 12),
          _buildSectionLabel('Level', theme),
          const SizedBox(height: 8),
          _buildScrollableChips(
            items: widget.levels,
            selected: widget.selectedLevel,
            hovered: _hoveredLvl,
            onHover: (v) => setState(() => _hoveredLvl = v),
            onSelect: (v) => widget.onChanged(widget.selectedCategory, v),
          ),
          if ((widget.types ?? const <String>[]).isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildSectionLabel('Type', theme),
            const SizedBox(height: 8),
            _buildScrollableChips(
              items: widget.types!,
              selected:
                  widget.selectedType ??
                  (widget.types!.isNotEmpty ? widget.types!.first : ''),
              hovered: null,
              onHover: (_) {},
              onSelect: (v) => widget.onTypeChanged?.call(v),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text, ThemeData theme) {
    return Row(
      children: [
        Text(
          text,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.8),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildScrollableChips({
    required List<String> items,
    required String selected,
    required String? hovered,
    required ValueChanged<String?> onHover,
    required ValueChanged<String> onSelect,
  }) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemBuilder: (context, index) {
          final String value = items[index];
          final bool isSelected = value == selected;
          final bool isHovered = value == hovered;
          return _AnimatedPill(
            label: value,
            selected: isSelected,
            hovered: isHovered,
            onHover: (h) => onHover(h ? value : null),
            onTap: () => onSelect(value),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: items.length,
      ),
    );
  }
}

class _AnimatedPill extends StatefulWidget {
  final String label;
  final bool selected;
  final bool hovered;
  final ValueChanged<bool> onHover;
  final VoidCallback onTap;

  const _AnimatedPill({
    required this.label,
    required this.selected,
    required this.hovered,
    required this.onHover,
    required this.onTap,
  });

  @override
  State<_AnimatedPill> createState() => _AnimatedPillState();
}

class _AnimatedPillState extends State<_AnimatedPill> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool selected = widget.selected;
    final bool hovered = widget.hovered;

    final Color baseBorder = theme.colorScheme.outline.withOpacity(0.25);
    final Color selectedBorder = AppTheme.primaryColor.withOpacity(0.6);
    final Color hoverBorder = AppTheme.accentColor.withOpacity(0.5);

    final Color baseBg = theme.colorScheme.surfaceVariant.withOpacity(0.6);
    final Color selectedBg = AppTheme.primaryColor.withOpacity(0.15);
    final Color hoverBg = AppTheme.accentColor.withOpacity(0.12);

    final Color textColor =
        selected
            ? AppTheme.primaryVariant
            : theme.colorScheme.onSurface.withOpacity(0.9);

    return MouseRegion(
      onEnter: (_) => widget.onHover(true),
      onExit: (_) => widget.onHover(false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: TweenAnimationBuilder<double>(
          duration: AppAnimations.fastAnimation,
          curve: AppAnimations.defaultCurve,
          tween: Tween<double>(
            begin: 1,
            end: hovered ? 1.04 : (selected ? 1.02 : 1.0),
          ),
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: AnimatedContainer(
                duration: AppAnimations.normalAnimation,
                curve: AppAnimations.defaultCurve,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: hovered ? hoverBg : (selected ? selectedBg : baseBg),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color:
                        hovered
                            ? hoverBorder
                            : (selected ? selectedBorder : baseBorder),
                    width: selected ? 1.6 : 1.0,
                  ),
                  boxShadow: [
                    if (hovered)
                      BoxShadow(
                        color: AppTheme.accentColor.withOpacity(0.18),
                        blurRadius: 16,
                        spreadRadius: 1,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: AppAnimations.fastAnimation,
                      child:
                          selected
                              ? Icon(
                                Icons.check_circle,
                                key: const ValueKey('on'),
                                size: 16,
                                color: AppTheme.primaryVariant,
                              )
                              : Icon(
                                Icons.circle_outlined,
                                key: const ValueKey('off'),
                                size: 16,
                                color: baseBorder,
                              ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: textColor,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 2),
                    AnimatedOpacity(
                      duration: AppAnimations.fastAnimation,
                      opacity: hovered ? 1 : 0,
                      child: const Text('✨'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
