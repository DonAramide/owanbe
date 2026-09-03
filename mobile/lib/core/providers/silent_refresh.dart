import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_notifier.dart';
import '../../auth/auth_session.dart';

/// Subscribe to a live tick without making it a rebuild dependency.
///
/// Riverpod treats a *watched* dependency change as a **reload** (loading UI).
/// [invalidateSelf] is a **refresh** (previous data stays visible).
void refreshOnAsyncTick(Ref ref, ProviderListenable<AsyncValue<dynamic>> tick) {
  ref.listen<AsyncValue<dynamic>>(tick, (previous, next) {
    if (!next.hasValue) return;
    final prevTick = previous?.valueOrNull;
    final nextTick = next.valueOrNull;
    if (nextTick == null) return;
    // First emitted tick is subscription, not a later poll.
    if (prevTick == null) return;
    if (prevTick == nextTick) return;
    ref.invalidateSelf();
  });
}

/// Keep an aggregator provider alive to [source] without reload-on-watch.
/// Initial load is ignored; later data replacements refresh in place.
void refreshWhenDataChanges<T>(
  Ref ref,
  ProviderListenable<AsyncValue<T>> source,
) {
  ref.listen<AsyncValue<T>>(source, (previous, next) {
    if (next.isLoading) return;
    final nextData = next.valueOrNull;
    if (nextData == null) return;
    if (previous == null || previous.isLoading) return;
    ref.invalidateSelf();
  });
}

extension AsyncValueUiStable<T> on AsyncValue<T> {
  /// Background refresh/reload must not replace an already-visible screen.
  R whenStable<R>({
    required R Function(T data) data,
    required R Function(Object error, StackTrace stackTrace) error,
    required R Function() loading,
  }) {
    return when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      data: data,
      error: error,
      loading: loading,
    );
  }
}

extension WatchSignedInUser on Ref {
  /// Sign-in/out only — not JWT object replacement or token rotation.
  AuthSession? watchSignedInUser() {
    watch(authSessionProvider.select((s) => s?.userId));
    return read(authSessionProvider);
  }
}
