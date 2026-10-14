import 'package:flutter/material.dart';
import '../models/achievement.dart';
import '../utils/achievement_date.dart';
import '../utils/app_motion.dart';
import '../utils/category_visuals.dart';
import 'app_widgets.dart';

class AchievementTile extends StatefulWidget {
  const AchievementTile({
    super.key,
    required this.achievement,
    this.highlight = false,
    this.onEdit,
    this.onDelete,
    this.actionsEnabled = true,
  });
  final Achievement achievement;
  final bool highlight;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool actionsEnabled;
  @override
  State<AchievementTile> createState() => _AchievementTileState();
}

class _AchievementTileState extends State<AchievementTile> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final item = widget.achievement;
    final theme = Theme.of(context);
    final color = CategoryVisuals.color(item.category);
    return AppReveal(
      child: Semantics(
        button: true,
        expanded: _expanded,
        child: AppPressable(
          onTap: () => setState(() => _expanded = !_expanded),
          child: AnimatedContainer(
            duration: AppMotion.duration(context),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: widget.highlight
                    ? theme.colorScheme.primary.withValues(alpha: 0.45)
                    : theme.colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        CategoryVisuals.icon(item.category),
                        color: color,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title, style: theme.textTheme.titleMedium),
                          const SizedBox(height: 5),
                          Text(
                            formatAchievementDate(item.date),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: AppMotion.duration(context),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (widget.onEdit != null || widget.onDelete != null)
                      PopupMenuButton<String>(
                        tooltip: 'Жетістік әрекеттері',
                        enabled: widget.actionsEnabled,
                        icon: const Icon(Icons.more_vert_rounded),
                        onSelected: (action) {
                          if (action == 'edit') widget.onEdit?.call();
                          if (action == 'delete') widget.onDelete?.call();
                        },
                        itemBuilder: (_) => [
                          if (widget.onEdit != null)
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Өңдеу'),
                            ),
                          if (widget.onDelete != null)
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Өшіру'),
                            ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    AppBadge(
                      CategoryVisuals.label(item.category),
                      color: color,
                    ),
                    if (widget.highlight)
                      AppBadge('Жаңа', icon: Icons.auto_awesome_outlined),
                  ],
                ),
                AnimatedSize(
                  duration: AppMotion.duration(context),
                  curve: AppMotion.curve,
                  alignment: Alignment.topCenter,
                  child: _expanded
                      ? Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            item.description,
                            style: theme.textTheme.bodyMedium,
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
