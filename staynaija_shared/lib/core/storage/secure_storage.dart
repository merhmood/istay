import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  SecureStorage._();
  static const _storage = FlutterSecureStorage();

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _deviceIdKey = 'device_id';

  static Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  static Future<String?> get accessToken => _storage.read(key: _accessTokenKey);
  static Future<String?> get refreshToken => _storage.read(key: _refreshTokenKey);

  /// A random per-install identifier, created on first use.
  ///
  /// Used only to group a signed-out person's own browsing together, so that
  /// looking at six listings before making an account still teaches us
  /// something. It is generated locally and is not derived from any hardware
  /// identifier, so it cannot follow anyone between apps, and `clear()`
  /// deliberately leaves it alone - signing out ends a session, not the install.
  static Future<String> deviceId() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final random = Random.secure();
    final id = List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    await _storage.write(key: _deviceIdKey, value: id);
    return id;
  }

  static Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}
