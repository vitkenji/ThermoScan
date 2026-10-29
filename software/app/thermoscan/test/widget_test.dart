import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thermoscan/core/storage/token_storage.dart';
import 'package:thermoscan/features/auth/data/auth_repository.dart';
import 'package:thermoscan/features/auth/domain/auth_user.dart';
import 'package:thermoscan/features/companies/data/company_repository.dart';
import 'package:thermoscan/features/companies/domain/company_models.dart';
import 'package:thermoscan/features/users/data/user_repository.dart';
import 'package:thermoscan/features/users/domain/user_models.dart';
import 'package:thermoscan/main.dart';

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository({this.initialUser}) : super(dio: Dio());

  final AuthUser? initialUser;

  @override
  Future<AuthUser> getMe() async {
    if (initialUser == null) {
      throw Exception('Unauthenticated');
    }
    return initialUser!;
  }
}

class _FakeCompanyRepository extends CompanyRepository {
  _FakeCompanyRepository() : super(dio: Dio());

  @override
  Future<List<Company>> listCompanies({int limit = 100, int offset = 0}) async {
    return const [
      Company(
        id: 'comp-1',
        name: 'SolTech Energy Ltd',
        address: 'São Paulo, BR',
        isActive: true,
        createdAt: '2026-10-29T10:00:00Z',
        updatedAt: '2026-10-29T10:00:00Z',
      ),
    ];
  }
}

class _FakeUserRepository extends UserRepository {
  _FakeUserRepository() : super(dio: Dio());

  @override
  Future<List<CompanyUser>> listUsers({
    String? role,
    int limit = 100,
    int offset = 0,
  }) async {
    return const [
      CompanyUser(
        id: 'mgr-1',
        companyId: 'comp-1',
        name: 'Elena Rostova',
        email: 'elena@soltech.io',
        role: 'manager',
        isActive: true,
        isDefaultManager: true,
        mustChangePassword: false,
        createdAt: '2026-10-29T10:00:00Z',
        updatedAt: '2026-10-29T10:00:00Z',
      ),
    ];
  }
}

void main() {
  testWidgets('Bootstraps from Splash to Login when no session exists',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(InMemoryTokenStorage()),
        ],
        child: const ThermoScanApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Field Diagnostics Login'), findsOneWidget);
    expect(find.text('Corporate Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
  });

  testWidgets('Enforces Mandatory Password Change (SCR-03) when required',
      (WidgetTester tester) async {
    final tokenStorage = InMemoryTokenStorage();
    await tokenStorage.saveTokens(
      accessToken: 'fake-access',
      refreshToken: 'fake-refresh',
    );

    const tempPassUser = AuthUser(
      id: 'u-1',
      companyId: 'comp-1',
      name: 'First Manager',
      email: 'mgr@soltech.io',
      role: 'manager',
      isActive: true,
      mustChangePassword: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(tokenStorage),
          authRepositoryProvider.overrideWithValue(
            _FakeAuthRepository(initialUser: tempPassUser),
          ),
        ],
        child: const ThermoScanApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Set Permanent Password'), findsOneWidget);
    expect(find.text('Update Password'), findsOneWidget);
  });

  testWidgets('Routes authenticated Manager to Administration Home (SCR-24)',
      (WidgetTester tester) async {
    final tokenStorage = InMemoryTokenStorage();
    await tokenStorage.saveTokens(
      accessToken: 'fake-access',
      refreshToken: 'fake-refresh',
    );

    const managerUser = AuthUser(
      id: 'mgr-1',
      companyId: 'comp-1',
      name: 'Elena Rostova',
      email: 'elena@soltech.io',
      role: 'manager',
      isActive: true,
      mustChangePassword: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(tokenStorage),
          authRepositoryProvider.overrideWithValue(
            _FakeAuthRepository(initialUser: managerUser),
          ),
          userRepositoryProvider.overrideWithValue(_FakeUserRepository()),
        ],
        child: const ThermoScanApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Administration'), findsOneWidget);
    expect(find.text('Company Users'), findsOneWidget);
    expect(find.text('Clients'), findsOneWidget);
  });

  testWidgets('Routes authenticated System Admin to Companies Home (SCR-04)',
      (WidgetTester tester) async {
    final tokenStorage = InMemoryTokenStorage();
    await tokenStorage.saveTokens(
      accessToken: 'fake-access',
      refreshToken: 'fake-refresh',
    );

    const adminUser = AuthUser(
      id: 'admin-1',
      name: 'System Admin',
      email: 'admin@thermoscan.local',
      role: 'system_admin',
      isActive: true,
      mustChangePassword: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(tokenStorage),
          authRepositoryProvider.overrideWithValue(
            _FakeAuthRepository(initialUser: adminUser),
          ),
          companyRepositoryProvider.overrideWithValue(_FakeCompanyRepository()),
        ],
        child: const ThermoScanApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Companies'), findsOneWidget);
    expect(find.text('SolTech Energy Ltd'), findsOneWidget);
  });
}
