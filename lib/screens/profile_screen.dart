import 'package:flutter/material.dart';

import '../models/student_profile.dart';
import '../widgets/stat_card.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.profile});

  final StudentProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(profile.name, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(profile.email, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 24),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Оқу орны', style: theme.textTheme.labelLarge),
                      Text(profile.university ?? 'Көрсетілмеген'),
                      const SizedBox(height: 16),
                      Text('Мамандық', style: theme.textTheme.labelLarge),
                      Text(profile.specialty ?? 'Көрсетілмеген'),
                      const SizedBox(height: 16),
                      Text('Курс', style: theme.textTheme.labelLarge),
                      Text(profile.course?.toString() ?? 'Көрсетілмеген'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              StatCard(
                icon: Icons.stars_outlined,
                text: 'Жалпы балл: ${profile.totalScore}',
              ),
              const SizedBox(height: 16),
              StatCard(
                icon: Icons.emoji_events_outlined,
                text: 'Жетістіктер саны: ${profile.achievementCount}',
              ),
              const SizedBox(height: 24),
              Text('Көрсеткіштер', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text(
                'Бастапқы мәндерге сақталған жетістіктердің ұпайлары қосылады.',
              ),
              const SizedBox(height: 16),
              for (final indicator in profile.indicators)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(indicator.name)),
                          const SizedBox(width: 12),
                          Text('${indicator.value} / 100'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: indicator.value / 100,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(8),
                        semanticsLabel: indicator.name,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
