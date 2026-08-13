import 'package:flutter/material.dart';

import '../extensions/eos_context.dart';
import '../layout/eos_adaptive.dart';
import '../layout/eos_responsive.dart';
import '../tokens/eos_spacing.dart';

/// Standard page chrome: title, optional actions, padded body.
///
/// Adaptive: stacks title above actions on compact windows to prevent
/// one-character-per-line title crushing.
///
/// Body is placed in a bounded [Expanded] region (shell-safe). By default the
/// body scrolls via [SingleChildScrollView]. Set [bodyScrollable] to false when
/// the body manages its own scroll / uses [Expanded] (e.g. split panes).
class EosPageScaffold extends StatelessWidget {
  const EosPageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions,
    this.leading,
    this.floatingHeader,
    this.bodyScrollable = true,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget>? actions;
  final Widget? leading;
  final Widget? floatingHeader;

  /// When true (default), wraps [body] in a vertical [SingleChildScrollView].
  /// When false, [body] fills remaining height and must handle overflow itself.
  final bool bodyScrollable;

  @override
  Widget build(BuildContext context) {
    final pagePad = EosResponsive.pagePaddingOf(context);

    final header = Padding(
      padding: pagePad.copyWith(bottom: EosSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[
            leading!,
            SizedBox(height: context.eos.spacing.sm),
          ],
          EosAdaptiveActionBar(
            leading: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.eosText.headlineMedium,
                  softWrap: true,
                ),
                if (subtitle != null) ...[
                  SizedBox(height: context.eos.spacing.xs),
                  Text(
                    subtitle!,
                    style: context.eosText.bodyMedium,
                    softWrap: true,
                  ),
                ],
              ],
            ),
            actions: actions ?? const [],
          ),
          if (floatingHeader != null) ...[
            SizedBox(height: context.eos.spacing.md),
            floatingHeader!,
          ],
        ],
      ),
    );

    final paddedBody = Padding(
      padding: pagePad.copyWith(top: 0),
      child: body,
    );

    return EosAdaptiveTextScale(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Expanded(
            child: bodyScrollable
                ? SingleChildScrollView(child: paddedBody)
                : paddedBody,
          ),
        ],
      ),
    );
  }
}
