import 'package:dio/dio.dart';

import 'package:staynaija_shared/core/api/dio_client.dart';
import 'package:staynaija_shared/core/storage/secure_storage.dart';
import 'package:staynaija_shared/models/user.dart';

class AuthRepository {
  final Dio _dio = DioClient.instance.dio;

  Future<AppUser> register({
    required String fullName,
    required String email,
    required String password,
    String? phoneNumber,
    required bool isHost,
  }) async {
    final response = await _dio.post('/auth/register', data: {
      'full_name': fullName,
      'email': email,
      'password': password,
      'phone_number': phoneNumber,
      'is_host': isHost,
    });
    return _saveTokensAndReturnUser(response.data);
  }

  Future<AppUser> login({required String email, required String password}) async {
    final response = await _dio.post('/auth/login', data: {'email': email, 'password': password});
    return _saveTokensAndReturnUser(response.data);
  }

  /// Signs in with a Google/Apple/Facebook token, silently registering the
  /// account on its first use - there is no separate "sign up with Google"
  /// step, since the provider has already proven who this person is.
  ///
  /// [token] is the provider's own signed token (never a client-asserted
  /// email) - see the caller in each app's social-sign-in service for how
  /// each SDK produces it. [isHost] should be true from the host app, so a
  /// brand-new account starts host-enabled.
  Future<AppUser> socialLogin({
    required String provider,
    required String token,
    String? fullName,
    required bool isHost,
  }) async {
    final response = await _dio.post('/auth/social', data: {
      'provider': provider,
      'token': token,
      'full_name': fullName,
      'is_host': isHost,
    });
    return _saveTokensAndReturnUser(response.data);
  }

  Future<AppUser> _saveTokensAndReturnUser(Map<String, dynamic> data) async {
    await SecureStorage.saveTokens(accessToken: data['access_token'], refreshToken: data['refresh_token']);
    return AppUser.fromJson(data['user']);
  }

  Future<AppUser?> fetchCurrentUser() async {
    final token = await SecureStorage.accessToken;
    if (token == null) return null;
    try {
      final response = await _dio.get('/auth/me');
      return AppUser.fromJson(response.data);
    } catch (_) {
      return null;
    }
  }

  Future<String?> requestOtp(String phoneNumber) async {
    final response = await _dio.post('/auth/request-otp', data: {'phone_number': phoneNumber});
    return response.data['dev_otp_code'];
  }

  Future<AppUser> verifyOtp({required String phoneNumber, required String code}) async {
    final response = await _dio.post('/auth/verify-otp', data: {'phone_number': phoneNumber, 'code': code});
    return AppUser.fromJson(response.data);
  }

  Future<void> logout() => SecureStorage.clear();
}
