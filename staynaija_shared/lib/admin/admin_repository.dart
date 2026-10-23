import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:staynaija_shared/core/api/dio_client.dart';
import 'package:staynaija_shared/models/user.dart';

final adminRepositoryProvider = Provider((ref) => AdminRepository());

/// A user's KYC submission, as the admin approval screen needs it. Deliberately
/// separate from `AppUser` - the document/selfie URLs (and the ability to see
/// someone else's verification queue at all) are reviewer-only concerns that
/// have no reason to live on the model every screen in the app already uses.
class VerificationRequest {
  final String id;
  final String fullName;
  final String email;
  final String? phoneNumber;
  final bool isHost;
  final String verificationStatus;
  final String? idDocumentUrl;
  final String? selfieUrl;
  final DateTime createdAt;

  VerificationRequest({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.isHost,
    required this.verificationStatus,
    required this.idDocumentUrl,
    required this.selfieUrl,
    required this.createdAt,
  });

  factory VerificationRequest.fromJson(Map<String, dynamic> json) => VerificationRequest(
        id: json['id'],
        fullName: json['full_name'],
        email: json['email'],
        phoneNumber: json['phone_number'],
        isHost: json['is_host'] ?? false,
        verificationStatus: json['verification_status'] ?? 'pending',
        idDocumentUrl: json['id_document_url'],
        selfieUrl: json['selfie_url'],
        createdAt: DateTime.parse(json['created_at']),
      );
}

class AdminRepository {
  final Dio _dio = DioClient.instance.dio;

  /// `status` is one of "pending" (the default, i.e. the review queue),
  /// "verified", or "rejected" - server-validated, see api/v1/admin.py.
  Future<List<VerificationRequest>> listVerifications({String status = 'pending'}) async {
    final response = await _dio.get('/admin/verifications', queryParameters: {'status': status});
    return (response.data as List).map((json) => VerificationRequest.fromJson(json)).toList();
  }

  Future<List<AppUser>> listHosts() async {
    final response = await _dio.get('/admin/hosts');
    return (response.data as List).map((json) => AppUser.fromJson(json)).toList();
  }

  /// Onboards a vetted host. For an email with no account yet, [password] is a
  /// temporary one the host is forced to replace at first login; for an
  /// existing account it is ignored and the account is simply promoted.
  Future<AppUser> createHost({
    required String email,
    String? fullName,
    String? phoneNumber,
    String? password,
  }) async {
    final response = await _dio.post('/admin/hosts', data: {
      'email': email,
      'full_name': fullName,
      'phone_number': phoneNumber,
      'password': password,
    });
    return AppUser.fromJson(response.data);
  }

  Future<void> reviewVerification(String userId, {required bool approve}) async {
    await _dio.patch('/admin/verifications/$userId', data: {'status': approve ? 'verified' : 'rejected'});
  }
}
