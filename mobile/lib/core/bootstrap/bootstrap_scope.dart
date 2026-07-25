import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../identity/workspace_sync.dart';
import 'app_bootstrap.dart';

/// Mounts once at app root — starts boot manager and workspace sync listener.
class BootstrapScope extends ConsumerStatefulWidget {
  const BootstrapScope({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BootstrapScope> createState() => _BootstrapScopeState();
}

class _BootstrapScopeState extends ConsumerState<BootstrapScope> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(appBootstrapProvider.notifier).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Activate workspace←identity sync (decoupled from identity load).
    ref.watch(workspaceIdentitySyncProvider);
    return widget.child;
  }
}
