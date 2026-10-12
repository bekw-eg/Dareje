import 'package:flutter/material.dart';
import '../models/achievement.dart';
import '../models/student_profile.dart';
import '../utils/app_colors.dart';
import '../utils/app_spacing.dart';
import '../widgets/app_widgets.dart';
import '../widgets/achievement_tile.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.profile,
    required this.achievements,
    required this.onAddAchievement,
    required this.onOpenAchievements,
    required this.onOpenProfile,
    required this.onOpenAnalytics,
    required this.onOpenRanking,
    required this.onOpenSimulator,
    this.rankingPosition,
  });
  final StudentProfile profile;
  final List<Achievement> achievements;
  final int? rankingPosition;
  final VoidCallback onAddAchievement;
  final VoidCallback onOpenAchievements;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenAnalytics;
  final VoidCallback onOpenRanking;
  final VoidCallback onOpenSimulator;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strongest = [...profile.indicators]
      ..sort((a, b) => b.value.compareTo(a.value));
    return AppPage(
      children: [
        AppReveal(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Сәлем, ${profile.user.firstName}!',
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Әр қадам — жаңа деңгей.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        AppReveal(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(28),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked =
                    constraints.maxWidth < 250 ||
                    MediaQuery.textScalerOf(context).scale(16) > 22;
                final title = Column(
                  crossAxisAlignment: stacked
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
                  children: [
                    const AppBadge(
                      'DÁREJE',
                      color: Color(0xFFE6DAFF),
                      icon: Icons.auto_awesome_outlined,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Жалпы балл',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Сенің өсуің\nбір көріністе.',
                      textAlign: stacked ? TextAlign.center : TextAlign.start,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFDFD3F5),
                      ),
                    ),
                  ],
                );
                final ring = AppScoreRing(
                  score: profile.totalScore,
                  size: 140,
                  onDark: true,
                );
                return stacked
                    ? Column(
                        children: [title, const SizedBox(height: 20), ring],
                      )
                    : Row(
                        children: [
                          Expanded(child: title),
                          const SizedBox(width: 16),
                          ring,
                        ],
                      );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _QuickMetric(
                value: '${profile.achievementCount}',
                label: 'Жетістік',
                icon: Icons.emoji_events_outlined,
                onTap: onOpenAchievements,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickMetric(
                value: rankingPosition == null ? '—' : '#$rankingPosition',
                label: 'Жергілікті орын',
                icon: Icons.leaderboard_outlined,
                onTap: onOpenRanking,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onAddAchievement,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Жетістік қосу'),
        ),
        const SizedBox(height: AppSpacing.section),
        AppPressable(
          color: theme.colorScheme.primaryContainer,
          onTap: onOpenSimulator,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.bolt_outlined,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ықпал симуляторы',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Келесі қадамды болжап көр',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.section),
        SectionHeading(
          'Күшті дағдылар',
          action: 'Барлығы',
          onAction: onOpenProfile,
        ),
        AppSurface(
          child: Column(
            children: [
              for (final indicator in strongest.take(3))
                SkillProgress(indicator: indicator),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onOpenAnalytics,
                  icon: const Icon(Icons.insights_outlined, size: 18),
                  label: const Text('Прогресті талдау'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.section),
        SectionHeading(
          'Соңғы жетістіктер',
          action: 'Барлығы',
          onAction: onOpenAchievements,
        ),
        if (achievements.isEmpty)
          AppSurface(
            child: Row(
              children: [
                Icon(
                  Icons.emoji_events_outlined,
                  color: theme.colorScheme.primary,
                  size: 30,
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Алғашқы жетістігіңді қос.\nӨсуің осы жерден басталады.',
                  ),
                ),
              ],
            ),
          )
        else
          for (final achievement in achievements.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AchievementTile(achievement: achievement),
            ),
      ],
    );
  }
}

class _QuickMetric extends StatelessWidget {
  const _QuickMetric({
    required this.value,
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String value;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => AppPressable(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
          const SizedBox(height: 12),
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}
