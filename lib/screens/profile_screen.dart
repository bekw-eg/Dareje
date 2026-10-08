import 'package:flutter/material.dart';

import '../models/student_profile.dart';
import '../services/local_achievement_service.dart';
import '../widgets/stat_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.profile,
    required this.achievementService,
  });

  final StudentProfile profile;
  final LocalAchievementService achievementService;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<int> _achievementCount;

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  void _loadCount() {
    _achievementCount = widget.achievementService.load().then(
      (items) => items.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
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
              FutureBuilder<int>(
                future: _achievementCount,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const StatCard(
                      icon: Icons.emoji_events_outlined,
                      text: 'Жетістіктер саны: жүктелуде…',
                    );
                  }
                  if (snapshot.hasError) {
                    return Column(
                      children: [
                        const Text('Жетістіктер санын жүктеу мүмкін болмады.'),
                        TextButton(
                          onPressed: () => setState(_loadCount),
                          child: const Text('Қайта көру'),
                        ),
                      ],
                    );
                  }
                  return StatCard(
                    icon: Icons.emoji_events_outlined,
                    text: 'Жетістіктер саны: ${snapshot.data}',
                  );
                },
              ),
              const SizedBox(height: 24),
              Text('Көрсеткіштер', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text(
                'Бастапқы сынақ мәндері. Жетістіктерге әлі байланысты емес.',
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
