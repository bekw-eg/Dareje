import 'package:flutter/material.dart';
import '../widgets/stat_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.firstName,
    required this.totalScore,
    required this.onAddAchievement,
  });

  final String firstName;
  final int totalScore;
  final VoidCallback onAddAchievement;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Сәлем, $firstName!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              StatCard(
                icon: Icons.stars_outlined,
                text: 'Жалпы балл: $totalScore',
              ),
              const SizedBox(height: 16),
              const StatCard(
                icon: Icons.leaderboard_outlined,
                text: 'Рейтингтегі орын: —',
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onAddAchievement,
                icon: const Icon(Icons.add),
                label: const Text('Жетістік қосу'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
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
