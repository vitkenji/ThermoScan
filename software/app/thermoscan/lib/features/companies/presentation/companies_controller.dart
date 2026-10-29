import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thermoscan/features/companies/data/company_repository.dart';
import 'package:thermoscan/features/companies/domain/company_models.dart';

final companiesListProvider =
    AsyncNotifierProvider.autoDispose<CompaniesListNotifier, List<Company>>(
  CompaniesListNotifier.new,
);

class CompaniesListNotifier extends AutoDisposeAsyncNotifier<List<Company>> {
  @override
  Future<List<Company>> build() async {
    final repo = ref.watch(companyRepositoryProvider);
    return repo.listCompanies();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      final repo = ref.read(companyRepositoryProvider);
      return repo.listCompanies();
    });
  }
}

final companyDetailsProvider = FutureProvider.autoDispose
    .family<CompanyDetails, String>((ref, companyId) async {
  final repo = ref.watch(companyRepositoryProvider);
  return repo.getCompanyDetails(companyId);
});
