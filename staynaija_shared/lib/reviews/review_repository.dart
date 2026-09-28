import 'package:dio/dio.dart';

import 'package:staynaija_shared/core/api/dio_client.dart';
import 'package:staynaija_shared/models/review.dart';

class ReviewRepository {
  final Dio _dio = DioClient.instance.dio;

  Future<Review> createReview({
    required String bookingId,
    required int cleanliness,
    required int communication,
    required int accuracy,
    required int locationRating,
    required int value,
    String? comment,
  }) async {
    final response = await _dio.post('/reviews', data: {
      'booking_id': bookingId,
      'cleanliness': cleanliness,
      'communication': communication,
      'accuracy': accuracy,
      'location_rating': locationRating,
      'value': value,
      'comment': comment,
    });
    return Review.fromJson(response.data);
  }

  Future<List<Review>> listForListing(String listingId) async {
    final response = await _dio.get('/reviews/listing/$listingId');
    return (response.data as List).map((json) => Review.fromJson(json)).toList();
  }
}
