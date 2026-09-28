import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:staynaija_shared/core/api/dio_client.dart';
import 'package:staynaija_shared/models/listing.dart';

final favoriteRepositoryProvider = Provider((ref) => FavoriteRepository());

class FavoriteRepository {
  final Dio _dio = DioClient.instance.dio;

  Future<List<Listing>> list() async {
    final response = await _dio.get('/favorites');
    return (response.data as List).map((json) => Listing.fromJson(json)).toList();
  }

  Future<Set<String>> listIds() async {
    final response = await _dio.get('/favorites/ids');
    return Set<String>.from(response.data['listing_ids'] as List);
  }

  Future<void> add(String listingId) => _dio.post('/favorites/$listingId');

  Future<void> remove(String listingId) => _dio.delete('/favorites/$listingId');
}
