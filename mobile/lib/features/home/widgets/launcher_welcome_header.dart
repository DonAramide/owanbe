import 'package:flutter/material.dart';

import '../../../eos/eos.dart';

/// Calm launcher welcome — no workspace dashboards or event countdowns.
class LauncherWelcomeHeader extends StatelessWidget {
  const LauncherWelcomeHeader({
    super.key,
    required this.displayName,
    this.avatarUrl,
    this.notificationCount = 0,
    this.onNotificationsTap,
  });

  final String displayName;
  final String? avatarUrl;
  final int notificationCount;
  final VoidCallback? onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    final firstName = displayName.trim().isEmpty
        ? 'there'
        : displayName.trim().split(RegExp(r'\s+')).first;

    return Container(
      padding: EdgeInsets.all(context.eos.spacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [EosColors.plumDark, EosColors.plum, Color(0xFF5E2D7A)],
        ),
        borderRadius: EosRadius.card,
        boxShadow: context.eos.shadowElevated,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: EosColors.champagne,
                backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
                    ? NetworkImage(avatarUrl!)
                    : null,
                child: avatarUrl == null || avatarUrl!.isEmpty
                    ? Text(
                        firstName.isNotEmpty ? firstName[0].toUpperCase() : 'O',
                        style: context.eosText.headlineSmall?.copyWith(
                          color: EosColors.plumDark,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : null,
              ),
              SizedBox(width: context.eos.spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back, $firstName',
                      style: context.eosText.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: context.eos.spacing.xxs),
                    Text(
                      'This is your Owanbe Home.',
                      style: context.eosText.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                    SizedBox(height: context.eos.spacing.xs),
                    Text(
                      'What do you want to do today?',
                      style: context.eosText.bodySmall?.copyWith(
                        color: EosColors.champagne.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (onNotificationsTap != null)
                IconButton(
                  tooltip: 'Activity & notifications',
                  onPressed: onNotificationsTap,
                  icon: notificationCount > 0
                      ? Badge(
                          label: Text('$notificationCount'),
                          child: const Icon(Icons.notifications_outlined, color: Colors.white),
                        )
                      : const Icon(Icons.notifications_outlined, color: Colors.white70),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
