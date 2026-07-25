import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'portal_deep_links.dart';

final pendingDeepLinkProvider = StateProvider<String?>((ref) => null);

final deepLinkListenerProvider = Provider<void>((ref) {
  final appLinks = AppLinks();

  appLinks.getInitialLink().then((uri) {
    if (uri == null) return;
    final route = PortalDeepLinks.mapUri(uri);
    if (route != null) {
      ref.read(pendingDeepLinkProvider.notifier).state = route;
    }
  });

  appLinks.uriLinkStream.listen((uri) {
    final route = PortalDeepLinks.mapUri(uri);
    if (route != null) {
      ref.read(pendingDeepLinkProvider.notifier).state = route;
    }
  });
});
