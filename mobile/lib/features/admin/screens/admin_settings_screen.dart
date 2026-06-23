import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../../../auth/auth_notifier.dart';
import '../finance/admin_finance_providers.dart';
import '../finance/finance_status_chip.dart';
import '../widgets/admin_page_layout.dart';
import 'admin_event_config_screen.dart';

class AdminSettingsScreen extends ConsumerWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final financeState = ref.watch(financeStateProvider);

    return AdminPageLayout(
      title: 'Settings',
      subtitle: 'Platform controls and environment',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EosSurfaceCard(
            elevated: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Finance controls', style: context.eosText.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                SizedBox(height: context.eos.spacing.md),
                financeState.when(
                  data: (state) => Row(
                    children: [
                      FinanceStatusChip(label: state),
                      SizedBox(width: context.eos.spacing.md),
                      DropdownButton<String>(
                        value: state,
                        items: const [
                          DropdownMenuItem(value: 'normal', child: Text('NORMAL')),
                          DropdownMenuItem(value: 'restricted', child: Text('RESTRICTED')),
                          DropdownMenuItem(value: 'frozen', child: Text('FROZEN')),
                        ],
                        onChanged: (v) async {
                          if (v == null) return;
                          await ref.read(adminFinanceApiProvider).setFinanceState(v);
                          ref.invalidate(financeStateProvider);
                        },
                      ),
                    ],
                  ),
                  loading: () => const CircularProgressIndicator(),
                  error: (_, _) => Text('Could not load finance state', style: context.eosText.bodyMedium),
                ),
              ],
            ),
          ),
          SizedBox(height: context.eos.spacing.lg),
          EosSurfaceCard(
            elevated: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Event configuration', style: context.eosText.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                SizedBox(height: context.eos.spacing.sm),
                Text('Categories, tags, templates, and budget defaults for organizers.',
                    style: context.eosText.bodyMedium),
                SizedBox(height: context.eos.spacing.md),
                Wrap(
                  spacing: context.eos.spacing.sm,
                  runSpacing: context.eos.spacing.sm,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AdminEventCategoriesScreen()),
                      ),
                      child: const Text('Event categories'),
                    ),
                    OutlinedButton(onPressed: null, child: const Text('Event tags')),
                    OutlinedButton(onPressed: null, child: const Text('Templates')),
                    OutlinedButton(onPressed: null, child: const Text('Vendor categories')),
                    OutlinedButton(onPressed: null, child: const Text('Budget templates')),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: context.eos.spacing.lg),
          EosSurfaceCard(
            elevated: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Environment', style: context.eosText.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                SizedBox(height: context.eos.spacing.sm),
                Text('Development · localhost API', style: context.eosText.bodyMedium),
              ],
            ),
          ),
          SizedBox(height: context.eos.spacing.lg),
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(authSessionProvider.notifier).signOut();
              if (context.mounted) context.go('/');
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
