import 'package:flutter/material.dart';
import 'package:thermoscan/core/theme/app_colors.dart';
import 'package:thermoscan/core/theme/app_typography.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.isActive,
    this.activeLabel = 'Active',
    this.inactiveLabel = 'Inactive',
  });

  final bool isActive;
  final String activeLabel;
  final String inactiveLabel;

  @override
  Widget build(BuildContext context) {
    final bgColor =
        isActive ? AppColors.successBackground : AppColors.background;
    final borderColor =
        isActive ? AppColors.successBorder : AppColors.border;
    final textColor =
        isActive ? AppColors.success : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: textColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isActive ? activeLabel : inactiveLabel,
            style: AppTypography.chip.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }
}

class RoleChip extends StatelessWidget {
  const RoleChip({
    super.key,
    required this.role,
    this.compact = false,
  });

  final String role;
  final bool compact;

  String get _displayLabel {
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

  @override
  Widget build(BuildContext context) {
    Color bgColor = AppColors.primarySoft;
    Color textColor = AppColors.primary;
    Color borderColor = AppColors.border;

    if (role == 'technician') {
      bgColor = const Color(0xFFE0F7FA);
      textColor = const Color(0xFF005161);
      borderColor = const Color(0xFFB0ECFF);
    } else if (role == 'client') {
      bgColor = AppColors.warningBackground;
      textColor = AppColors.warning;
      borderColor = AppColors.warningBorder;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(compact ? 999 : 8),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Text(
        _displayLabel,
        style: AppTypography.chip.copyWith(
          fontSize: compact ? 11 : 12,
          color: textColor,
        ),
      ),
    );
  }
}
