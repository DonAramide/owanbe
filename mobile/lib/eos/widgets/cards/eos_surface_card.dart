import 'package:flutter/material.dart';

import '../../extensions/eos_context.dart';
import '../../tokens/eos_radius.dart';

/// Base elevated surface for EOS cards — soft border, optional accent strip.
class EosSurfaceCard extends StatelessWidget {
  const EosSurfaceCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.accentColor,
    this.elevated = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final Color? accentColor;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final tokens = context.eos;
    final scheme = context.eosColors;

    final paddedChild = Padding(
      padding: padding ?? tokens.spacing.card,
      child: child,
    );

    final body = accentColor != null
        ? IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: accentColor),
                Expanded(child: paddedChild),
              ],
            ),
          )
        : paddedChild;

    Widget content = Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: EosRadius.card,
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.85)),
        boxShadow: elevated ? tokens.shadowElevated : tokens.shadowSoft,
      ),
      child: ClipRRect(
        borderRadius: EosRadius.card,
        child: body,
      ),
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, child: content),
      );
    }

    return content;
  }
}
