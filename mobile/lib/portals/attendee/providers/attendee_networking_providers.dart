import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/auth_notifier.dart';
import '../../../core/api/networking_api.dart';
import '../../../core/api/persistence_providers.dart';

final networkingPeopleQueryProvider =
    StateProvider.autoDispose.family<({String q, String company, String interest}), String>(
  (ref, eventId) => (q: '', company: '', interest: ''),
);

final networkingPeopleProvider =
    FutureProvider.autoDispose.family<List<DirectoryPerson>, String>((ref, eventId) async {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 2), link.close);
  ref.onDispose(timer.cancel);

  final session = ref.watch(authSessionProvider);
  if (session == null) return const [];
  final filters = ref.watch(networkingPeopleQueryProvider(eventId));
  return ref.read(networkingApiProvider).listPeople(
        session: session,
        eventId: eventId,
        q: filters.q,
        company: filters.company,
        interest: filters.interest,
      );
});

final networkingSuggestionsProvider =
    FutureProvider.autoDispose.family<List<DirectoryPerson>, String>((ref, eventId) async {
  final session = ref.watch(authSessionProvider);
  if (session == null) return const [];
  return ref.read(networkingApiProvider).suggestions(session: session, eventId: eventId);
});

final networkingConnectionsProvider =
    FutureProvider.autoDispose.family<List<NetworkingConnection>, String>((ref, eventId) async {
  final session = ref.watch(authSessionProvider);
  if (session == null) return const [];
  return ref.read(networkingApiProvider).listConnections(session: session, eventId: eventId);
});

final networkingBusinessCardProvider = FutureProvider.autoDispose<BusinessCard?>((ref) async {
  final session = ref.watch(authSessionProvider);
  if (session == null) return null;
  return ref.read(networkingApiProvider).fetchBusinessCard(session);
});

final networkingNotificationsProvider =
    FutureProvider.autoDispose<List<NetworkingNotification>>((ref) async {
  final session = ref.watch(authSessionProvider);
  if (session == null) return const [];
  return ref.read(networkingApiProvider).fetchNotifications(session);
});

Future<void> refreshNetworking(WidgetRef ref, String eventId) async {
  ref.invalidate(networkingPeopleProvider(eventId));
  ref.invalidate(networkingSuggestionsProvider(eventId));
  ref.invalidate(networkingConnectionsProvider(eventId));
  ref.invalidate(networkingNotificationsProvider);
}
