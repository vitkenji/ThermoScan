class Company {
  const Company({
    required this.id,
    required this.name,
    this.address,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? address;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  String get formattedCreatedDate {
    final parsed = DateTime.tryParse(createdAt);
    if (parsed == null) return createdAt;
    final local = parsed.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      address: json['address'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }
}

class CompanyManagerSummary {
  const CompanyManagerSummary({
    required this.id,
    this.companyId,
    required this.name,
    required this.email,
    required this.role,
    required this.isActive,
    required this.isDefaultManager,
    required this.mustChangePassword,
  });

  final String id;
  final String? companyId;
  final String name;
  final String email;
  final String role;
  final bool isActive;
  final bool isDefaultManager;
  final bool mustChangePassword;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'MG';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  factory CompanyManagerSummary.fromJson(Map<String, dynamic> json) {
    return CompanyManagerSummary(
      id: json['id'] as String? ?? '',
      companyId: json['company_id'] as String?,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'manager',
      isActive: json['is_active'] as bool? ?? true,
      isDefaultManager: json['is_default_manager'] as bool? ?? false,
      mustChangePassword: json['must_change_password'] as bool? ?? false,
    );
  }
}

class CompanyDetails {
  const CompanyDetails({
    required this.company,
    required this.managers,
  });

  final Company company;
  final List<CompanyManagerSummary> managers;

  factory CompanyDetails.fromJson(Map<String, dynamic> json) {
    final managersRaw = json['managers'] as List<dynamic>? ?? const [];
    return CompanyDetails(
      company: Company.fromJson(
        (json['company'] as Map<String, dynamic>?) ?? const {},
      ),
      managers: managersRaw
          .whereType<Map<String, dynamic>>()
          .map(CompanyManagerSummary.fromJson)
          .toList(),
    );
  }
}

class CreateCompanyResult {
  const CreateCompanyResult({
    required this.company,
    required this.defaultManager,
    required this.temporaryPassword,
  });

  final Company company;
  final CompanyManagerSummary defaultManager;
  final String temporaryPassword;

  factory CreateCompanyResult.fromJson(Map<String, dynamic> json) {
    return CreateCompanyResult(
      company: Company.fromJson(
        (json['company'] as Map<String, dynamic>?) ?? const {},
      ),
      defaultManager: CompanyManagerSummary.fromJson(
        (json['default_manager'] as Map<String, dynamic>?) ?? const {},
      ),
      temporaryPassword: json['temporary_password'] as String? ?? '',
    );
  }
}

class ResetManagerPasswordResult {
  const ResetManagerPasswordResult({
    required this.user,
    required this.temporaryPassword,
  });

  final CompanyManagerSummary user;
  final String temporaryPassword;

  factory ResetManagerPasswordResult.fromJson(Map<String, dynamic> json) {
    return ResetManagerPasswordResult(
      user: CompanyManagerSummary.fromJson(
        (json['user'] as Map<String, dynamic>?) ?? const {},
      ),
      temporaryPassword: json['temporary_password'] as String? ?? '',
    );
  }
}
