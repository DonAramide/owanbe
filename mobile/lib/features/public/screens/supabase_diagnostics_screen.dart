import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../supabase/supabase_diagnostic.dart';

/// Shown when Supabase config validation fails before the full app can boot.
class SupabaseBootstrapFailureApp extends StatelessWidget {
  const SupabaseBootstrapFailureApp({super.key, required this.diagnostic});

  final SupabaseDiagnostic diagnostic;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SupabaseDiagnosticsBody(
        diagnostic: diagnostic,
        onRetry: null,
      ),
    );
  }
}

/// Full-screen diagnostics for configuration / connectivity failures.
class SupabaseDiagnosticsBody extends StatelessWidget {
  const SupabaseDiagnosticsBody({
    super.key,
    required this.diagnostic,
    this.onRetry,
    this.onContinueToLogin,
    this.retrying = false,
  });

  final SupabaseDiagnostic diagnostic;
  final VoidCallback? onRetry;
  final VoidCallback? onContinueToLogin;
  final bool retrying;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF1A0F1C),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(
                diagnostic.isConfigurationError
                    ? Icons.settings_suggest_outlined
                    : Icons.wifi_off_rounded,
                size: 56,
                color: const Color(0xFFE8C9A0),
              ),
              const SizedBox(height: 20),
              Text(
                diagnostic.kindLabel,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                diagnostic.message,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.white70,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              if (diagnostic.configuredUrl != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Configured URL',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: const Color(0xFFE8C9A0),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                SelectableText(
                  diagnostic.configuredUrl!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white60,
                    fontFamily: 'monospace',
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              ...diagnostic.resolvedSteps.map(
                (step) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ASCII dash — avoid U+2022 (Flutter Web downloads Noto Sans Symbols for it).
                      const Text('- ', style: TextStyle(color: Colors.white54)),
                      Expanded(
                        child: Text(
                          step,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (kDebugMode && diagnostic.technicalDetail != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Technical detail',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.white38,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  diagnostic.technicalDetail!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white38,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
              const Spacer(),
              if (onRetry != null)
                FilledButton(
                  onPressed: retrying ? null : onRetry,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE8C9A0),
                    foregroundColor: const Color(0xFF1A0F1C),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: retrying
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Retry connection'),
                ),
              if (onContinueToLogin != null && !diagnostic.isConfigurationError) ...[
                const SizedBox(height: 10),
                TextButton(
                  onPressed: retrying ? null : onContinueToLogin,
                  child: const Text(
                    'Continue to sign-in',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
