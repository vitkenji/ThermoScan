class AuthUser {
  const AuthUser({
    required this.id,
    this.companyId,
    required this.name,
    required this.email,
    required this.role,
    required this.isActive,
    required this.mustChangePassword,
  });

  final String id;
  final String? companyId;
  final String name;
  final String email;
  final String role; // 'system_admin' | 'manager' | 'technician' | 'client'
  final bool isActive;
  final bool mustChangePassword;

  bool get isSystemAdmin => role == 'system_admin';
  bool get isManager => role == 'manager';
  bool get isTechnician => role == 'technician';
  bool get isClient => role == 'client';

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'TS';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  String get roleDisplayName {
    switch (role) {
      case 'system_admin':
        return 'System Admin';
      case 'manager':
        return 'Manager';
      case 'technician':
        return 'Technician';
      case 'client':
        return 'Client';
      default:
        return role;
    }
  }

  String get homeRoute {
    if (mustChangePassword) return '/change-password';
    switch (role) {
      case 'system_admin':
        return '/admin/companies';
      case 'manager':
        return '/manager';
      case 'technician':
      case 'client':
      default:
        return '/home';
    }
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String? ?? '',
      companyId: json['company_id'] as String?,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'client',
      isActive: json['is_active'] as bool? ?? true,
      mustChangePassword: json['must_change_password'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'company_id': companyId,
        'name': name,
        'email': email,
        'role': role,
        'is_active': isActive,
        'must_change_password': mustChangePassword,
      };
}

class AuthSessionResponse {
  const AuthSessionResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final AuthUser user;

  factory AuthSessionResponse.fromJson(Map<String, dynamic> json) {
    return AuthSessionResponse(
      accessToken: json['access_token'] as String? ?? '',
      refreshToken: json['refresh_token'] as String? ?? '',
      user: AuthUser.fromJson(
        (json['user'] as Map<String, dynamic>?) ?? const {},
      ),
    );
  }
}
