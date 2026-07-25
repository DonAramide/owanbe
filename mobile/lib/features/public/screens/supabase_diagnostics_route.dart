import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/bootstrap/app_boot_state.dart';
import '../../../core/bootstrap/app_bootstrap.dart';
import '../../../supabase/supabase_diagnostic.dart';
import 'supabase_diagnostics_screen.dart';

/// Router-mounted diagnostics — shown when startup connectivity/config checks fail.
class SupabaseDiagnosticsScreen extends ConsumerStatefulWidget {
  const SupabaseDiagnosticsScreen({super.key});

  @override
  ConsumerState<SupabaseDiagnosticsScreen> createState() =>
      _SupabaseDiagnosticsScreenState();
}

class _SupabaseDiagnosticsScreenState
    extends ConsumerState<SupabaseDiagnosticsScreen> {
  bool _retrying = false;

  @override
  Widget build(BuildContext context) {
    final boot = ref.watch(appBootstrapProvider);

    ref.listen(appBootstrapProvider, (previous, next) {
      if (next.phase == AppBootPhase.ready &&
          next.destination != null &&
          next.destination != '/diagnostics/supabase') {
        if (context.mounted) context.go(next.destination!);
      }
    });

    final diagnostic = _diagnosticFromBoot(boot) ??
        ref.read(appBootstrapProvider.notifier).lastDiagnostic ??
        const SupabaseDiagnostic(
          kind: SupabaseFailureKind.unknown,
          title: 'Unable to reach the sign-in service',
          message: 'Connectivity diagnostics are unavailable. Retry or restart the app.',
        );

    return SupabaseDiagnosticsBody(
      diagnostic: diagnostic,
      retrying: _retrying,
      onRetry: () async {
        setState(() => _retrying = true);
        try {
          await ref.read(appBootstrapProvider.notifier).retryConnectivity();
        } finally {
          if (mounted) setState(() => _retrying = false);
        }
      },
      onContinueToLogin: diagnostic.isConfigurationError
          ? null
          : () async {
              setState(() => _retrying = true);
              try {
                await ref.read(appBootstrapProvider.notifier).continueToLogin();
              } finally {
                if (mounted) setState(() => _retrying = false);
              }
            },
    );
  }

  SupabaseDiagnostic? _diagnosticFromBoot(AppBootSnapshot boot) {
    if (boot.connectivityKind == null && boot.connectivityMessage == null) {
      return null;
    }
    final kind = SupabaseFailureKind.values.firstWhere(
      (k) => k.name == boot.connectivityKind,
      orElse: () => SupabaseFailureKind.unknown,
    );
    return SupabaseDiagnostic(
      kind: kind,
      title: boot.connectivityTitle ?? 'Connectivity issue',
      message: boot.connectivityMessage ?? boot.errorMessage ?? 'Unknown failure',
      configuredUrl: boot.configuredUrl,
      technicalDetail: boot.technicalDetail,
    );
  }
}
