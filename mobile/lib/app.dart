import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';
import 'theme/owanbe_theme.dart';

class OwanbeApp extends ConsumerWidget {
  const OwanbeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      title: 'Owanbe',
      theme: owanbeTheme,
      routerConfig: router,
    );
  }
}
