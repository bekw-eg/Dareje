import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/progress_history_entry.dart';
import '../models/student_indicator.dart';
import '../utils/achievement_date.dart';
import '../utils/app_motion.dart';

class SkillRadarChart extends StatefulWidget {
  const SkillRadarChart({
    super.key,
    required this.indicators,
    this.comparisonIndicators,
    this.comparisonProgress = 1,
  });
  final List<StudentIndicator> indicators;
  final List<StudentIndicator>? comparisonIndicators;
  final double comparisonProgress;

  @override
  State<SkillRadarChart> createState() => _SkillRadarChartState();
}

class _SkillRadarChartState extends State<SkillRadarChart> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.indicators.isEmpty) return const Text('Көрсеткіштер жоқ');
    final colors = Theme.of(context).colorScheme;
    final selected =
        widget.indicators[_selected.clamp(0, widget.indicators.length - 1)];
    final comparison = widget.comparisonIndicators;
    final predicted = comparison == null
        ? null
        : comparison.firstWhere((item) => item.type == selected.type);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          predicted == null
              ? '${selected.name} · ${selected.value} / 100'
              : '${selected.name} · ${selected.value} → ${predicted.value} (+${predicted.value - selected.value})',
          key: const ValueKey('radar-tooltip'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: AspectRatio(
              aspectRatio: 1.2,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    onTapDown: (details) {
                      final center = Offset(
                        constraints.maxWidth / 2,
                        constraints.maxHeight / 2,
                      );
                      final vector = details.localPosition - center;
                      final angle =
                          (math.atan2(vector.dy, vector.dx) +
                              math.pi / 2 +
                              2 * math.pi) %
                          (2 * math.pi);
                      setState(
                        () => _selected =
                            (angle / (2 * math.pi) * widget.indicators.length)
                                .round() %
                            widget.indicators.length,
                      );
                    },
                    child: Semantics(
                      label: predicted == null
                          ? 'Дағдылар диаграммасы. ${selected.name}: ${selected.value} / 100. Төмендегі санаттарды таңдаңыз.'
                          : '${selected.name}: қазір ${selected.value}, болжам ${predicted.value}. Төмендегі дағдыларды таңдаңыз.',
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: AppMotion.duration(
                          context,
                          AppMotion.entrance,
                        ),
                        curve: AppMotion.curve,
                        builder: (context, progress, _) => CustomPaint(
                          painter: _RadarPainter(
                            widget.indicators,
                            _selected,
                            colors,
                            comparison,
                            widget.comparisonProgress,
                            progress,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        if (comparison != null)
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 20,
            runSpacing: 8,
            children: [
              Text('● Қазір', style: TextStyle(color: colors.primary)),
              Text('◆ Болжам', style: TextStyle(color: colors.tertiary)),
              const Text('Шкала: 0–100'),
            ],
          ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            for (var index = 0; index < widget.indicators.length; index++)
              ChoiceChip(
                label: Text(
                  '${index + 1}. ${widget.indicators[index].name} ${widget.indicators[index].value}',
                ),
                selected: _selected == index,
                onSelected: (_) => setState(() => _selected = index),
              ),
          ],
        ),
      ],
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(
    this.indicators,
    this.selected,
    this.colors,
    this.comparison,
    this.progress,
    this.entranceProgress,
  );
  final List<StudentIndicator> indicators;
  final int selected;
  final ColorScheme colors;
  final List<StudentIndicator>? comparison;
  final double progress;
  final double entranceProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 24;
    Offset point(int index, double ratio) {
      final angle = -math.pi / 2 + index * 2 * math.pi / indicators.length;
      return center + Offset(math.cos(angle), math.sin(angle)) * radius * ratio;
    }

    Path polygon(double Function(int) value) {
      final path = Path();
      for (var index = 0; index < indicators.length; index++) {
        final p = point(index, value(index));
        if (index == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      return path..close();
    }

    final grid = Paint()
      ..color = colors.outlineVariant
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final level in [0.25, 0.5, 0.75, 1.0]) {
      canvas.drawPath(polygon((_) => level), grid);
    }
    for (var index = 0; index < indicators.length; index++) {
      canvas.drawLine(center, point(index, 1), grid);
    }
    final data = polygon(
      (index) => indicators[index].value / 100 * entranceProgress,
    );
    canvas.drawPath(
      data,
      Paint()..color = colors.primary.withValues(alpha: 0.18),
    );
    if (comparison != null) {
      final values = {for (final item in comparison!) item.type: item.value};
      double ratio(int index) {
        final before = indicators[index].value;
        final after = values[indicators[index].type] ?? before;
        return (before + (after - before) * progress) / 100;
      }

      final predicted = polygon(ratio);
      canvas.drawPath(
        predicted,
        Paint()..color = colors.tertiary.withValues(alpha: 0.16),
      );
      canvas.drawPath(
        predicted,
        Paint()
          ..color = colors.tertiary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
      for (var index = 0; index < indicators.length; index++) {
        final p = point(index, ratio(index));
        final marker = index == selected ? 6.0 : 3.5;
        canvas.drawRect(
          Rect.fromCenter(center: p, width: marker * 2, height: marker * 2),
          Paint()..color = colors.tertiary,
        );
      }
    }
    canvas.drawPath(
      data,
      Paint()
        ..color = colors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    for (var index = 0; index < indicators.length; index++) {
      canvas.drawCircle(
        point(index, indicators[index].value / 100 * entranceProgress),
        index == selected ? 6 : 3,
        Paint()..color = colors.primary,
      );
      final label = TextPainter(
        text: TextSpan(
          text: '${index + 1}',
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final p = point(index, 1.14);
      label.paint(canvas, p - Offset(label.width / 2, label.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) => true;
}

String formatHistoryTimestamp(DateTime timestamp) {
  final local = timestamp.toLocal();
  return '${formatAchievementDate(local)} · ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

class ProgressLineChart extends StatefulWidget {
  const ProgressLineChart({super.key, required this.events});
  final List<ProgressHistoryEntry> events;

  @override
  State<ProgressLineChart> createState() => _ProgressLineChartState();
}

class _ProgressLineChartState extends State<ProgressLineChart> {
  late int _selected = widget.events.length - 1;

  @override
  void didUpdateWidget(covariant ProgressLineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.events != widget.events) _selected = widget.events.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.events.isEmpty) return const SizedBox.shrink();
    final event = widget.events[_selected];
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            '${formatHistoryTimestamp(event.timestamp)}\n${event.previousTotalScore} → ${event.newTotalScore} балл',
            key: const ValueKey('history-tooltip'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 190,
          child: LayoutBuilder(
            builder: (context, constraints) {
              void select(Offset local) {
                var nearest = 0;
                var distance = double.infinity;
                for (var index = 0; index < widget.events.length; index++) {
                  final x = _pointX(widget.events, index, constraints.maxWidth);
                  final delta = (local.dx - x).abs();
                  if (delta <= distance) {
                    nearest = index;
                    distance = delta;
                  }
                }
                setState(() => _selected = nearest);
              }

              return GestureDetector(
                key: const ValueKey('progress-line-chart'),
                onTapDown: (details) => select(details.localPosition),
                onHorizontalDragUpdate: (details) =>
                    select(details.localPosition),
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(widget.events.map((e) => e.id).join('|')),
                  tween: Tween(begin: 0, end: 1),
                  duration: AppMotion.duration(context, AppMotion.entrance),
                  builder: (context, opacity, _) => CustomPaint(
                    painter: _LinePainter(
                      widget.events,
                      _selected,
                      colors,
                      opacity,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 4,
          children: [
            Text(
              formatAchievementDate(widget.events.first.timestamp.toLocal()),
            ),
            if (widget.events.length > 1)
              Text(
                formatAchievementDate(widget.events.last.timestamp.toLocal()),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton.outlined(
              tooltip: 'Алдыңғы жазба',
              onPressed: _selected == 0
                  ? null
                  : () => setState(() => _selected--),
              icon: const Icon(Icons.chevron_left),
            ),
            Text('${_selected + 1} / ${widget.events.length}'),
            IconButton.outlined(
              tooltip: 'Келесі жазба',
              onPressed: _selected == widget.events.length - 1
                  ? null
                  : () => setState(() => _selected++),
              icon: const Icon(Icons.chevron_right),
            ),
            const Text('Нүктені таңда · күн мен балл'),
          ],
        ),
      ],
    );
  }
}

double _pointX(List<ProgressHistoryEntry> events, int index, double width) {
  final start = events.first.timestamp.microsecondsSinceEpoch;
  final span = events.last.timestamp.microsecondsSinceEpoch - start;
  if (span == 0) return width / 2;
  return 36 +
      (width - 48) *
          (events[index].timestamp.microsecondsSinceEpoch - start) /
          span;
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.events, this.selected, this.colors, this.opacity);
  final List<ProgressHistoryEntry> events;
  final int selected;
  final ColorScheme colors;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    double y(int value) => 12 + (size.height - 24) * (1 - value / 100);
    final grid = Paint()
      ..color = colors.outlineVariant
      ..strokeWidth = 1;
    for (final value in [0, 25, 50, 75, 100]) {
      canvas.drawLine(
        Offset(36, y(value)),
        Offset(size.width - 12, y(value)),
        grid,
      );
      final label = TextPainter(
        text: TextSpan(
          text: '$value',
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(0, y(value) - label.height / 2));
    }
    final path = Path();
    for (var index = 0; index < events.length; index++) {
      final point = Offset(
        _pointX(events, index, size.width),
        y(events[index].newTotalScore),
      );
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    if (events.length > 1) {
      final area = Path.from(path)
        ..lineTo(_pointX(events, events.length - 1, size.width), y(0))
        ..lineTo(_pointX(events, 0, size.width), y(0))
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.primary.withValues(alpha: 0.18 * opacity),
              colors.primary.withValues(alpha: 0),
            ],
          ).createShader(Offset.zero & size),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = colors.primary.withValues(alpha: opacity)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
    final markerX = _pointX(events, selected, size.width);
    canvas.drawLine(
      Offset(markerX, 12),
      Offset(markerX, size.height - 12),
      Paint()..color = colors.primary.withValues(alpha: 0.3 * opacity),
    );
    for (var index = 0; index < events.length; index++) {
      canvas.drawCircle(
        Offset(
          _pointX(events, index, size.width),
          y(events[index].newTotalScore),
        ),
        index == selected ? 5 : 3,
        Paint()..color = colors.primary.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter oldDelegate) => true;
}
