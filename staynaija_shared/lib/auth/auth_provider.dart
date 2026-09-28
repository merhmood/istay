import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:staynaija_shared/core/api/dio_client.dart';
import 'package:staynaija_shared/auth/auth_repository.dart';
import 'package:staynaija_shared/models/user.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final AppUser? user;
  final bool isLoading;
  final String? error;

  const AuthState({this.status = AuthStatus.unknown, this.user, this.isLoading = false, this.error});

  AuthState copyWith({AuthStatus? status, AppUser? user, bool? isLoading, String? error, bool clearError = false}) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final authRepositoryProvider = Provider((ref) => AuthRepository());

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repository) : super(const AuthState()) {
    _restoreSession();
  }

  final AuthRepository _repository;

  Future<void> _restoreSession() async {
    final user = await _repository.fetchCurrentUser();
    state = state.copyWith(
      status: user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated,
      user: user,
    );
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _repository.login(email: email, password: password);
      state = state.copyWith(status: AuthStatus.authenticated, user: user, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _friendlyError(e));
      return false;
    }
  }

  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
    String? phoneNumber,
    required bool isHost,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _repository.register(
        fullName: fullName,
        email: email,
        password: password,
        phoneNumber: phoneNumber,
        isHost: isHost,
      );
      state = state.copyWith(status: AuthStatus.authenticated, user: user, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _friendlyError(e));
      return false;
    }
  }

  Future<bool> socialLogin({
    required String provider,
    required String token,
    String? fullName,
    required bool isHost,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _repository.socialLogin(
        provider: provider,
        token: token,
        fullName: fullName,
        isHost: isHost,
      );
      state = state.copyWith(status: AuthStatus.authenticated, user: user, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _friendlyError(e));
      return false;
    }
  }

  Future<void> refreshUser() async {
    final user = await _repository.fetchCurrentUser();
    if (user != null) state = state.copyWith(user: user);
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  String _friendlyError(Object e) => apiErrorMessage(e);
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});
