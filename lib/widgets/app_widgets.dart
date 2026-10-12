import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/student_indicator.dart';
import '../utils/app_motion.dart';
import '../utils/app_spacing.dart';
import '../utils/category_visuals.dart';

class AppPage extends StatelessWidget {
  const AppPage({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppSpacing.contentWidth),
      child: SingleChildScrollView(
        padding: AppSpacing.page(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    ),
  );
}

class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
  });
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Material(
    color: color ?? Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radius),
      side: BorderSide(
        color: Theme.of(
          context,
        ).colorScheme.outlineVariant.withValues(alpha: 0.6),
      ),
    ),
    child: Padding(padding: padding, child: child),
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (action != null)
          TextButton(onPressed: onAction, child: Text(action!)),
      ],
    ),
  );
}

/// Однократное появление; нет таймеров и бесконечных декоративных анимаций.
class AppReveal extends StatelessWidget {
  const AppReveal({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: AppMotion.duration(context, AppMotion.entrance),
    curve: AppMotion.curve,
    child: child,
    builder: (context, value, child) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, 12 * (1 - value)),
        child: child,
      ),
    ),
  );
}

class AppStateSwitch extends StatelessWidget {
  const AppStateSwitch({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: AppMotion.duration(context),
    switchInCurve: AppMotion.curve,
    switchOutCurve: Curves.easeIn,
    layoutBuilder: (current, previous) => Stack(
      alignment: Alignment.topCenter,
      children: [
        for (final old in previous)
          IgnorePointer(child: ExcludeSemantics(child: old)),
        if (current != null) current,
      ],
    ),
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: animation.drive(
          Tween(begin: const Offset(0, 0.025), end: Offset.zero),
        ),
        child: child,
      ),
    ),
    child: child,
  );
}

class AppPressable extends StatefulWidget {
  const AppPressable({
    super.key,
    required this.child,
    this.onTap,
    this.color,
    this.radius = AppSpacing.radius,
  });
  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final double radius;
  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> {
  bool _pressed = false;
  void _press(bool value) {
    if (_pressed != value && widget.onTap != null)
      setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _press(true),
    onPointerUp: (_) => _press(false),
    onPointerCancel: (_) => _press(false),
    child: AnimatedScale(
      scale: _pressed && !AppMotion.reduced(context) ? 0.98 : 1,
      duration: AppMotion.duration(context, AppMotion.quick),
      curve: AppMotion.curve,
      child: Material(
        color: widget.color ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(widget.radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: widget.onTap, child: widget.child),
      ),
    ),
  );
}

class AppBadge extends StatelessWidget {
  const AppBadge(this.label, {super.key, this.color, this.icon});
  final String label;
  final Color? color;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final tone = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: tone),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: tone),
            ),
          ),
        ],
      ),
    );
  }
}

class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.firstName,
    required this.lastName,
    this.size = 48,
    this.heroTag,
  });
  final String firstName;
  final String lastName;
  final double size;
  final Object? heroTag;
  @override
  Widget build(BuildContext context) {
    final initials = [firstName, lastName]
        .where((n) => n.trim().isNotEmpty)
        .map((n) => n.trim().characters.first)
        .join()
        .toUpperCase();
    final colors = Theme.of(context).colorScheme;
    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(size * 0.34),
        border: Border.all(color: colors.primary.withValues(alpha: 0.1)),
      ),
      alignment: Alignment.center,
      child: Text(
        initials.isEmpty ? '?' : initials,
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          fontSize: size * 0.33,
          fontWeight: FontWeight.w700,
          color: colors.onPrimaryContainer,
        ),
      ),
    );
    return heroTag != null && !AppMotion.reduced(context)
        ? Hero(
            tag: heroTag!,
            child: Material(type: MaterialType.transparency, child: avatar),
          )
        : avatar;
  }
}

class AppScoreRing extends StatelessWidget {
  const AppScoreRing({
    super.key,
    required this.score,
    this.size = 148,
    this.onDark = false,
  });
  final int score;
  final double size;
  final bool onDark;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tone = onDark ? const Color(0xFFD9C7FF) : colors.primary;
    return Semantics(
      label: 'Жалпы балл: $score',
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: score.toDouble()),
        duration: AppMotion.duration(context, AppMotion.entrance),
        curve: AppMotion.curve,
        builder: (context, value, _) => SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RingPainter(
              value / 100,
              tone,
              onDark
                  ? Colors.white.withValues(alpha: 0.13)
                  : colors.outlineVariant,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      child: Text(
                        '${value.round()}',
                        style: Theme.of(context).textTheme.displayLarge
                            ?.copyWith(
                              color: onDark ? Colors.white : colors.onSurface,
                              fontSize: size * 0.32,
                            ),
                      ),
                    ),
                    Text(
                      '/ 100',
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        fontSize: 12,
                        color: onDark
                            ? const Color(0xFFDFD3F5)
                            : colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.value, this.color, this.track);
  final double value;
  final Color color;
  final Color track;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(6);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2,
      false,
      paint..color = track,
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * value.clamp(0, 1),
      false,
      paint..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      value != old.value || color != old.color || track != old.track;
}

class SkillProgress extends StatelessWidget {
  const SkillProgress({super.key, required this.indicator, this.subtitle});
  final StudentIndicator indicator;
  final String? subtitle;
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).brightness == Brightness.dark
        ? Theme.of(context).colorScheme.primary
        : CategoryVisuals.color(CategoryVisuals.category(indicator.type));
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                CategoryVisuals.skillIcon(indicator.type),
                size: 20,
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  indicator.name,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${indicator.value} / 100',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: indicator.value / 100),
            duration: AppMotion.duration(context, AppMotion.entrance),
            curve: AppMotion.curve,
            builder: (_, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 7,
              color: color,
              backgroundColor: color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(8),
              semanticsLabel: indicator.name,
              semanticsValue: '${indicator.value}%',
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AppDetails extends StatelessWidget {
  const AppDetails({
    super.key,
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
  });
  final String title;
  final Widget child;
  final bool initiallyExpanded;
  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: Text(title, style: Theme.of(context).textTheme.titleSmall),
    initiallyExpanded: initiallyExpanded,
    expansionAnimationStyle: AnimationStyle(
      duration: AppMotion.duration(context),
      curve: AppMotion.curve,
    ),
    children: [Align(alignment: Alignment.centerLeft, child: child)],
  );
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => AppReveal(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(
              icon,
              size: 38,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 24), action!],
        ],
      ),
    ),
  );
}

/// Стабильная геометрия загрузки, без бесконечного shimmer.
class AppSkeleton extends StatelessWidget {
  const AppSkeleton({super.key, this.label = 'Деректер жүктелуде'});
  final String label;
  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    liveRegion: true,
    excludeSemantics: true,
    child: AppPage(
      children: [
        const SizedBox(height: 8),
        _bone(context, 32, width: 180),
        const SizedBox(height: 24),
        _bone(context, 200),
        const SizedBox(height: 28),
        for (var i = 0; i < 3; i++) ...[
          _bone(context, 80),
          const SizedBox(height: 14),
        ],
      ],
    ),
  );
  Widget _bone(BuildContext context, double height, {double? width}) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.outlineVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
    ),
  );
}

class AppButtonContent extends StatelessWidget {
  const AppButtonContent({
    super.key,
    required this.busy,
    required this.label,
    required this.busyLabel,
  });
  final bool busy;
  final String label;
  final String busyLabel;
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: AppMotion.duration(context, AppMotion.quick),
    child: Row(
      key: ValueKey(busy),
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (busy) ...[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Text(busy ? busyLabel : label, textAlign: TextAlign.center),
        ),
      ],
    ),
  );
}
