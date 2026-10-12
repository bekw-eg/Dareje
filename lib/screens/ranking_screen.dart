import 'package:flutter/material.dart';
import '../models/student_profile.dart';
import '../models/student_ranking_entry.dart';
import '../services/ranking_data_source.dart';
import '../services/student_ranking_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_motion.dart';
import '../utils/app_spacing.dart';
import '../widgets/app_widgets.dart';
import 'profile_screen.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({
    super.key,
    required this.dataSource,
    required this.currentLogin,
    this.dataRevision = 0,
  });
  final RankingDataSource dataSource;
  final String currentLogin;
  final int dataRevision;
  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  final _rankingService = StudentRankingService();
  late Future<List<StudentRankingEntry>> _loading;
  @override
  void initState() {
    super.initState();
    _loading = _load();
  }

  @override
  void didUpdateWidget(covariant RankingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dataSource != widget.dataSource ||
        oldWidget.currentLogin != widget.currentLogin ||
        oldWidget.dataRevision != widget.dataRevision)
      _loading = _load();
  }

  Future<List<StudentRankingEntry>> _load() {
    final loading = Future<List<StudentProfile>>.sync(
      widget.dataSource.loadProfiles,
    ).then(_rankingService.rank);
    loading.ignore();
    return loading;
  }

  void _reload() => setState(() {
    _loading = _load();
  });
  Future<void> _refresh() async {
    _reload();
    try {
      await _loading;
    } catch (_) {
      /* Ошибку показывает FutureBuilder. */
    }
  }

  void _openProfile(StudentProfile profile, {Object? heroTag}) =>
      Navigator.of(context).push(
        AppMotion.route<void>(
          (_) => Scaffold(
            appBar: AppBar(title: const Text('Көрсеткіштер')),
            body: SafeArea(
              child: ProfileScreen(profile: profile, avatarHeroTag: heroTag),
            ),
          ),
        ),
      );
  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<StudentRankingEntry>>(
        future: _loading,
        builder: (context, snapshot) {
          final Widget content;
          if (snapshot.connectionState != ConnectionState.done) {
            content = const AppSkeleton(
              key: ValueKey('loading'),
              label: 'Рейтинг жүктелуде',
            );
          } else if (snapshot.hasError) {
            content = AppPage(
              key: const ValueKey('error'),
              children: [
                AppEmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Рейтингті жүктеу мүмкін болмады',
                  message: 'Аккаунт деректері оқылмады.',
                  action: FilledButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Қайта көру'),
                  ),
                ),
              ],
            );
          } else {
            content = _buildRanking(snapshot.data!);
          }
          return AppStateSwitch(child: content);
        },
      );

  Widget _buildRanking(List<StudentRankingEntry> entries) {
    final theme = Theme.of(context);
    StudentRankingEntry? own;
    for (final entry in entries) {
      if (entry.profile.user.login == widget.currentLogin) own = entry;
    }
    final top = entries.where((entry) => entry.position <= 3).toList();
    return Center(
      key: const ValueKey('ranking'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.contentWidth),
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: AppSpacing.page(context).copyWith(bottom: 16),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Жергілікті рейтинг',
                              style: theme.textTheme.headlineSmall,
                            ),
                          ),
                          IconButton(
                            onPressed: _reload,
                            tooltip: 'Жаңарту',
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          const AppBadge(
                            'Осы құрылғыда',
                            icon: Icons.devices_outlined,
                          ),
                          AppBadge(
                            '${entries.length} студент',
                            color: theme.colorScheme.secondary,
                          ),
                        ],
                      ),
                      AppDetails(
                        title: 'Рейтинг туралы',
                        child: Text(
                          'Тек осы құрылғыда немесе браузерде тіркелген аккаунттар көрсетіледі. Жалпы студенттер рейтингі әзірге қолжетімсіз. Балл тең болса, орын да бірдей болады.',
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (own != null)
                        _OwnPositionCard(
                          entry: own,
                          onTap: own.profile.indicators.isEmpty
                              ? null
                              : () => _openProfile(own!.profile),
                        )
                      else if (entries.isNotEmpty)
                        const Text('Сіздің аккаунтыңыз бұл тізімде жоқ.'),
                      if (entries.isEmpty)
                        const AppEmptyState(
                          icon: Icons.leaderboard_outlined,
                          title: 'Рейтингте студенттер жоқ',
                          message: 'Сақталған студент деректері қажет.',
                        )
                      else if (entries.length == 1)
                        const AppEmptyState(
                          icon: Icons.people_outline,
                          title: 'Әзірге басқа студенттер жоқ',
                          message:
                              'Бір ғана жергілікті аккаунт бар. Басқа құрылғылар синхрондалмайды.',
                        )
                      else ...[
                        const SizedBox(height: 28),
                        const SectionHeading('TOP-3'),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final largeText =
                                MediaQuery.textScalerOf(context).scale(16) > 21;
                            final columns =
                                largeText || constraints.maxWidth < 300
                                ? 1
                                : top.length.clamp(1, 3);
                            final width =
                                (constraints.maxWidth - 10 * (columns - 1)) /
                                columns;
                            return Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                for (final entry in top)
                                  SizedBox(
                                    width: width,
                                    child: _TopStudentCard(
                                      entry: entry,
                                      isCurrent:
                                          entry.profile.user.login ==
                                          widget.currentLogin,
                                      onTap: entry.profile.indicators.isEmpty
                                          ? null
                                          : () => _openProfile(
                                              entry.profile,
                                              heroTag:
                                                  'top-${entry.profile.user.login}',
                                            ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                      if (entries.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        SectionHeading('Студенттер · ${entries.length}'),
                      ],
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: AppSpacing.page(context).copyWith(top: 0),
                sliver: SliverList.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _StudentRow(
                        key: ValueKey('student-${entry.profile.user.login}'),
                        entry: entry,
                        isCurrent:
                            entry.profile.user.login == widget.currentLogin,
                        onTap: entry.profile.indicators.isEmpty
                            ? null
                            : () => _openProfile(
                                entry.profile,
                                heroTag: 'row-${entry.profile.user.login}',
                              ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OwnPositionCard extends StatelessWidget {
  const _OwnPositionCard({required this.entry, this.onTap});
  final StudentRankingEntry entry;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.primaryContainer,
    child: Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Сіздің орныңыз',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: const Color(0xFFDFD3F5)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 24,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: AppMotion.duration(context),
                child: Text(
                  '#${entry.position}',
                  key: ValueKey(entry.position),
                  style: Theme.of(
                    context,
                  ).textTheme.displayLarge?.copyWith(color: Colors.white),
                ),
              ),
              Text(
                '${entry.profile.totalScore} балл',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            entry.profile.name,
            style: const TextStyle(color: Color(0xFFDFD3F5)),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onTap,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: EdgeInsets.zero,
            ),
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: const Text('Көрсеткіштерді көру'),
          ),
        ],
      ),
    ),
  );
}

class _TopStudentCard extends StatelessWidget {
  const _TopStudentCard({
    required this.entry,
    required this.isCurrent,
    this.onTap,
  });
  final StudentRankingEntry entry;
  final bool isCurrent;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = entry.position == 1
        ? AppColors.amber
        : theme.colorScheme.primary;
    return AppReveal(
      child: AppPressable(
        onTap: onTap,
        color: entry.position == 1
            ? const Color(0xFFFFF6E9)
            : theme.colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
          child: Column(
            children: [
              Icon(Icons.workspace_premium_outlined, size: 24, color: color),
              const SizedBox(height: 6),
              Text(
                '#${entry.position}',
                style: theme.textTheme.titleLarge?.copyWith(color: color),
              ),
              const SizedBox(height: 12),
              AppAvatar(
                firstName: entry.profile.user.firstName,
                lastName: entry.profile.user.lastName,
                heroTag: 'top-${entry.profile.user.login}',
              ),
              const SizedBox(height: 12),
              Text(
                entry.profile.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall,
              ),
              if (isCurrent)
                Text(
                  'Сіз',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              const SizedBox(height: 10),
              Text(
                '${entry.profile.totalScore} балл',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({
    super.key,
    required this.entry,
    required this.isCurrent,
    this.onTap,
  });
  final StudentRankingEntry entry;
  final bool isCurrent;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      selected: isCurrent,
      child: Card(
        color: isCurrent ? colors.primaryContainer : colors.surface,
        child: AppPressable(
          onTap: onTap,
          color: isCurrent ? colors.primaryContainer : colors.surface,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '#${entry.position}',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AppAvatar(
                  firstName: entry.profile.user.firstName,
                  lastName: entry.profile.user.lastName,
                  size: 40,
                  heroTag: 'row-${entry.profile.user.login}',
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.profile.name,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        isCurrent
                            ? 'Сіз · @${entry.profile.user.login}'
                            : '@${entry.profile.user.login}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${entry.profile.totalScore} балл',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
