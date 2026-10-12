import 'package:flutter/material.dart';
import '../utils/app_motion.dart';

class DarejeNavigation extends StatelessWidget {
  const DarejeNavigation({
    super.key,
    required this.index,
    required this.onChanged,
  });
  final int index;
  final ValueChanged<int> onChanged;
  static const labels = ['Басты', 'Жетістік', 'Рейтинг', 'Профиль', 'Талдау'];
  static const icons = [
    Icons.home_outlined,
    Icons.emoji_events_outlined,
    Icons.leaderboard_outlined,
    Icons.person_outline,
    Icons.insights_outlined,
  ];
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final largeText = MediaQuery.textScalerOf(context).scale(12) > 16;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: Semantics(
                    selected: index == i,
                    button: true,
                    label: labels[i],
                    excludeSemantics: true,
                    child: Tooltip(
                      message: labels[i],
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => onChanged(i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedContainer(
                                duration: AppMotion.duration(
                                  context,
                                  AppMotion.quick,
                                ),
                                curve: AppMotion.curve,
                                width: 46,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: index == i
                                      ? colors.primaryContainer
                                      : colors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  icons[i],
                                  color: index == i
                                      ? colors.primary
                                      : colors.onSurfaceVariant,
                                  size: 23,
                                ),
                              ),
                              if (!largeText) ...[
                                const SizedBox(height: 4),
                                Text(
                                  labels[i],
                                  maxLines: 1,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        letterSpacing: 0,
                                        color: index == i
                                            ? colors.primary
                                            : colors.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
