import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/theme_mode_provider.dart';
import '../../extensions/eos_context.dart';
import '../../tokens/eos_colors.dart';
import '../cards/eos_surface_card.dart';

/// Appearance picker: system, light, or dark.
class EosThemeModeSection extends ConsumerWidget {
  const EosThemeModeSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);

    return EosSurfaceCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Appearance', style: context.eosText.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          SizedBox(height: context.eos.spacing.xs),
          Text('Choose light, dark, or match your device.', style: context.eosText.bodySmall),
          SizedBox(height: context.eos.spacing.md),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('System'),
                icon: Icon(Icons.brightness_auto_outlined, size: 18),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('Light'),
                icon: Icon(Icons.light_mode_outlined, size: 18),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('Dark'),
                icon: Icon(Icons.dark_mode_outlined, size: 18),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (selection) {
              ref.read(themeModeProvider.notifier).setMode(selection.first);
            },
          ),
          if (mode == ThemeMode.dark) ...[
            SizedBox(height: context.eos.spacing.sm),
            Row(
              children: [
                Icon(Icons.nights_stay_outlined, size: 18, color: EosColors.champagne),
                SizedBox(width: context.eos.spacing.xs),
                Text('Dark mode is on', style: context.eosText.labelSmall),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
