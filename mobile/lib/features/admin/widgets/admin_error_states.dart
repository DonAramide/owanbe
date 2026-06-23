import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import 'admin_api_error.dart';

class ErrorStateCard extends StatelessWidget {
  const ErrorStateCard({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.error_outline,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _AdminStateCard(
      icon: icon,
      iconColor: EosColors.critical,
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}

class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return _AdminStateCard(
      icon: icon,
      iconColor: context.eosColors.onSurfaceVariant,
      title: title,
      message: message ?? 'Nothing to show yet.',
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}

class SessionExpiredCard extends StatelessWidget {
  const SessionExpiredCard({super.key, this.onSignIn});

  final VoidCallback? onSignIn;

  @override
  Widget build(BuildContext context) {
    return _AdminStateCard(
      icon: Icons.lock_clock_outlined,
      iconColor: EosColors.warning,
      title: 'Session expired',
      message: 'Sign in again to continue managing the platform.',
      actionLabel: 'Sign in',
      onAction: onSignIn ?? () => context.go('/staff/login?role=admin'),
    );
  }
}

class UnauthorizedCard extends StatelessWidget {
  const UnauthorizedCard({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return _AdminStateCard(
      icon: Icons.shield_outlined,
      iconColor: EosColors.critical,
      title: 'Access denied',
      message: 'Your account does not have permission to view this resource.',
      actionLabel: 'Back to dashboard',
      onAction: onBack ?? () => context.go('/admin'),
    );
  }
}

class AdminErrorState extends StatelessWidget {
  const AdminErrorState({
    super.key,
    required this.error,
    this.onRetry,
    this.onSignIn,
  });

  final Object error;
  final VoidCallback? onRetry;
  final VoidCallback? onSignIn;

  @override
  Widget build(BuildContext context) {
    return switch (classifyAdminError(error)) {
      AdminErrorKind.sessionExpired => SessionExpiredCard(onSignIn: onSignIn),
      AdminErrorKind.unauthorized => UnauthorizedCard(onBack: onRetry),
      AdminErrorKind.generic => ErrorStateCard(
          title: 'Could not load data',
          message: friendlyAdminErrorMessage(error),
          actionLabel: onRetry != null ? 'Try again' : null,
          onAction: onRetry,
        ),
    };
  }
}

class AdminLoadingSkeleton extends StatelessWidget {
  const AdminLoadingSkeleton({super.key, this.cardCount = 3});

  final int cardCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: EosSpacing.lg,
          runSpacing: EosSpacing.lg,
          children: [
            for (var i = 0; i < cardCount; i++)
              SizedBox(
                width: 220,
                height: 108,
                child: _ShimmerBox(borderRadius: 16),
              ),
          ],
        ),
        SizedBox(height: EosSpacing.lg),
        _ShimmerBox(height: 280, borderRadius: 16),
      ],
    );
  }
}

class _AdminStateCard extends StatelessWidget {
  const _AdminStateCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: EosSurfaceCard(
          elevated: true,
          padding: const EdgeInsets.all(EosSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: iconColor),
              SizedBox(height: context.eos.spacing.md),
              Text(title, style: context.eosText.titleMedium, textAlign: TextAlign.center),
              SizedBox(height: context.eos.spacing.sm),
              Text(
                message,
                style: context.eosText.bodyMedium?.copyWith(color: context.eosColors.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              if (actionLabel != null && onAction != null) ...[
                SizedBox(height: context.eos.spacing.lg),
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({this.height = 48, this.borderRadius = 12});

  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: context.eosColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}
