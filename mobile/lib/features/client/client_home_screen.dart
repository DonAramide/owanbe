import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/auth_notifier.dart';
import '../disputes/client_disputes_screen.dart';

class ClientHomeScreen extends ConsumerWidget {
  const ClientHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Client Disputes'),
        actions: [
          Text(session?.displayName ?? ''),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authSessionProvider.notifier).signOut(),
          ),
        ],
      ),
      body: const ClientDisputesScreen(),
    );
  }
}
