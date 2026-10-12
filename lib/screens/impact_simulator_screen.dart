import 'package:flutter/material.dart';

import '../models/achievement.dart';
import '../models/impact_scenario.dart';
import '../models/simulation_result.dart';
import '../services/impact_simulation_data_source.dart';
import '../services/impact_simulation_service.dart';
import '../widgets/analytics_charts.dart';
import '../widgets/app_widgets.dart';
import '../utils/app_colors.dart';
import '../utils/app_motion.dart';
import '../utils/app_spacing.dart';
import '../utils/category_visuals.dart';

class ImpactSimulatorScreen extends StatefulWidget {
  const ImpactSimulatorScreen({
    super.key,
    required this.dataSource,
    this.dataRevision = 0,
  });
  final ImpactSimulationDataSource dataSource;
  final int dataRevision;

  @override
  State<ImpactSimulatorScreen> createState() => _ImpactSimulatorScreenState();
}

class _ImpactSimulatorScreenState extends State<ImpactSimulatorScreen> {
  final _engine = ImpactSimulationService();
  ImpactSimulationData? _data;
  SimulationResult? _result;
  ImpactScenario? _scenario;
  String _category = 'Programming';
  bool _busy = true;
  bool _error = false;
  bool _showAfter = true;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ImpactSimulatorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dataRevision != oldWidget.dataRevision ||
        widget.dataSource != oldWidget.dataSource)
      _load();
  }

  Future<void> _load({ImpactScenario? simulate}) async {
    final request = ++_request;
    setState(() {
      _busy = true;
      _error = false;
      _result = null;
    });
    try {
      // Свежие достижения и рейтинг перед каждым расчётом, без накопления симуляций.
      final data = await widget.dataSource.load();
      if (!mounted || request != _request) return;
      final result = simulate == null || data.profile.indicators.isEmpty
          ? null
          : _engine.simulate(
              profile: data.profile,
              scenario: simulate,
              rankingProfiles: data.rankingProfiles,
            );
      setState(() {
        _data = data;
        _result = result;
        _showAfter = true;
        _busy = false;
      });
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() {
        _busy = false;
        _error = true;
      });
    }
  }

  void _another() {
    _scenario = null;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_busy) {
      return const AppSkeleton(label: 'Ағымдағы деректер жүктелуде');
    }
    if (_error || _data!.profile.indicators.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _Panel(
            title: _error
                ? 'Симуляторды жүктеу мүмкін болмады'
                : 'Әзірге көрсеткіштер жоқ',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _error
                      ? 'Профиль деректері оқылмады. Қайта көріңіз.'
                      : 'Болжам үшін ағымдағы профиль көрсеткіштері қажет.',
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => _load(simulate: _scenario),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Қайта көру'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final result = _result;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.contentWidth),
        child: RefreshIndicator(
          onRefresh: () => _load(simulate: result?.scenario),
          child: ListView(
            key: ValueKey(result == null ? 'scenario-list' : 'result-list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AppSpacing.page(context),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: AppColors.heroGradient,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 32,
                      color: const Color(0xFFDFD3F5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      result == null ? 'Келесі қадамың' : result.scenario.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      result == null
                          ? 'Бір қадам. Қанша өсім?'
                          : 'Бір ықтимал жетістік · ${ImpactScenario.categoryLabel(result.scenario.category)}',
                      style: const TextStyle(color: Color(0xFFDFD3F5)),
                    ),
                    const SizedBox(height: 16),
                    if (result == null) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          AppBadge(
                            'Қазір: ${_data!.profile.totalScore} / 100',
                            color: const Color(0xFFE6DAFF),
                          ),
                          AppBadge(
                            '${_data!.profile.achievementCount} жетістік',
                            color: const Color(0xFFE6DAFF),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.visibility_outlined,
                          size: 20,
                          color: Color(0xFFDFD3F5),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Тек болжам · нақты деректер өзгермейді',
                            style: TextStyle(
                              color: Color(0xFFDFD3F5),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (result == null) ..._selection() else ..._results(result),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _selection() {
    return [
      _Panel(
        title: 'Санатты таңда',
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final category in Achievement.categories)
              ChoiceChip(
                key: ValueKey('impact-category-$category'),
                label: Text(ImpactScenario.categoryLabel(category)),
                selected: _category == category,
                onSelected: (_) => setState(() {
                  _category = category;
                  _scenario = null;
                }),
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _Panel(
        title: 'Келесі жетістік',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final columns =
                    constraints.maxWidth >= 560 &&
                        MediaQuery.textScalerOf(context).scale(16) <= 22
                    ? 2
                    : 1;
                final width =
                    (constraints.maxWidth - 12 * (columns - 1)) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final scenario in ImpactScenario.examples.where(
                      (item) => item.category == _category,
                    ))
                      SizedBox(
                        width: width,
                        child: _ScenarioCard(
                          scenario: scenario,
                          selected: _scenario?.id == scenario.id,
                          onTap: () => setState(() => _scenario = scenario),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            const AppDetails(
              title: 'Балл ережесі',
              child: Text(
                'Бір санаттағы сценарийлерге бірдей балл ережесі қолданылады. Жетістік түрі қосымша бонус бермейді.',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const ValueKey('simulate-impact'),
              onPressed: _scenario == null
                  ? null
                  : () => _load(simulate: _scenario),
              icon: const Icon(Icons.bolt_rounded),
              label: const Text('Ықпалды есептеу'),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _results(SimulationResult result) {
    final colors = Theme.of(context).colorScheme;
    return [
      _Panel(
        title: 'Жалпы баллдың өзгерісі',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow =
                    constraints.maxWidth < 420 ||
                    MediaQuery.textScalerOf(context).scale(16) > 22;
                final cards = [
                  _ScoreTile(
                    label: 'ҚАЗІР',
                    value: result.beforeOverallScore,
                    color: colors.primaryContainer,
                    foreground: colors.onPrimaryContainer,
                    key: const ValueKey('before-score'),
                  ),
                  _ScoreTile(
                    label: 'БОЛЖАМ',
                    value: result.afterOverallScore,
                    begin: result.beforeOverallScore,
                    color: colors.tertiaryContainer,
                    foreground: colors.onTertiaryContainer,
                    key: const ValueKey('after-score'),
                  ),
                ];
                return narrow
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          cards[0],
                          const SizedBox(height: 12),
                          cards[1],
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: cards[0]),
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Icon(Icons.arrow_forward_rounded),
                          ),
                          Expanded(child: cards[1]),
                        ],
                      );
              },
            ),
            const SizedBox(height: 16),
            Text(
              '+${result.overallDelta} жалпы балл',
              key: const ValueKey('impact-score-delta'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Жалпы балл — алты көрсеткіштің дөңгелектелген орташа мәні.',
            ),
            if (result.overallDelta == 0)
              Text(
                result.impacts.any((item) => item.delta > 0)
                    ? 'Дағды өсімі бар, бірақ орташа мәнді дөңгелектеу жалпы баллды өзгертпеді.'
                    : 'Әсер ететін дағдылар 100 шегіне жеткен, сондықтан қосымша балл жоқ.',
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _Panel(
        title: 'Жергілікті рейтинг болжамы',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              result.currentRank == null
                  ? 'Орын болжамы қолжетімсіз'
                  : '#${result.currentRank} → #${result.predictedRank}',
              key: const ValueKey('impact-ranking'),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(result.rankingExplanation),
            const SizedBox(height: 8),
            const Text(
              'Тек осы құрылғыдағы / браузердегі нақты аккаунттар. Бұл жаһандық рейтинг емес.',
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _Panel(
        title: 'Дағдыларды салыстыру',
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: _duration(context),
          curve: Curves.easeOutCubic,
          builder: (context, progress, _) => SkillRadarChart(
            indicators: result.beforeMetrics,
            comparisonIndicators: result.afterMetrics,
            comparisonProgress: progress,
          ),
        ),
      ),
      const SizedBox(height: 16),
      _Panel(
        title: 'Әр дағдының өсімі',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Қазір'),
                  selected: !_showAfter,
                  onSelected: (_) => setState(() => _showAfter = false),
                ),
                ChoiceChip(
                  label: const Text('Болжам'),
                  selected: _showAfter,
                  onSelected: (_) => setState(() => _showAfter = true),
                ),
              ],
            ),
            const SizedBox(height: 20),
            for (final impact in result.impacts)
              _MetricBar(impact: impact, showAfter: _showAfter),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _Panel(
        title: 'Балл неліктен өзгерді?',
        child: AppDetails(
          title: 'Есептеуді ашу',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${result.scenario.title} · ${ImpactScenario.categoryLabel(result.scenario.category)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              for (final impact in result.impacts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${impact.before.name}: +${impact.delta}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(impact.explanation),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      FilledButton.icon(
        key: const ValueKey('try-another-scenario'),
        onPressed: _another,
        icon: const Icon(Icons.restart_alt),
        label: const Text('Басқа сценарийді көру'),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () => _load(simulate: result.scenario),
        icon: const Icon(Icons.refresh),
        label: const Text('Ағымдағы деректермен қайта есептеу'),
      ),
      const SizedBox(height: 12),
    ];
  }
}

Duration _duration(BuildContext context) =>
    AppMotion.duration(context, AppMotion.entrance);

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({
    required this.scenario,
    required this.selected,
    required this.onTap,
  });
  final ImpactScenario scenario;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: AppPressable(
        key: ValueKey('scenario-${scenario.id}'),
        onTap: onTap,
        color: selected ? colors.primaryContainer : colors.surfaceContainerLow,
        radius: 20,
        child: AnimatedContainer(
          duration: AppMotion.duration(context),
          curve: AppMotion.curve,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? colors.primary : colors.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedSwitcher(
                duration: AppMotion.duration(context, AppMotion.quick),
                child: Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : CategoryVisuals.icon(scenario.category),
                  key: ValueKey(selected),
                  color: colors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                scenario.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                scenario.description,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreTile extends StatelessWidget {
  const _ScoreTile({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.foreground,
    this.begin,
  });
  final String label;
  final int value;
  final int? begin;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: foreground,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
          tween: Tween(
            begin: (begin ?? value).toDouble(),
            end: value.toDouble(),
          ),
          duration: _duration(context),
          curve: Curves.easeOutCubic,
          builder: (context, current, _) => Text(
            '${current.round()} / 100',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}

class _MetricBar extends StatelessWidget {
  const _MetricBar({required this.impact, required this.showAfter});
  final MetricImpact impact;
  final bool showAfter;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TweenAnimationBuilder<double>(
        tween: Tween(
          begin: impact.before.value.toDouble(),
          end: (showAfter ? impact.after.value : impact.before.value)
              .toDouble(),
        ),
        duration: _duration(context),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  impact.before.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${impact.before.value} → ${impact.after.value} · +${impact.delta}',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Semantics(
              label:
                  '${impact.before.name}: ${value.round()} / 100, өсім ${impact.delta}',
              child: Stack(
                children: [
                  LinearProgressIndicator(
                    value: value / 100,
                    minHeight: 10,
                    color: colors.tertiary,
                    backgroundColor: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  LinearProgressIndicator(
                    value: impact.before.value / 100,
                    minHeight: 10,
                    color: colors.primary,
                    backgroundColor: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${value.round()} / 100',
              key: ValueKey('impact-metric-${impact.before.type.name}'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => AppReveal(
    child: AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    ),
  );
}
