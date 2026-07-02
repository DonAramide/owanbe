import 'package:flutter/material.dart';

import '../../../../eos/eos.dart';

enum EventLoadingVariant { workspace, module, list, card }

/// Shimmer skeleton loading for Event OS surfaces (Phase 42.4 / 42.6).
class EventLoadingSkeleton extends StatelessWidget {
  const EventLoadingSkeleton({super.key, this.variant = EventLoadingVariant.module});

  final EventLoadingVariant variant;

  @override
  Widget build(BuildContext context) {
    return _EventShimmerScope(
      child: switch (variant) {
        EventLoadingVariant.workspace => const _WorkspaceSkeleton(),
        EventLoadingVariant.module => const _ModuleSkeleton(),
        EventLoadingVariant.list => const _ListSkeleton(),
        EventLoadingVariant.card => const _CardSkeleton(),
      },
    );
  }
}

class _EventShimmerScope extends StatefulWidget {
  const _EventShimmerScope({required this.child});

  final Widget child;

  @override
  State<_EventShimmerScope> createState() => _EventShimmerScopeState();
}

class _EventShimmerScopeState extends State<_EventShimmerScope> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => _ShimmerData(
        opacity: 0.45 + (_controller.value * 0.35),
        child: child!,
      ),
      child: widget.child,
    );
  }
}

class _ShimmerData extends InheritedWidget {
  const _ShimmerData({required this.opacity, required super.child});

  final double opacity;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ShimmerData>()?.opacity ?? 0.55;

  @override
  bool updateShouldNotify(_ShimmerData oldWidget) => oldWidget.opacity != opacity;
}

class _WorkspaceSkeleton extends StatelessWidget {
  const _WorkspaceSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EosSpacing.pagePadding,
      children: [
        _Block(height: 140, radius: BorderRadius.circular(EosRadius.lg)),
        SizedBox(height: context.eos.spacing.lg),
        _Block(height: 20, width: 180),
        SizedBox(height: context.eos.spacing.sm),
        _Block(height: 120),
        SizedBox(height: context.eos.spacing.lg),
        _Block(height: 20, width: 140),
        SizedBox(height: context.eos.spacing.sm),
        Row(
          children: [
            Expanded(child: _Block(height: 88)),
            SizedBox(width: context.eos.spacing.sm),
            Expanded(child: _Block(height: 88)),
          ],
        ),
        SizedBox(height: context.eos.spacing.lg),
        for (var i = 0; i < 3; i++) ...[
          _Block(height: 72),
          SizedBox(height: context.eos.spacing.sm),
        ],
      ],
    );
  }
}

class _ModuleSkeleton extends StatelessWidget {
  const _ModuleSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EosSpacing.pagePadding,
      children: [
        _Block(height: 20, width: 200),
        SizedBox(height: context.eos.spacing.xs),
        _Block(height: 14, width: 260),
        SizedBox(height: context.eos.spacing.lg),
        _Block(height: 100),
        SizedBox(height: context.eos.spacing.lg),
        for (var i = 0; i < 4; i++) ...[
          _Block(height: 64),
          SizedBox(height: context.eos.spacing.sm),
        ],
      ],
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 5; i++) ...[
          _Block(height: 56),
          SizedBox(height: context.eos.spacing.sm),
        ],
      ],
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EosSpacing.pagePadding,
      child: _Block(height: 160),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.height, this.width, this.radius});

  final double height;
  final double? width;
  final BorderRadius? radius;

  @override
  Widget build(BuildContext context) {
    final opacity = _ShimmerData.of(context);
    return Container(
      height: height,
      width: width ?? double.infinity,
      decoration: BoxDecoration(
        color: context.eosColors.surfaceContainerHighest.withValues(alpha: opacity),
        borderRadius: radius ?? context.eos.radius.card,
      ),
    );
  }
}
