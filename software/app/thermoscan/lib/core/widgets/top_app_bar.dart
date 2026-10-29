import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:thermoscan/core/theme/app_colors.dart';
import 'package:thermoscan/core/theme/app_typography.dart';
import 'package:thermoscan/core/widgets/status_chips.dart';
import 'package:thermoscan/core/widgets/thermoscan_logo.dart';

class ThermoScanAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ThermoScanAppBar({
    super.key,
    required this.title,
    this.role,
    this.showBack = false,
    this.onBack,
    this.showProfileAction = true,
    this.trailingAction,
  });

  final String title;
  final String? role;
  final bool showBack;
  final VoidCallback? onBack;
  final bool showProfileAction;
  final Widget? trailingAction;

  @override
  Size get preferredSize => const Size.fromHeight(57);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (showBack) ...[
                  IconButton(
                    onPressed: onBack ?? () => context.pop(),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 4),
                ],
                const ThermoScanLogoIcon(size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.h3.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (role != null) ...[
                  RoleChip(role: role!, compact: true),
                  const SizedBox(width: 6),
                ],
                if (trailingAction != null)
                  trailingAction!
                else if (showProfileAction)
                  IconButton(
                    onPressed: () => context.push('/profile'),
                    icon: const Icon(
                      Icons.account_circle_outlined,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    tooltip: 'Profile & Settings',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
