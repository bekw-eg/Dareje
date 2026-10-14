import 'package:flutter/material.dart';

import '../models/progress_analytics.dart';
import '../models/student_indicator.dart';
import '../services/analytics_data_source.dart';
import '../services/progress_analytics_service.dart';
import '../utils/achievement_date.dart';
import '../widgets/analytics_charts.dart';
import '../widgets/app_widgets.dart';
import '../utils/app_spacing.dart';
import '../utils/category_visuals.dart';

class ProgressAnalyticsScreen extends StatefulWidget {
  const ProgressAnalyticsScreen({
    super.key,
    required this.dataSource,
    this.dataRevision = 0,
    this.clock,
  });

  final AnalyticsDataSource dataSource;
  final int dataRevision;
  final DateTime Function()? clock;

  @override
  State<ProgressAnalyticsScreen> createState() =>
      _ProgressAnalyticsScreenState();
}

class _ProgressAnalyticsScreenState extends State<ProgressAnalyticsScreen> {
  final _analytics = ProgressAnalyticsService();
  late Future<ProgressAnalyticsData> _loading;
  AnalyticsPeriod _period = AnalyticsPeriod.month;

  @override
  void initState() {
    super.initState();
    _loading = _load();
  }

  @override
  void didUpdateWidget(covariant ProgressAnalyticsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dataRevision != oldWidget.dataRevision ||
        widget.dataSource != oldWidget.dataSource) {
      _loading = _load();
    }
  }

  Future<ProgressAnalyticsData> _load() {
    final result = Future<ProgressAnalyticsData>.sync(widget.dataSource.load);
    result.ignore();
    return result;
  }

  void _reload() {
    setState(() {
      _loading = _load();
    });
  }

  Future<void> _refresh() async {
    _reload();
    try {
      await _loading;
    } catch (_) {
      /* Ошибку показывает FutureBuilder. */
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProgressAnalyticsData>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const AppSkeleton(label: 'Талдау жүктелуде');
        }
        if (snapshot.hasError) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: _AnalyticsCard(
                  title: 'Талдауды жүктеу мүмкін болмады',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Сақталған деректер оқылмады. Қайта көріңіз.'),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Қайта көру'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        final summary = _analytics.summarize(
          data: snapshot.data!,
          period: _period,
          now: (widget.clock ?? DateTime.now)(),
        );
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.contentWidth,
            ),
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AppSpacing.page(context),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Прогресс талдауы',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Жаңарту',
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Өсуіңді бір көріністе көр.'),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final period in AnalyticsPeriod.values)
                        ChoiceChip(
                          label: Text(period.label),
                          selected: _period == period,
                          onSelected: (_) => setState(() => _period = period),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _Overview(summary: summary),
                  const SizedBox(height: 16),
                  _AnalyticsCard(
                    title: 'Дағдылар көрінісі',
                    subtitle: 'Дағдыны таңда · 0–100',
                    child: SkillRadarChart(
                      indicators: summary.data.profile.indicators,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _AnalyticsCard(
                    title: 'Балл тарихы · ${_period.label}',
                    subtitle:
                        'Графикте өзгеріс сақталған уақыт көрсетіледі, жетістіктің алынған күні емес.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (summary.events.isEmpty)
                          _EmptyMessage(
                            icon: Icons.show_chart,
                            title: summary.data.history.isEmpty
                                ? 'Әзірге прогресс тарихы жоқ'
                                : 'Бұл кезеңде жазбалар жоқ',
                            message: summary.data.history.isEmpty
                                ? 'Жаңа жетістік сақталған кезде алғашқы нақты жазба пайда болады.'
                                : 'Басқа кезеңді таңдаңыз немесе жаңа жетістік қосыңыз.',
                          )
                        else
                          ProgressLineChart(events: summary.events),
                        const SizedBox(height: 12),
                        const AppDetails(
                          title: 'Тарих туралы',
                          child: Text(
                            'Графикте нақты сақталған уақыт көрсетіледі. Тек тарих енгізілгеннен кейін сақталған өзгерістер қамтылады. Бұрынғы өзгерістер қалпына келтірілмейді.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _AnalyticsCard(
                    title: 'Санаттар мен дағдылар',
                    child: _CategoryBreakdown(summary: summary),
                  ),
                  const SizedBox(height: 16),
                  _AnalyticsCard(
                    title: 'Жетістіктер хронологиясы',
                    subtitle:
                        'Алынған күні бойынша жаңадан ескіге қарай. Барлық жетістіктер.',
                    child: summary.timeline.isEmpty
                        ? const _EmptyMessage(
                            icon: Icons.emoji_events_outlined,
                            title: 'Әзірге жетістіктер жоқ',
                            message:
                                'Алғашқы жетістігіңізді «Жетістіктер» бөлімінде қосыңыз.',
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final entry in summary.timeline)
                                _TimelineRow(
                                  entry: entry,
                                  indicators: summary.data.profile.indicators,
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

String _change(int? value) =>
    value == null ? '—' : '${value >= 0 ? '+' : ''}$value';
String _names(List<StudentIndicator> indicators) =>
    indicators.isEmpty ? '—' : indicators.map((item) => item.name).join(', ');

class _Overview extends StatelessWidget {
  const _Overview({required this.summary});
  final ProgressAnalyticsSummary summary;
  @override
  Widget build(BuildContext context) {
    final data = summary.data;
    final theme = Theme.of(context);
    return AppReveal(
      child: AppSurface(
        color: theme.colorScheme.primaryContainer,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Жеке прогресс', style: theme.textTheme.titleLarge),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final width =
                    constraints.maxWidth < 260 ||
                        MediaQuery.textScalerOf(context).scale(16) > 22
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 16) / 2;
                return Wrap(
                  spacing: 16,
                  runSpacing: 20,
                  children: [
                    SizedBox(
                      width: width,
                      child: _Metric(
                        'Жалпы балл',
                        '${data.profile.totalScore} / 100',
                        key: const ValueKey('analytics-score'),
                        prominent: true,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _Metric(
                        'Тіркелген өзгеріс',
                        '${_change(summary.recordedScoreChange)} балл',
                        key: const ValueKey('analytics-change'),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _Metric(
                        'Жетістіктер',
                        '${data.profile.achievementCount}',
                        key: const ValueKey('analytics-count'),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _Metric(
                        'Жергілікті орын',
                        data.rankingPosition == null
                            ? '—'
                            : '#${data.rankingPosition}',
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            if (data.rankingUnavailable)
              const Text('Рейтинг деректері оқылмады. Жаңартып көріңіз.')
            else
              const AppBadge(
                'Осы құрылғыдағы аккаунттар',
                icon: Icons.devices_outlined,
              ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, {super.key, this.prominent = false});
  final String label;
  final String value;
  final bool prominent;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        value,
        style: prominent
            ? Theme.of(context).textTheme.headlineMedium
            : Theme.of(context).textTheme.headlineSmall,
      ),
    ],
  );
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.summary});
  final ProgressAnalyticsSummary summary;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          AppBadge(
            'Күшті: ${_names(summary.strongest)}',
            icon: Icons.north_east_rounded,
          ),
          AppBadge(
            'Даму: ${_names(summary.growthOpportunity)}',
            color: Theme.of(context).colorScheme.secondary,
          ),
        ],
      ),
      const SizedBox(height: 24),
      for (final category in summary.categories)
        SkillProgress(
          key: ValueKey('category-${category.indicator.type.name}'),
          indicator: category.indicator,
          subtitle:
              '${category.achievementCount} тікелей жетістік · ${_change(category.recordedChange)} тіркелген өсім',
        ),
      AppDetails(
        title: 'Санаттар қалай әсер етеді?',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Даму мүмкіндігі — ағымдағы мәні ең төмен дағды. Бұл өсу қарқынын білдірмейді.',
            ),
            const SizedBox(height: 8),
            Text(
              'Басқа: ${summary.data.achievements.where((a) => a.category == 'Other').length} жетістік. Жеке көрсеткіші жоқ; топтық жұмысқа әсер етеді.',
            ),
            const SizedBox(height: 8),
            const Text(
              'Топтық жұмысқа басқа санаттардағы жетістіктер әсер етеді; бұл жеке жетістік санаты емес.',
            ),
          ],
        ),
      ),
    ],
  );
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.entry, required this.indicators});
  final AchievementTimelineEntry entry;
  final List<StudentIndicator> indicators;

  @override
  Widget build(BuildContext context) {
    final event = entry.historyEntry;
    final influence = event == null
        ? <String>[]
        : [
            for (final indicator in indicators)
              if ((event.indicatorChanges[indicator.type] ?? 0) != 0)
                '${indicator.name} ${_change(event.indicatorChanges[indicator.type])}',
          ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            CategoryVisuals.icon(entry.achievement.category),
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.achievement.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${CategoryVisuals.label(entry.achievement.category)} · ${formatAchievementDate(entry.achievement.date)}',
                ),
                const SizedBox(height: 6),
                if (event == null)
                  const Text('Нақты ықпал тарихта сақталмаған.')
                else ...[
                  Text('Соңғы өзгеріс: ${event.operation.label}'),
                  Text(
                    'Жалпы балл: ${_change(event.totalScoreChange)} · ${event.previousTotalScore} → ${event.newTotalScore}',
                  ),
                  AppDetails(
                    title: 'Ықпал туралы',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          influence.isEmpty
                              ? 'Көрсеткіштер өзгермеді.'
                              : influence.join(' · '),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Өзгеріс уақыты: ${formatHistoryTimestamp(event.timestamp)}',
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  const _AnalyticsCard({
    required this.title,
    required this.child,
    this.subtitle,
  });
  final String title;
  final String? subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => AppReveal(
    child: AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          child,
          if (subtitle != null)
            AppDetails(title: 'Толығырақ', child: Text(subtitle!)),
        ],
      ),
    ),
  );
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Column(
      children: [
        Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
      ],
    ),
  );
}
