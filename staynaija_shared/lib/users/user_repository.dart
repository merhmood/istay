import 'dart:io';

import 'package:dio/dio.dart';

import 'package:staynaija_shared/core/api/dio_client.dart';
import 'package:staynaija_shared/models/user.dart';

class UserRepository {
  final Dio _dio = DioClient.instance.dio;

  Future<AppUser> updateProfile(Map<String, dynamic> changes) async {
    final response = await _dio.patch('/users/me', data: changes);
    return AppUser.fromJson(response.data);
  }

  Future<AppUser> uploadVerificationDocuments({required File idDocument, required File selfie}) async {
    final formData = FormData.fromMap({
      'id_document': await MultipartFile.fromFile(idDocument.path),
      'selfie': await MultipartFile.fromFile(selfie.path),
    });
    final response = await _dio.post('/users/me/verification-documents', data: formData);
    return AppUser.fromJson(response.data);
  }
}
