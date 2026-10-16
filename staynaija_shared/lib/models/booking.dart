enum BookingStatus {
  pendingHostApproval,
  awaitingPayment,
  confirmed,
  declined,
  cancelled,
  completed;

  static BookingStatus fromApi(String value) => switch (value) {
        'pending_host_approval' => BookingStatus.pendingHostApproval,
        'awaiting_payment' => BookingStatus.awaitingPayment,
        'confirmed' => BookingStatus.confirmed,
        'declined' => BookingStatus.declined,
        'cancelled' => BookingStatus.cancelled,
        'completed' => BookingStatus.completed,
        _ => BookingStatus.pendingHostApproval,
      };

  String get apiValue => switch (this) {
        BookingStatus.pendingHostApproval => 'pending_host_approval',
        BookingStatus.awaitingPayment => 'awaiting_payment',
        BookingStatus.confirmed => 'confirmed',
        BookingStatus.declined => 'declined',
        BookingStatus.cancelled => 'cancelled',
        BookingStatus.completed => 'completed',
      };

  String get label => switch (this) {
        BookingStatus.pendingHostApproval => 'Pending host approval',
        BookingStatus.awaitingPayment => 'Awaiting payment',
        BookingStatus.confirmed => 'Confirmed',
        BookingStatus.declined => 'Declined',
        BookingStatus.cancelled => 'Cancelled',
        BookingStatus.completed => 'Completed',
      };
}

class PriceBreakdown {
  final int nights;
  final double nightlyRate;
  final double subtotal;
  final double discountAmount;
  final double cleaningFee;
  final double platformFee;
  final double hostPayoutAmount;
  final double totalPrice;

  PriceBreakdown({
    required this.nights,
    required this.nightlyRate,
    required this.subtotal,
    required this.discountAmount,
    required this.cleaningFee,
    required this.platformFee,
    required this.hostPayoutAmount,
    required this.totalPrice,
  });

  factory PriceBreakdown.fromJson(Map<String, dynamic> json) => PriceBreakdown(
        nights: json['nights'],
        nightlyRate: (json['nightly_rate'] as num).toDouble(),
        subtotal: (json['subtotal'] as num).toDouble(),
        discountAmount: (json['discount_amount'] as num).toDouble(),
        cleaningFee: (json['cleaning_fee'] as num).toDouble(),
        platformFee: (json['platform_fee'] as num).toDouble(),
        hostPayoutAmount: (json['host_payout_amount'] as num).toDouble(),
        totalPrice: (json['total_price'] as num).toDouble(),
      );
}

class Booking {
  final String id;
  final String listingId;
  final String guestId;
  final String hostId;
  final DateTime checkIn;
  final DateTime checkOut;
  final int numGuests;
  final int nights;
  final double subtotal;
  final double discountAmount;
  final double cleaningFee;
  final double platformFee;
  final double hostPayoutAmount;
  final double totalPrice;
  final BookingStatus status;
  final DateTime? payoutReleaseAt;
  final String? paymentReference;

  Booking({
    required this.id,
    required this.listingId,
    required this.guestId,
    required this.hostId,
    required this.checkIn,
    required this.checkOut,
    required this.numGuests,
    required this.nights,
    required this.subtotal,
    required this.discountAmount,
    required this.cleaningFee,
    required this.platformFee,
    required this.hostPayoutAmount,
    required this.totalPrice,
    required this.status,
    required this.payoutReleaseAt,
    required this.paymentReference,
  });

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
        id: json['id'],
        listingId: json['listing_id'],
        guestId: json['guest_id'],
        hostId: json['host_id'],
        checkIn: DateTime.parse(json['check_in']),
        checkOut: DateTime.parse(json['check_out']),
        numGuests: json['num_guests'],
        nights: json['nights'],
        subtotal: (json['subtotal'] as num).toDouble(),
        discountAmount: (json['discount_amount'] as num).toDouble(),
        cleaningFee: (json['cleaning_fee'] as num).toDouble(),
        platformFee: (json['platform_fee'] as num).toDouble(),
        hostPayoutAmount: (json['host_payout_amount'] as num).toDouble(),
        totalPrice: (json['total_price'] as num).toDouble(),
        status: BookingStatus.fromApi(json['status']),
        payoutReleaseAt: json['payout_release_at'] != null ? DateTime.parse(json['payout_release_at']) : null,
        paymentReference: json['payment_reference'],
      );
}
