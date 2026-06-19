import 'package:flutter/material.dart';

import '../tokens/eos_breakpoints.dart';

enum EosLayoutSize { mobile, tablet, desktop, wide }

class EosResponsive extends StatelessWidget {
  const EosResponsive({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
    this.wide,
  });

  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;
  final Widget? wide;

  static EosLayoutSize layoutSizeOf(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= EosBreakpoints.wide) return EosLayoutSize.wide;
    if (w >= EosBreakpoints.desktop) return EosLayoutSize.desktop;
    if (w >= EosBreakpoints.tablet) return EosLayoutSize.tablet;
    return EosLayoutSize.mobile;
  }

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < EosBreakpoints.tablet;

  static bool isTabletOrWider(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= EosBreakpoints.tablet;

  static int columnsFor(BuildContext context) => switch (layoutSizeOf(context)) {
        EosLayoutSize.mobile => 1,
        EosLayoutSize.tablet => 2,
        EosLayoutSize.desktop => 3,
        EosLayoutSize.wide => 4,
      };

  @override
  Widget build(BuildContext context) {
    return switch (layoutSizeOf(context)) {
      EosLayoutSize.wide => wide ?? desktop ?? tablet ?? mobile,
      EosLayoutSize.desktop => desktop ?? tablet ?? mobile,
      EosLayoutSize.tablet => tablet ?? mobile,
      EosLayoutSize.mobile => mobile,
    };
  }
}
