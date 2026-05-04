import '../data/app_database.dart';

/// Outbox [OutboxActions.actionType] values understood by [OwanbeRestOutboxTransport].
abstract final class OwanbeOutboxActionKinds {
  /// POST `/bookings` — [OutboxActions.payloadJson] is the raw JSON request body.
  static const bookingCreate = 'owanbe.booking.create';

  /// PATCH `/bookings/{bookingId}` — payload must include `bookingId`, `version`, and patch fields.
  static const bookingPatch = 'owanbe.booking.patch';

  /// POST `/bookings/{bookingId}/payments` — payload must include `bookingId`, `provider`, `returnUrl`.
  static const bookingPaymentInitiate = 'owanbe.booking.payment.initiate';
}

enum OutboxDeliveryDisposition { completed, retryLater, failed }

class OutboxDeliveryResult {
  const OutboxDeliveryResult._({
    required this.disposition,
    this.message,
    this.httpStatus,
  });

  const OutboxDeliveryResult.completed()
      : this._(disposition: OutboxDeliveryDisposition.completed);

  const OutboxDeliveryResult.retryLater({String? message, int? httpStatus})
      : this._(
          disposition: OutboxDeliveryDisposition.retryLater,
          message: message,
          httpStatus: httpStatus,
        );

  const OutboxDeliveryResult.failed({String? message, int? httpStatus})
      : this._(
          disposition: OutboxDeliveryDisposition.failed,
          message: message,
          httpStatus: httpStatus,
        );

  final OutboxDeliveryDisposition disposition;
  final String? message;
  final int? httpStatus;
}

/// Sends one durable outbox mutation to the Owanbe API (or another backend).
abstract class OutboxTransport {
  Future<OutboxDeliveryResult> send(OutboxActionRow row);
}
