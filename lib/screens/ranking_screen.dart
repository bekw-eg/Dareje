import 'package:flutter/material.dart';

import '../models/student_profile.dart';
import '../models/student_ranking_entry.dart';
import '../services/ranking_data_source.dart';
import '../services/student_ranking_service.dart';
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
        oldWidget.dataRevision != widget.dataRevision) {
      _loading = _load();
    }
  }

  Future<List<StudentRankingEntry>> _load() {
    final loading = Future<List<StudentProfile>>.sync(
      widget.dataSource.loadProfiles,
    ).then(_rankingService.rank);
    // При мгновенной ошибке обработчик нужен до следующего кадра.
    // FutureBuilder всё равно получит эту ошибку и покажет повторную загрузку.
    loading.ignore();
    return loading;
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
      // Ошибку показывает FutureBuilder, в том числе после pull-to-refresh.
    }
  }

  void _openProfile(StudentProfile profile) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Көрсеткіштер')),
          body: SafeArea(child: ProfileScreen(profile: profile)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<StudentRankingEntry>>(
      future: _loading,
      builder: (context, snapshot) {
        final Widget content;
        if (snapshot.connectionState != ConnectionState.done) {
          content = const Center(
            key: ValueKey('loading'),
            child: CircularProgressIndicator(
              semanticsLabel: 'Рейтинг жүктелуде',
            ),
          );
        } else if (snapshot.hasError) {
          content = Center(
            key: const ValueKey('error'),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: _RankingMessage(
                  icon: Icons.cloud_off_outlined,
                  title: 'Рейтингті жүктеу мүмкін болмады',
                  description:
                      'Кейбір аккаунттардың деректері оқылмады. Қайта көріңіз.',
                  action: FilledButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Қайта көру'),
                  ),
                ),
              ),
            ),
          );
        } else {
          content = _buildRanking(snapshot.data!);
        }
        return AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 220),
          child: content,
        );
      },
    );
  }

  Widget _buildRanking(List<StudentRankingEntry> entries) {
    final theme = Theme.of(context);
    StudentRankingEntry? ownEntry;
    for (final entry in entries) {
      if (entry.profile.user.login == widget.currentLogin) ownEntry = entry;
    }
    // Все студенты на местах 1–3 видны, даже если делят одну позицию.
    final top = entries.where((entry) => entry.position <= 3).toList();

    return Center(
      key: const ValueKey('ranking'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Жергілікті рейтинг',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _reload,
                            tooltip: 'Жаңарту',
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Тек осы құрылғыда немесе браузерде тіркелген '
                        'аккаунттар көрсетіледі. Жалпы студенттер рейтингі '
                        'әзірге қолжетімсіз.',
                      ),
                      const SizedBox(height: 20),
                      if (ownEntry != null)
                        _OwnPositionCard(
                          entry: ownEntry,
                          onTap: ownEntry.profile.indicators.isEmpty
                              ? null
                              : () => _openProfile(ownEntry!.profile),
                        )
                      else if (entries.isNotEmpty)
                        const Text('Сіздің аккаунтыңыз бұл тізімде жоқ.'),
                      if (entries.isEmpty)
                        const _RankingMessage(
                          icon: Icons.leaderboard_outlined,
                          title: 'Рейтингте студенттер жоқ',
                          description:
                              'Рейтинг үшін сақталған студенттер деректері қажет.',
                        )
                      else if (entries.length == 1) ...[
                        const SizedBox(height: 20),
                        const _RankingMessage(
                          icon: Icons.people_outline,
                          title: 'Әзірге басқа студенттер жоқ',
                          description:
                              'Тізімде бір ғана жергілікті аккаунт бар. '
                              'Басқа құрылғылардың деректері '
                              'синхрондалмайды.',
                        ),
                      ] else ...[
                        const SizedBox(height: 24),
                        Text('TOP-3', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 4),
                        const Text('Балл тең болса, орын да бірдей болады.'),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final largeText =
                                MediaQuery.textScalerOf(context).scale(16) > 21;
                            final columns =
                                constraints.maxWidth < 540 || largeText
                                ? 1
                                : top.length.clamp(1, 3);
                            final width =
                                (constraints.maxWidth - 12 * (columns - 1)) /
                                columns;
                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
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
                                          : () => _openProfile(entry.profile),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                      if (entries.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text(
                          'Студенттер · ${entries.length}',
                          style: theme.textTheme.titleLarge,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
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
                            : () => _openProfile(entry.profile),
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Сіздің орныңыз', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 20,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '#${entry.position}',
                  style: theme.textTheme.headlineLarge,
                ),
                Text(
                  '${entry.profile.totalScore} балл',
                  style: theme.textTheme.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(entry.profile.name, style: theme.textTheme.titleMedium),
            TextButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.insights_outlined),
              label: const Text('Көрсеткіштерді көру'),
            ),
          ],
        ),
      ),
    );
  }
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
    final colors = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: entry.position == 1 ? colors.tertiaryContainer : colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isCurrent ? colors.primary : colors.outlineVariant,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                Icons.emoji_events_outlined,
                color: colors.tertiary,
                size: 32,
              ),
              Text('#${entry.position}', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              _StudentAvatar(profile: entry.profile),
              const SizedBox(height: 12),
              Text(
                entry.profile.name,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              if (isCurrent) const Text('Сіз'),
              const SizedBox(height: 8),
              Text(
                '${entry.profile.totalScore} балл',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
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
        margin: EdgeInsets.zero,
        elevation: 0,
        color: isCurrent ? colors.primaryContainer : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isCurrent ? colors.primary : colors.outlineVariant,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '#${entry.position}',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _StudentAvatar(profile: entry.profile),
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
                      ),
                      Text(
                        '${entry.profile.totalScore} балл',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null) const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StudentAvatar extends StatelessWidget {
  const _StudentAvatar({required this.profile});

  final StudentProfile profile;

  @override
  Widget build(BuildContext context) {
    final initials = [profile.user.firstName, profile.user.lastName]
        .where((name) => name.trim().isNotEmpty)
        .map((name) => name.trim().characters.first)
        .join()
        .toUpperCase();
    final colors = Theme.of(context).colorScheme;
    return CircleAvatar(
      backgroundColor: colors.secondaryContainer,
      foregroundColor: colors.onSecondaryContainer,
      child: Text(initials.isEmpty ? '?' : initials),
    );
  }
}

class _RankingMessage extends StatelessWidget {
  const _RankingMessage({
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(description, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}
