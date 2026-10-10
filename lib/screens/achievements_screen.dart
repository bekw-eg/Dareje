import 'package:flutter/material.dart';

import '../models/achievement.dart';
import '../services/local_achievement_service.dart';
import '../utils/achievement_date.dart';
import 'add_achievement_screen.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key, required this.service, this.onSaved});

  final LocalAchievementService service;
  final VoidCallback? onSaved;

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  late Future<List<Achievement>> _loading;

  @override
  void initState() {
    super.initState();
    _loading = widget.service.load();
  }

  Future<void> _add() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddAchievementScreen(service: widget.service),
      ),
    );
    if (saved == true && mounted) {
      _reload();
      widget.onSaved?.call();
    }
  }

  void _reload() {
    setState(() {
      _loading = widget.service.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Achievement>>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 648),
            child: snapshot.hasError
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const Text(
                        'Жетістіктерді жүктеу мүмкін болмады.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _reload,
                        child: const Text('Қайта көру'),
                      ),
                    ],
                  )
                : _buildList(snapshot.data!),
          ),
        );
      },
    );
  }

  Widget _buildList(List<Achievement> achievements) {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: achievements.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (achievements.isEmpty) ...[
                const SizedBox(height: 32),
                Icon(
                  Icons.emoji_events_outlined,
                  size: 72,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  'Әзірге жетістіктер жоқ',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Алғашқы жетістігіңізді қосып, табыстарыңызды сақтаңыз.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
              ],
              FilledButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add),
                label: const Text('Жетістік қосу'),
              ),
              const SizedBox(height: 20),
            ],
          );
        }
        final achievement = achievements[index - 1];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Chip(label: Text(achievement.category)),
                    Text(formatAchievementDate(achievement.date)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  achievement.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
