import 'package:flutter/material.dart';

import '../../eos/eos.dart';

/// Circle avatar that falls back to initials when [NetworkImage] fails to load.
class ProfileNetworkAvatar extends StatelessWidget {
  const ProfileNetworkAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.radius = 28,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String name;
  final String? avatarUrl;
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    final bg = backgroundColor ?? EosColors.champagne.withValues(alpha: 0.35);
    final fg = foregroundColor ?? EosColors.plum;
    final url = avatarUrl?.trim();
    final hasUrl = url != null && url.isNotEmpty;

    Widget fallback() => CircleAvatar(
          radius: radius,
          backgroundColor: bg,
          child: Text(
            initial,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w800,
              fontSize: radius * 0.75,
            ),
          ),
        );

    if (!hasUrl) return fallback();

    return ClipOval(
      child: Image.network(
        url,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return SizedBox(
            width: radius * 2,
            height: radius * 2,
            child: Center(
              child: SizedBox(
                width: radius,
                height: radius,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
      ),
    );
  }
}
