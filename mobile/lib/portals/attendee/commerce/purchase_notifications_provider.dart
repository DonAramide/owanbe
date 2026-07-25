import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PurchaseNotificationType {
  purchaseConfirmation,
  registrationConfirmation,
  ticketReady,
  paymentSuccess,
  paymentFailure,
  paymentPending,
  resendConfirmation,
}

class PurchaseNotification {
  PurchaseNotification({
    required this.type,
    required this.title,
    required this.body,
    this.orderId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final PurchaseNotificationType type;
  final String title;
  final String body;
  final String? orderId;
  final DateTime createdAt;
}

class PurchaseNotificationsNotifier extends Notifier<List<PurchaseNotification>> {
  @override
  List<PurchaseNotification> build() => const [];

  void push(PurchaseNotification notification) {
    state = [notification, ...state].take(40).toList();
  }

  void clear() => state = const [];
}

final purchaseNotificationsProvider =
    NotifierProvider<PurchaseNotificationsNotifier, List<PurchaseNotification>>(
  PurchaseNotificationsNotifier.new,
);
