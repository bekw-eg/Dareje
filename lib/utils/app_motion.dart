import 'package:flutter/material.dart';

abstract final class AppMotion {
  static const quick = Duration(milliseconds: 180);
  static const standard = Duration(milliseconds: 280);
  static const entrance = Duration(milliseconds: 350);
  static const curve = Curves.easeOutCubic;
  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.accessibleNavigationOf(context);
  static Duration duration(BuildContext context, [Duration value = standard]) =>
      reduced(context) ? Duration.zero : value;
  static Route<T> route<T>(WidgetBuilder builder) =>
      MaterialPageRoute<T>(builder: builder);
}

class AppPageTransitions extends PageTransitionsBuilder {
  const AppPageTransitions();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AppMotion.reduced(context)) return child;
    final curved = animation.drive(CurveTween(curve: AppMotion.curve));
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: curved.drive(
          Tween(begin: const Offset(0.035, 0.02), end: Offset.zero),
        ),
        child: child,
      ),
    );
  }
}
