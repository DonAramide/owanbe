import 'package:flutter/material.dart';

import '../extensions/eos_context.dart';
import '../tokens/eos_spacing.dart';
import 'eos_responsive.dart';

/// Central adaptive presentation primitives.
///
/// Screens should compose these instead of inventing per-screen MediaQuery hacks.
abstract final class EosAdaptive {
  static EosAdaptiveWindow windowOf(BuildContext context) =>
      EosResponsive.windowOf(context);

  static bool isCompact(BuildContext context) => EosResponsive.isCompact(context);

  static bool isMedium(BuildContext context) => EosResponsive.isMedium(context);

  static bool isExpanded(BuildContext context) => EosResponsive.isExpanded(context);
}

/// Applies adaptive text scale for the subtree (presentation only).
class EosAdaptiveTextScale extends StatelessWidget {
  const EosAdaptiveTextScale({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final factor = EosResponsive.textScaleFactorOf(context);
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(
        textScaler: TextScaler.linear(mq.textScaler.scale(1) * factor),
      ),
      child: child,
    );
  }
}

/// Adaptive page padding wrapper.
class EosAdaptivePadding extends StatelessWidget {
  const EosAdaptivePadding({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? EosResponsive.pagePaddingOf(context),
      child: child,
    );
  }
}

/// Action / header bar that stacks on compact and stays horizontal on wider layouts.
///
/// Prevents one-character-per-line title crushing when actions compete for width.
class EosAdaptiveActionBar extends StatelessWidget {
  const EosAdaptiveActionBar({
    super.key,
    required this.leading,
    this.actions = const [],
    this.spacing,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  final Widget leading;
  final List<Widget> actions;
  final double? spacing;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final gap = spacing ?? context.eos.spacing.sm;
    if (actions.isEmpty) return leading;

    if (EosAdaptive.isCompact(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          leading,
          SizedBox(height: gap),
          Wrap(
            spacing: gap,
            runSpacing: gap,
            alignment: WrapAlignment.start,
            children: [
              for (final action in actions)
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: action,
                ),
            ],
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Expanded(child: leading),
        SizedBox(width: gap),
        Flexible(
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            alignment: WrapAlignment.end,
            children: actions,
          ),
        ),
      ],
    );
  }
}

/// Responsive grid that picks column count from [EosResponsive.columnsFor].
class EosAdaptiveGrid extends StatelessWidget {
  const EosAdaptiveGrid({
    super.key,
    required this.children,
    this.spacing,
    this.runSpacing,
    this.columns,
    this.childAspectRatio,
    this.shrinkWrap = true,
    this.physics = const NeverScrollableScrollPhysics(),
  });

  final List<Widget> children;
  final double? spacing;
  final double? runSpacing;
  final int? columns;
  final double? childAspectRatio;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    final cols = columns ?? EosResponsive.columnsFor(context);
    final gap = spacing ?? context.eos.spacing.md;
    final runGap = runSpacing ?? gap;

    if (cols <= 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: runGap),
            children[i],
          ],
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final itemWidth = (width - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: runGap,
          children: [
            for (final child in children)
              SizedBox(
                width: itemWidth,
                child: childAspectRatio == null
                    ? child
                    : AspectRatio(aspectRatio: childAspectRatio!, child: child),
              ),
          ],
        );
      },
    );
  }
}

/// Form field layout — 1 column on phone, up to 2 on tablet/desktop.
class EosAdaptiveFormLayout extends StatelessWidget {
  const EosAdaptiveFormLayout({
    super.key,
    required this.children,
    this.spacing,
    this.runSpacing,
  });

  final List<Widget> children;
  final double? spacing;
  final double? runSpacing;

  @override
  Widget build(BuildContext context) {
    final cols = EosResponsive.formColumnsFor(context);
    final gap = spacing ?? context.eos.spacing.md;
    final runGap = runSpacing ?? context.eos.spacing.md;

    if (cols <= 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: runGap),
            children[i],
          ],
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: runGap,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

/// KPI / metric card strip — full-width cards on phone, multi-column wrap elsewhere.
class EosAdaptiveKpiGrid extends StatelessWidget {
  const EosAdaptiveKpiGrid({
    super.key,
    required this.children,
    this.spacing,
    this.runSpacing,
    this.minCardWidth = 160,
  });

  final List<Widget> children;
  final double? spacing;
  final double? runSpacing;
  final double minCardWidth;

  @override
  Widget build(BuildContext context) {
    final gap = spacing ?? context.eos.spacing.md;
    final runGap = runSpacing ?? gap;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final cardWidth = EosAdaptive.isCompact(context)
            ? maxW
            : EosAdaptive.isMedium(context)
                ? (maxW - gap) / 2
                : (maxW / (maxW / minCardWidth).floor().clamp(1, 6)).clamp(minCardWidth, 260.0);

        // Expanded: prefer ~200–260 cards that wrap naturally.
        final width = EosAdaptive.isExpanded(context)
            ? (maxW >= 900 ? 200.0 : (maxW - gap) / 2)
            : cardWidth;

        return Wrap(
          spacing: gap,
          runSpacing: runGap,
          children: [
            for (final child in children)
              SizedBox(width: width.isFinite ? width : maxW, child: child),
          ],
        );
      },
    );
  }
}

/// Full-width primary actions on compact; inline on wider layouts.
class EosAdaptiveButtonBar extends StatelessWidget {
  const EosAdaptiveButtonBar({
    super.key,
    required this.children,
    this.spacing,
    this.alignment = MainAxisAlignment.end,
  });

  final List<Widget> children;
  final double? spacing;
  final MainAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final gap = spacing ?? context.eos.spacing.sm;
    if (EosAdaptive.isCompact(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: gap),
            SizedBox(height: 48, child: children[i]),
          ],
        ],
      );
    }
    return Row(
      mainAxisAlignment: alignment,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          children[i],
        ],
      ],
    );
  }
}

/// Shared chrome for workspace top bars — rearranges by window class.
class EosAdaptiveTopBarChrome extends StatelessWidget {
  const EosAdaptiveTopBarChrome({
    super.key,
    this.leading,
    this.title,
    this.search,
    this.primaryActions = const [],
    this.iconActions = const [],
    this.trailing,
  });

  /// Optional brand / logo.
  final Widget? leading;

  /// Optional title widget (expanded layouts).
  final Widget? title;

  /// Search field — full width on compact second row when provided.
  final Widget? search;

  /// Labeled buttons shown inline on expanded; overflow menu on compact.
  final List<EosAdaptiveChromeAction> primaryActions;

  /// Always icon buttons.
  final List<Widget> iconActions;

  /// Workspace switcher / profile cluster.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final compact = EosAdaptive.isCompact(context);
    final pad = EdgeInsets.symmetric(
      horizontal: EosAdaptive.isExpanded(context) ? EosSpacing.lg : EosSpacing.md,
      vertical: EosSpacing.sm,
    );

    return Material(
      color: context.eosColors.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.eosColors.outlineVariant)),
        ),
        child: Padding(
          padding: pad,
          child: compact ? _compact(context) : _wide(context),
        ),
      ),
    );
  }

  Widget _wide(BuildContext context) {
    return Row(
      children: [
        if (leading != null) ...[
          leading!,
          SizedBox(width: context.eos.spacing.sm),
        ],
        if (title != null) ...[
          Flexible(child: title!),
          SizedBox(width: context.eos.spacing.sm),
        ],
        if (search != null) Expanded(child: search!),
        if (search == null && title == null) const Spacer(),
        SizedBox(width: context.eos.spacing.sm),
        for (final action in primaryActions) ...[
          action.buildExpanded(context),
          SizedBox(width: context.eos.spacing.sm),
        ],
        ...iconActions,
        if (trailing != null) trailing!,
      ],
    );
  }

  Widget _compact(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (leading != null) ...[
              leading!,
              SizedBox(width: context.eos.spacing.xs),
            ],
            if (title != null) Expanded(child: title!) else const Spacer(),
            if (primaryActions.isNotEmpty)
              PopupMenuButton<int>(
                tooltip: 'Actions',
                icon: const Icon(Icons.more_horiz),
                itemBuilder: (context) => [
                  for (var i = 0; i < primaryActions.length; i++)
                    PopupMenuItem(
                      value: i,
                      child: Row(
                        children: [
                          Icon(primaryActions[i].icon, size: 18),
                          const SizedBox(width: 10),
                          Text(primaryActions[i].label),
                        ],
                      ),
                    ),
                ],
                onSelected: (i) => primaryActions[i].onPressed(),
              ),
            ...iconActions,
            if (trailing != null) trailing!,
          ],
        ),
        if (search != null) ...[
          SizedBox(height: context.eos.spacing.xs),
          search!,
        ],
      ],
    );
  }
}

class EosAdaptiveChromeAction {
  const EosAdaptiveChromeAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool filled;

  Widget buildExpanded(BuildContext context) {
    if (filled) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}
