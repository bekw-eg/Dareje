import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_spacing.dart';
import 'app_widgets.dart';

class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.description,
    required this.child,
    this.showBackButton = false,
    this.canGoBack = true,
  });
  final String title;
  final String description;
  final Widget child;
  final bool showBackButton;
  final bool canGoBack;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: showBackButton
        ? AppBar(
            leading: IconButton(
              tooltip: 'Кіруге оралу',
              onPressed: canGoBack
                  ? () => Navigator.of(context).maybePop()
                  : null,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          )
        : null,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: AppSpacing.page(context),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: AppReveal(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: AppColors.heroGradient,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Icon(
                              Icons.stacked_line_chart_rounded,
                              color: Colors.white,
                              size: 25,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Dáreje',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      if (!showBackButton) ...[
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: AppColors.heroGradient,
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const AppBadge(
                                'СЕНІҢ ӨСУ КЕҢІСТІГІҢ',
                                color: Color(0xFFE6DAFF),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Жетістігіңді сақта.\nДеңгейіңді көтер.',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(color: Colors.white),
                              ),
                              const SizedBox(height: 24),
                              const Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  AppBadge(
                                    'Жетістіктер',
                                    color: Color(0xFFE6DAFF),
                                    icon: Icons.emoji_events_outlined,
                                  ),
                                  AppBadge(
                                    'Прогресс',
                                    color: Color(0xFFE6DAFF),
                                    icon: Icons.insights_outlined,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 28),
                      child,
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.devices_outlined,
                            size: 16,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Аккаунт осы құрылғыда сақталады',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
