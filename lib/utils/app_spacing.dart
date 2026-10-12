import 'package:flutter/material.dart';

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const section = 28.0;
  static const radius = 24.0;
  static const contentWidth = 760.0;
  static EdgeInsets page(BuildContext context) => EdgeInsets.fromLTRB(
    MediaQuery.sizeOf(context).width < 360 ? lg : xl,
    lg,
    MediaQuery.sizeOf(context).width < 360 ? lg : xl,
    xxl,
  );
}
