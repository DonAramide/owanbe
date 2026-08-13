import 'package:flutter/material.dart';

import '../tokens/eos_breakpoints.dart';
import '../tokens/eos_spacing.dart';

/// Adaptive window class derived from viewport width.
enum EosLayoutSize {
  /// Phone — compact (0–599).
  mobile,

  /// Tablet — medium (600–1023).
  tablet,

  /// Desktop — expanded (1024–1439).
  desktop,

  /// Ultra-wide density (1440+).
  wide,
}

/// Compact adaptive window taxonomy used by presentation chrome.
enum EosAdaptiveWindow {
  compact,
  medium,
  expanded,
}

/// Centralized adaptive layout resolver.
///
/// Prefer this over per-screen MediaQuery width checks.
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
    if (w >= EosBreakpoints.phone) return EosLayoutSize.tablet;
    return EosLayoutSize.mobile;
  }

  static EosAdaptiveWindow windowOf(BuildContext context) {
    return switch (layoutSizeOf(context)) {
      EosLayoutSize.mobile => EosAdaptiveWindow.compact,
      EosLayoutSize.tablet => EosAdaptiveWindow.medium,
      EosLayoutSize.desktop || EosLayoutSize.wide => EosAdaptiveWindow.expanded,
    };
  }

  /// Phone / compact viewport.
  static bool isCompact(BuildContext context) =>
      layoutSizeOf(context) == EosLayoutSize.mobile;

  /// Tablet / medium viewport.
  static bool isMedium(BuildContext context) =>
      layoutSizeOf(context) == EosLayoutSize.tablet;

  /// Desktop or wider.
  static bool isExpanded(BuildContext context) =>
      windowOf(context) == EosAdaptiveWindow.expanded;

  /// Legacy: true on phone (compact). Prefer [isCompact].
  static bool isMobile(BuildContext context) => isCompact(context);

  /// True on tablet and wider (not phone).
  static bool isTabletOrWider(BuildContext context) => !isCompact(context);

  /// Grid / form column count by window.
  static int columnsFor(BuildContext context) => switch (layoutSizeOf(context)) {
        EosLayoutSize.mobile => 1,
        EosLayoutSize.tablet => 2,
        EosLayoutSize.desktop => 3,
        EosLayoutSize.wide => 4,
      };

  /// Form field columns (never more than 2 on tablet).
  static int formColumnsFor(BuildContext context) => switch (windowOf(context)) {
        EosAdaptiveWindow.compact => 1,
        EosAdaptiveWindow.medium => 2,
        EosAdaptiveWindow.expanded => 2,
      };

  /// Whether dense data tables should render as cards/lists.
  static bool useCardDataPresentation(BuildContext context) => isCompact(context);

  /// Adaptive page padding — tighter on phone for usable content width.
  static EdgeInsets pagePaddingOf(BuildContext context) => switch (windowOf(context)) {
        EosAdaptiveWindow.compact => const EdgeInsets.symmetric(
            horizontal: EosSpacing.md,
            vertical: EosSpacing.md,
          ),
        EosAdaptiveWindow.medium => EosSpacing.pagePadding,
        EosAdaptiveWindow.expanded => EosSpacing.pagePadding,
      };

  /// Preferred KPI / metric card width for Wrap layouts.
  static double kpiCardWidthOf(BuildContext context, {double maxWidth = 0}) {
    final width = maxWidth > 0 ? maxWidth : MediaQuery.sizeOf(context).width;
    final pad = pagePaddingOf(context).horizontal;
    final available = (width - pad).clamp(0.0, double.infinity);
    return switch (windowOf(context)) {
      EosAdaptiveWindow.compact => available,
      EosAdaptiveWindow.medium => (available - EosSpacing.md) / 2,
      EosAdaptiveWindow.expanded => 200,
    };
  }

  /// Headline scale factor — prevents oversized titles crushing chrome on phone.
  static double textScaleFactorOf(BuildContext context) => switch (windowOf(context)) {
        EosAdaptiveWindow.compact => 0.92,
        EosAdaptiveWindow.medium => 0.96,
        EosAdaptiveWindow.expanded => 1.0,
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
