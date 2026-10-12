import 'package:flutter/material.dart';
import '../widgets/stat_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.firstName,
    required this.totalScore,
    required this.onAddAchievement,
    this.onOpenSimulator,
  });

  final String firstName;
  final int totalScore;
  final VoidCallback onAddAchievement;
  final VoidCallback? onOpenSimulator;

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
              if (onOpenSimulator != null) ...[
                const SizedBox(height: 20),
                Card(
                  margin: EdgeInsets.zero,
                  elevation: 0,
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 32,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Келесі жетістігіңіздің ықпалын көріңіз',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Дағды өсімі мен жергілікті рейтингтегі орныңызды алдын ала болжаңыз.',
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: onOpenSimulator,
                          icon: const Icon(Icons.bolt_rounded),
                          label: const Text('Ықпал симуляторы'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
