import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_error_states.dart';

class AdminAsyncBody<T> extends StatelessWidget {
  const AdminAsyncBody({
    super.key,
    required this.value,
    required this.builder,
    this.onRetry,
    this.onSignIn,
    this.loading,
    this.empty,
    this.isEmpty,
    this.skeletonCount = 3,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;
  final VoidCallback? onSignIn;
  final Widget? loading;
  final Widget? empty;
  final bool Function(T data)? isEmpty;
  final int skeletonCount;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => loading ?? AdminLoadingSkeleton(cardCount: skeletonCount),
      error: (error, _) => AdminErrorState(
        error: error,
        onRetry: onRetry,
        onSignIn: onSignIn,
      ),
      data: (data) {
        if (isEmpty != null && isEmpty!(data)) {
          return empty ?? const EmptyStateCard(title: 'No data yet');
        }
        return builder(data);
      },
    );
  }
}
