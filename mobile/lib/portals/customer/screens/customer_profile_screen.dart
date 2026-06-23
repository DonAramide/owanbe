import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/auth_notifier.dart';
import '../../../eos/eos.dart';
import '../widgets/section_header.dart';

class CustomerProfileScreen extends ConsumerWidget {
  const CustomerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);

    return ColoredBox(
      color: EosColors.canvas,
      child: ListView(
        padding: EdgeInsets.all(context.eos.spacing.lg),
        children: [
          const SectionHeader(
            title: 'More',
            subtitle: 'Account, tickets, and settings.',
          ),
          EosSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session?.displayName ?? 'Guest', style: context.eosText.titleMedium),
                if (session?.email != null) ...[
                  SizedBox(height: context.eos.spacing.xxs),
                  Text(session!.email!, style: context.eosText.bodySmall),
                ],
              ],
            ),
          ),
          SizedBox(height: context.eos.spacing.md),
          ListTile(
            leading: const Icon(Icons.confirmation_number_outlined),
            title: const Text('My tickets'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/attendee'),
          ),
          ListTile(
            leading: const Icon(Icons.explore_outlined),
            title: const Text('Discover events'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/events'),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: () async {
              await ref.read(authSessionProvider.notifier).signOut();
              if (context.mounted) context.go('/');
            },
          ),
        ],
      ),
    );
  }
}
