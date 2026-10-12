import 'package:flutter/material.dart';
import '../models/student_profile.dart';
import '../utils/app_spacing.dart';
import '../widgets/app_widgets.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.profile,
    this.avatarHeroTag,
    this.onOpenAchievements,
    this.onOpenAnalytics,
  });
  final StudentProfile profile;
  final Object? avatarHeroTag;
  final VoidCallback? onOpenAchievements;
  final VoidCallback? onOpenAnalytics;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppPage(
      children: [
        AppReveal(
          child: Column(
            children: [
              AppAvatar(
                firstName: profile.user.firstName,
                lastName: profile.user.lastName,
                size: 84,
                heroTag: avatarHeroTag,
              ),
              const SizedBox(height: 20),
              Text(
                profile.name,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              SelectableText(
                profile.email,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              AppBadge('@${profile.user.login}'),
            ],
          ),
        ),
        const SizedBox(height: 28),
        AppSurface(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stats = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Жалпы балл', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 16),
                  Semantics(
                    label: 'Жетістіктер саны: ${profile.achievementCount}',
                    excludeSemantics: true,
                    child: Row(
                      children: [
                        Icon(
                          Icons.emoji_events_outlined,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${profile.achievementCount} жетістік',
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onOpenAchievements != null)
                    TextButton(
                      onPressed: onOpenAchievements,
                      child: const Text('Жетістіктерді көру'),
                    ),
                ],
              );
              final ring = AppScoreRing(score: profile.totalScore, size: 128);
              return constraints.maxWidth < 250 ||
                      MediaQuery.textScalerOf(context).scale(16) > 22
                  ? Column(children: [ring, const SizedBox(height: 20), stats])
                  : Row(
                      children: [
                        ring,
                        const SizedBox(width: 24),
                        Expanded(child: stats),
                      ],
                    );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.section),
        SectionHeading(
          'Көрсеткіштер',
          action: onOpenAnalytics == null ? null : 'Талдау',
          onAction: onOpenAnalytics,
        ),
        AppSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final indicator in profile.indicators)
                SkillProgress(indicator: indicator),
              if (profile.indicators.isEmpty) const Text('Көрсеткіштер жоқ'),
              const AppDetails(
                title: 'Балл қалай есептеледі?',
                child: Text(
                  'Бастапқы мәндерге сақталған жетістіктердің ұпайлары қосылады. Әр дағды 100 баллмен шектеледі. Жалпы балл — көрсеткіштердің дөңгелектелген орташа мәні.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        AppSurface(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: AppDetails(
            title: 'Оқу туралы мәліметтер',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StudyField('Оқу орны', profile.university ?? 'Көрсетілмеген'),
                _StudyField('Мамандық', profile.specialty ?? 'Көрсетілмеген'),
                _StudyField(
                  'Курс',
                  profile.course?.toString() ?? 'Көрсетілмеген',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StudyField extends StatelessWidget {
  const _StudyField(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(value),
      ],
    ),
  );
}
