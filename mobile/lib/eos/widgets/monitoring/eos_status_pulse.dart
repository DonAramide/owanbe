import 'package:flutter/material.dart';

class EosStatusPulse extends StatefulWidget {
  const EosStatusPulse({super.key, required this.color, this.size = 8});

  final Color color;
  final double size;

  @override
  State<EosStatusPulse> createState() => _EosStatusPulseState();
}

class _EosStatusPulseState extends State<EosStatusPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
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
      builder: (context, child) {
        final scale = 1 + (_controller.value * 0.6);
        final opacity = 1 - _controller.value;
        return SizedBox(
          width: widget.size * 2,
          height: widget.size * 2,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: scale,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: opacity * 0.35),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
              ),
            ],
          ),
        );
      },
    );
  }
}
