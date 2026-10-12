import 'package:flutter/material.dart';
import '../models/achievement.dart';
import '../services/local_achievement_service.dart';
import '../utils/app_spacing.dart';
import '../utils/category_visuals.dart';
import '../widgets/app_widgets.dart';
import '../widgets/achievement_tile.dart';
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
  String? _category;
  String? _newId;
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
      setState(() {
        _category = null;
        _loading = widget.service.load().then((items) {
          if (items.isNotEmpty) _newId = items.first.id;
          return items;
        });
      });
      widget.onSaved?.call();
    }
  }

  void _reload() => setState(() {
    _loading = widget.service.load();
  });
  Future<void> _refresh() async {
    _reload();
    try {
      await _loading;
    } catch (_) {
      /* FutureBuilder покажет ошибку. */
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Achievement>>(
    future: _loading,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done)
        return const AppSkeleton(label: 'Жетістіктер жүктелуде');
      if (snapshot.hasError)
        return AppPage(
          children: [
            AppEmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Жетістіктерді жүктеу мүмкін болмады.',
              message: 'Сақталған деректер оқылмады.',
              action: FilledButton(
                onPressed: _reload,
                child: const Text('Қайта көру'),
              ),
            ),
          ],
        );
      final items = snapshot.data!;
      final visible = items
          .where((a) => _category == null || a.category == _category)
          .toList();
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.contentWidth),
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AppSpacing.page(context),
              itemCount: visible.length + 1,
              itemBuilder: (context, index) {
                if (index > 0)
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AchievementTile(
                      key: ValueKey(
                        visible[index - 1].id ?? 'legacy-${index - 1}',
                      ),
                      achievement: visible[index - 1],
                      highlight:
                          visible[index - 1].id != null &&
                          visible[index - 1].id == _newId,
                    ),
                  );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (items.isEmpty)
                      AppEmptyState(
                        icon: Icons.emoji_events_outlined,
                        title: 'Әзірге жетістіктер жоқ',
                        message: 'Алғашқы жеңісіңді осы жерде сақта.',
                      )
                    else ...[
                      AppReveal(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Сенің жетістіктерің',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineSmall,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${items.length} жетістік · ${items.map((a) => a.category).toSet().length} санат',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    FilledButton.icon(
                      onPressed: _add,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Жетістік қосу'),
                    ),
                    if (items.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Барлығы'),
                            selected: _category == null,
                            onSelected: (_) => setState(() => _category = null),
                          ),
                          for (final category in Achievement.categories)
                            ChoiceChip(
                              label: Text(CategoryVisuals.label(category)),
                              avatar: Icon(
                                CategoryVisuals.icon(category),
                                size: 16,
                                color: CategoryVisuals.color(category),
                              ),
                              selected: _category == category,
                              onSelected: (_) =>
                                  setState(() => _category = category),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (items.isNotEmpty && visible.isEmpty)
                      const AppEmptyState(
                        icon: Icons.filter_list_rounded,
                        title: 'Бұл санатта жетістік жоқ',
                        message:
                            'Басқа санатты таңда немесе жаңа жетістік қос.',
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    },
  );
}
