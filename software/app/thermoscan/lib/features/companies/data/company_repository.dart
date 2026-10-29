import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thermoscan/core/network/api_client.dart';
import 'package:thermoscan/core/network/api_exception.dart';
import 'package:thermoscan/features/companies/domain/company_models.dart';

final companyRepositoryProvider = Provider<CompanyRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return CompanyRepository(dio: dio);
});

class CompanyRepository {
  const CompanyRepository({required this.dio});

  final Dio dio;

  Future<List<Company>> listCompanies({
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/companies',
        queryParameters: {
          'limit': limit,
          'offset': offset,
        },
      );
      final list = response.data?['companies'] as List<dynamic>? ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(Company.fromJson)
          .toList();
    } on DioException catch (err) {
      throw ApiException.fromDioException(err);
    }
  }

  Future<CompanyDetails> getCompanyDetails(String companyId) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/companies/$companyId',
      );
      return CompanyDetails.fromJson(response.data ?? const {});
    } on DioException catch (err) {
      throw ApiException.fromDioException(err);
    }
  }

  Future<CreateCompanyResult> createCompany({
    required String name,
    String? address,
    required String managerName,
    required String managerEmail,
  }) async {
    try {
      final trimmedAddress = address?.trim();
      final response = await dio.post<Map<String, dynamic>>(
        '/companies',
        data: {
          'name': name.trim(),
          if (trimmedAddress != null && trimmedAddress.isNotEmpty)
            'address': trimmedAddress,
          'manager_name': managerName.trim(),
          'manager_email': managerEmail.trim(),
        },
      );
      return CreateCompanyResult.fromJson(response.data ?? const {});
    } on DioException catch (err) {
      throw ApiException.fromDioException(err);
    }
  }

  Future<ResetManagerPasswordResult> resetManagerPassword({
    required String companyId,
    required String managerId,
  }) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/companies/$companyId/managers/$managerId/reset-password',
      );
      return ResetManagerPasswordResult.fromJson(response.data ?? const {});
    } on DioException catch (err) {
      throw ApiException.fromDioException(err);
    }
  }
}
