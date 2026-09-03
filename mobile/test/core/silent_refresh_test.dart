import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:owambe/core/providers/silent_refresh.dart';

void main() {
  test('refreshOnAsyncTick keeps previous value (refresh, not reload)', () async {
    final tick = StreamProvider<int>((ref) async* {
      yield 0;
      await Future<void>.delayed(const Duration(milliseconds: 40));
      yield 1;
    });

    var builds = 0;
    final data = FutureProvider<String>((ref) async {
      builds += 1;
      refreshOnAsyncTick(ref, tick);
      return 'v$builds';
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(await container.read(data.future), 'v1');
    expect(container.read(data).hasValue, isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 80));
    final afterTick = container.read(data);
    expect(afterTick.hasValue, isTrue, reason: 'tick must not drop existing data');
    expect(builds, greaterThan(1), reason: 'later ticks must refetch');
    expect(afterTick.valueOrNull, anyOf('v1', 'v2'));
  });

  test('whenStable skips loading when a previous value exists', () {
    final refreshing = const AsyncLoading<String>().copyWithPrevious(
      const AsyncData('kept'),
    );
    final shown = refreshing.whenStable(
      data: (v) => 'data:$v',
      error: (_, __) => 'error',
      loading: () => 'loading',
    );
    expect(shown, 'data:kept');
  });
}
