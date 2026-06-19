import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../organizer/providers/organizer_providers.dart';
import '../data/public_event_catalog.dart';
import '../models/public_models.dart';

final publicCatalogProvider = Provider<PublicEventCatalog>((ref) => PublicEventCatalog());

final discoverQueryProvider = StateProvider<String>((ref) => '');
final discoverCategoryProvider = StateProvider<String>((ref) => 'all');

final publicEventsProvider = FutureProvider.autoDispose<List<PublicEvent>>((ref) async {
  ref.watch(organizerRevisionProvider);
  final catalog = ref.watch(publicCatalogProvider);
  final query = ref.watch(discoverQueryProvider);
  final category = ref.watch(discoverCategoryProvider);
  return catalog.listEvents(query: query, category: category);
});

final publicEventProvider = FutureProvider.autoDispose.family<PublicEvent?, String>((ref, id) async {
  ref.watch(organizerRevisionProvider);
  return ref.watch(publicCatalogProvider).getEvent(id);
});

final eventCategoriesProvider = Provider<List<String>>((ref) {
  ref.watch(organizerRevisionProvider);
  return ref.watch(publicCatalogProvider).categories();
});

class CartNotifier extends Notifier<List<CartLine>> {
  @override
  List<CartLine> build() => [];

  int get itemCount => state.fold(0, (sum, line) => sum + line.quantity);
  int get totalMinor => state.fold(0, (sum, line) => sum + line.lineTotalMinor);

  void addOrUpdate(CartLine line) {
    final idx = state.indexWhere((l) => l.eventId == line.eventId && l.tierId == line.tierId);
    if (idx >= 0) {
      final next = [...state];
      next[idx] = next[idx].copyWith(quantity: next[idx].quantity + line.quantity);
      state = next;
    } else {
      state = [...state, line];
    }
  }

  void setQuantity(String eventId, String tierId, int quantity) {
    if (quantity <= 0) {
      removeLine(eventId, tierId);
      return;
    }
    state = [
      for (final line in state)
        if (line.eventId == eventId && line.tierId == tierId)
          line.copyWith(quantity: quantity)
        else
          line,
    ];
  }

  void removeLine(String eventId, String tierId) {
    state = state.where((l) => !(l.eventId == eventId && l.tierId == tierId)).toList();
  }

  void clear() => state = [];
}

final cartProvider = NotifierProvider<CartNotifier, List<CartLine>>(CartNotifier.new);

class AttendeeTicketsNotifier extends Notifier<List<AttendeeTicket>> {
  @override
  List<AttendeeTicket> build() => [];

  void addAll(List<AttendeeTicket> tickets) => state = [...state, ...tickets];
}

final attendeeTicketsProvider =
    NotifierProvider<AttendeeTicketsNotifier, List<AttendeeTicket>>(AttendeeTicketsNotifier.new);

final cartCountProvider = Provider<int>(
  (ref) => ref.watch(cartProvider).fold(0, (sum, line) => sum + line.quantity),
);
