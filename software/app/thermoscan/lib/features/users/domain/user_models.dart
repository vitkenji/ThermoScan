class CompanyUser {
  const CompanyUser({
    required this.id,
    this.companyId,
    required this.name,
    required this.email,
    required this.role,
    required this.isActive,
    required this.isDefaultManager,
    required this.mustChangePassword,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? companyId;
  final String name;
  final String email;
  final String role; // 'manager' | 'technician' | 'client'
  final bool isActive;
  final bool isDefaultManager;
  final bool mustChangePassword;
  final String createdAt;
  final String updatedAt;

  bool get isManager => role == 'manager';
  bool get isTechnician => role == 'technician';
  bool get isClient => role == 'client';

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'US';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  factory CompanyUser.fromJson(Map<String, dynamic> json) {
    return CompanyUser(
      id: json['id'] as String? ?? '',
      companyId: json['company_id'] as String?,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'client',
      isActive: json['is_active'] as bool? ?? true,
      isDefaultManager: json['is_default_manager'] as bool? ?? false,
      mustChangePassword: json['must_change_password'] as bool? ?? false,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }
}

class AssignedManagerSummary {
  const AssignedManagerSummary({
    required this.id,
    required this.name,
    required this.email,
    required this.isActive,
    required this.isDefaultManager,
    required this.assignedAt,
  });

  final String id;
  final String name;
  final String email;
  final bool isActive;
  final bool isDefaultManager;
  final String assignedAt;

  factory AssignedManagerSummary.fromJson(Map<String, dynamic> json) {
    return AssignedManagerSummary(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
      isDefaultManager: json['is_default_manager'] as bool? ?? false,
      assignedAt: json['assigned_at'] as String? ?? '',
    );
  }
}

class CompanyUserDetails {
  const CompanyUserDetails({
    required this.user,
    required this.managers,
  });

  final CompanyUser user;
  final List<AssignedManagerSummary> managers;

  factory CompanyUserDetails.fromJson(Map<String, dynamic> json) {
    final rawManagers = json['managers'] as List<dynamic>? ?? const [];
    return CompanyUserDetails(
      user: CompanyUser.fromJson(
        (json['user'] as Map<String, dynamic>?) ?? const {},
      ),
      managers: rawManagers
          .whereType<Map<String, dynamic>>()
          .map(AssignedManagerSummary.fromJson)
          .toList(),
    );
  }
}

class CreateCompanyUserResult {
  const CreateCompanyUserResult({
    required this.user,
    required this.managerIds,
    required this.temporaryPassword,
  });

  final CompanyUser user;
  final List<String> managerIds;
  final String temporaryPassword;

  factory CreateCompanyUserResult.fromJson(Map<String, dynamic> json) {
    final rawIds = json['manager_ids'] as List<dynamic>? ?? const [];
    return CreateCompanyUserResult(
      user: CompanyUser.fromJson(
        (json['user'] as Map<String, dynamic>?) ?? const {},
      ),
      managerIds: rawIds.whereType<String>().toList(),
      temporaryPassword: json['temporary_password'] as String? ?? '',
    );
  }
}

class ResetCompanyUserPasswordResult {
  const ResetCompanyUserPasswordResult({
    required this.user,
    required this.temporaryPassword,
  });

  final CompanyUser user;
  final String temporaryPassword;

  factory ResetCompanyUserPasswordResult.fromJson(Map<String, dynamic> json) {
    return ResetCompanyUserPasswordResult(
      user: CompanyUser.fromJson(
        (json['user'] as Map<String, dynamic>?) ?? const {},
      ),
      temporaryPassword: json['temporary_password'] as String? ?? '',
    );
  }
}
