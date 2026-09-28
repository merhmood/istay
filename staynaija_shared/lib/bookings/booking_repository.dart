import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:staynaija_shared/core/api/dio_client.dart';
import 'package:staynaija_shared/models/booking.dart';

final bookingRepositoryProvider = Provider((ref) => BookingRepository());

class BookingRepository {
  final Dio _dio = DioClient.instance.dio;

  Future<PriceBreakdown> getPriceBreakdown({
    required String listingId,
    required DateTime checkIn,
    required DateTime checkOut,
  }) async {
    final response = await _dio.get('/bookings/price-breakdown', queryParameters: {
      'listing_id': listingId,
      'check_in': _dateOnly(checkIn),
      'check_out': _dateOnly(checkOut),
    });
    return PriceBreakdown.fromJson(response.data);
  }

  Future<Booking> createBooking({
    required String listingId,
    required DateTime checkIn,
    required DateTime checkOut,
    required int numGuests,
  }) async {
    final response = await _dio.post('/bookings', data: {
      'listing_id': listingId,
      'check_in': _dateOnly(checkIn),
      'check_out': _dateOnly(checkOut),
      'num_guests': numGuests,
    });
    return Booking.fromJson(response.data);
  }

  Future<List<Booking>> myBookings({bool asHost = false}) async {
    final response = await _dio.get('/bookings/mine', queryParameters: {'as_host': asHost});
    return (response.data as List).map((json) => Booking.fromJson(json)).toList();
  }

  Future<Booking> getBooking(String id) async {
    final response = await _dio.get('/bookings/$id');
    return Booking.fromJson(response.data);
  }

  Future<Booking> updateStatus(String id, BookingStatus status) async {
    final response = await _dio.patch('/bookings/$id/status', data: {'status': status.apiValue});
    return Booking.fromJson(response.data);
  }

  String _dateOnly(DateTime date) => date.toIso8601String().split('T').first;
}
