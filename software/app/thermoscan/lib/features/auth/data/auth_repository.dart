import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thermoscan/core/network/api_client.dart';
import 'package:thermoscan/core/network/api_exception.dart';
import 'package:thermoscan/features/auth/domain/auth_user.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return AuthRepository(dio: dio);
});

class AuthRepository {
  const AuthRepository({required this.dio});

  final Dio dio;

  Future<AuthSessionResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {
          'email': email.trim(),
          'password': password,
        },
      );
      return AuthSessionResponse.fromJson(response.data ?? const {});
    } on DioException catch (err) {
      throw ApiException.fromDioException(err);
    }
  }

  Future<AuthUser> getMe() async {
    try {
      final response = await dio.get<Map<String, dynamic>>('/auth/me');
      return AuthUser.fromJson(response.data ?? const {});
    } on DioException catch (err) {
      throw ApiException.fromDioException(err);
    }
  }

  Future<AuthUser> updateOwnProfile({
    required String name,
    required String email,
  }) async {
    try {
      final response = await dio.patch<Map<String, dynamic>>(
        '/auth/me',
        data: {
          'name': name.trim(),
          'email': email.trim(),
        },
      );
      return AuthUser.fromJson(response.data ?? const {});
    } on DioException catch (err) {
      throw ApiException.fromDioException(err);
    }
  }

  Future<AuthSessionResponse> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/auth/change-password',
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );
      return AuthSessionResponse.fromJson(response.data ?? const {});
    } on DioException catch (err) {
      throw ApiException.fromDioException(err);
    }
  }

  Future<void> logout({String? refreshToken}) async {
    try {
      await dio.post<Map<String, dynamic>>(
        '/auth/logout',
        data: {
          if (refreshToken != null && refreshToken.isNotEmpty)
            'refresh_token': refreshToken,
        },
      );
    } on DioException {
      // Even if network fails or session is already expired, local cleanup proceeds.
    }
  }
}
