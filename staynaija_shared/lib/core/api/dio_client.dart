import 'package:dio/dio.dart';

import 'package:staynaija_shared/core/api/api_config.dart';
import 'package:staynaija_shared/core/storage/secure_storage.dart';

/// A Dio instance that attaches the access token to every request and
/// transparently refreshes it on a 401 using the stored refresh token.
class DioClient {
  DioClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.apiV1,
        connectTimeout: const Duration(seconds: 15),
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await SecureStorage.accessToken;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401 &&
              !error.requestOptions.path.contains('/auth/')) {
            final refreshed = await _tryRefresh();
            if (refreshed) {
              final retryResponse = await _retry(error.requestOptions);
              return handler.resolve(retryResponse);
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  static final DioClient instance = DioClient._internal();
  late final Dio _dio;

  Dio get dio => _dio;

  Future<bool> _tryRefresh() async {
    final refreshToken = await SecureStorage.refreshToken;
    if (refreshToken == null) return false;
    try {
      final response = await Dio(
        BaseOptions(baseUrl: ApiConfig.apiV1),
      ).post('/auth/refresh', data: {'refresh_token': refreshToken});
      await SecureStorage.saveTokens(
        accessToken: response.data['access_token'],
        refreshToken: response.data['refresh_token'],
      );
      return true;
    } catch (_) {
      await SecureStorage.clear();
      return false;
    }
  }

  Future<Response<dynamic>> _retry(RequestOptions requestOptions) async {
    final token = await SecureStorage.accessToken;
    final options = Options(
      method: requestOptions.method,
      headers: {...requestOptions.headers, 'Authorization': 'Bearer $token'},
    );
    return _dio.request<dynamic>(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: options,
    );
  }
}

String apiErrorMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['detail'] != null) {
      final detail = data['detail'];
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] != null)
          return first['msg'].toString();
      }
    }
    return error.message ?? 'Something went wrong';
  }
  return error.toString();
}

/// Broad categories of API failure, coarse enough to pick an icon/headline
/// from but not so specific it needs a case for every status code - a 404
/// and a 422 both mean "the request itself was wrong", not "try again".
enum ApiErrorKind {
  /// No connection reached the server at all - the request never got a
  /// response, so a retry is the obvious next step.
  network,

  /// The server responded but rejected the request (4xx) - retrying the
  /// exact same request won't help; something about it was wrong.
  badRequest,

  /// The server responded with a failure on its own side (5xx) - not the
  /// guest's fault, and often transient, so retrying is reasonable.
  serverError,

  /// Anything that doesn't fit the above, including non-Dio errors.
  unknown,
}

ApiErrorKind classifyApiError(Object error) {
  if (error is! DioException) return ApiErrorKind.unknown;
  switch (error.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.transformTimeout:
      return ApiErrorKind.network;
    case DioExceptionType.badResponse:
      final status = error.response?.statusCode ?? 0;
      if (status >= 500) return ApiErrorKind.serverError;
      if (status >= 400) return ApiErrorKind.badRequest;
      return ApiErrorKind.unknown;
    case DioExceptionType.cancel:
    case DioExceptionType.badCertificate:
    case DioExceptionType.unknown:
      return ApiErrorKind.unknown;
  }
}
