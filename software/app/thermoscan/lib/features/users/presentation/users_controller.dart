import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thermoscan/features/users/data/user_repository.dart';
import 'package:thermoscan/features/users/domain/user_models.dart';

final companyUsersProvider =
    AsyncNotifierProvider.autoDispose<CompanyUsersNotifier, List<CompanyUser>>(
  CompanyUsersNotifier.new,
);

class CompanyUsersNotifier extends AutoDisposeAsyncNotifier<List<CompanyUser>> {
  @override
  Future<List<CompanyUser>> build() async {
    final repo = ref.watch(userRepositoryProvider);
    return repo.listUsers();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      final repo = ref.read(userRepositoryProvider);
      return repo.listUsers();
    });
  }
}

final userDetailsProvider = FutureProvider.autoDispose
    .family<CompanyUserDetails, String>((ref, userId) async {
  final repo = ref.watch(userRepositoryProvider);
  return repo.getUserDetails(userId);
});
