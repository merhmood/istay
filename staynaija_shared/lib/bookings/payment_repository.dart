import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:staynaija_shared/core/api/dio_client.dart';
import 'package:staynaija_shared/models/booking.dart';

final paymentRepositoryProvider = Provider((ref) => PaymentRepository());

/// A payment the guest made, flattened with its booking/listing context by the
/// backend so the payments and escrow screens need only this one call.
class PaymentHistoryEntry {
  final String id;
  final String reference;
  final double amount;
  final String currency;
  final String status;
  final DateTime createdAt;
  final String bookingId;
  final String bookingStatus;
  final String listingTitle;
  final String listingCity;
  final DateTime checkIn;
  final DateTime checkOut;
  final DateTime? payoutReleaseAt;
  final bool inEscrow;

  PaymentHistoryEntry({
    required this.id,
    required this.reference,
    required this.amount,
    required this.currency,
    required this.status,
    required this.createdAt,
    required this.bookingId,
    required this.bookingStatus,
    required this.listingTitle,
    required this.listingCity,
    required this.checkIn,
    required this.checkOut,
    required this.payoutReleaseAt,
    required this.inEscrow,
  });

  factory PaymentHistoryEntry.fromJson(Map<String, dynamic> json) => PaymentHistoryEntry(
        id: json['id'],
        reference: json['reference'],
        amount: (json['amount'] as num).toDouble(),
        currency: json['currency'],
        status: json['status'],
        createdAt: DateTime.parse(json['created_at']),
        bookingId: json['booking_id'],
        bookingStatus: json['booking_status'],
        listingTitle: json['listing_title'],
        listingCity: json['listing_city'],
        checkIn: DateTime.parse(json['check_in']),
        checkOut: DateTime.parse(json['check_out']),
        payoutReleaseAt: json['payout_release_at'] != null ? DateTime.parse(json['payout_release_at']) : null,
        inEscrow: json['in_escrow'] ?? false,
      );
}

class PaymentInit {
  final String reference;
  final String authorizationUrl;
  final String publicKey;
  final int amountKobo;
  final String email;

  PaymentInit({
    required this.reference,
    required this.authorizationUrl,
    required this.publicKey,
    required this.amountKobo,
    required this.email,
  });

  factory PaymentInit.fromJson(Map<String, dynamic> json) => PaymentInit(
        reference: json['reference'],
        authorizationUrl: json['authorization_url'],
        publicKey: json['public_key'],
        amountKobo: json['amount_kobo'],
        email: json['email'],
      );
}

class PaymentRepository {
  final Dio _dio = DioClient.instance.dio;

  Future<PaymentInit> initialize(String bookingId) async {
    final response = await _dio.post('/payments/initialize', data: {'booking_id': bookingId});
    return PaymentInit.fromJson(response.data);
  }

  Future<List<PaymentHistoryEntry>> myPayments() async {
    final response = await _dio.get('/payments/mine');
    return [for (final item in response.data as List) PaymentHistoryEntry.fromJson(item)];
  }

  Future<Booking> verify(String reference) async {
    final response = await _dio.post('/payments/verify', data: {'reference': reference});
    return Booking.fromJson(response.data);
  }
}
