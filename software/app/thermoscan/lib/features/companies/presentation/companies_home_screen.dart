import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thermoscan/core/theme/app_colors.dart';
import 'package:thermoscan/core/theme/app_typography.dart';
import 'package:thermoscan/core/widgets/app_buttons.dart';
import 'package:thermoscan/core/widgets/top_app_bar.dart';
import 'package:thermoscan/features/auth/presentation/auth_controller.dart';

/// SCR-04: Companies Home (System Admin) — Shell ready for Step 3
class CompaniesHomeScreen extends ConsumerWidget {
  const CompaniesHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ThermoScanAppBar(
        title: 'Enterprise Admin',
        role: user?.role ?? 'system_admin',
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Companies', style: AppTypography.h2),
            const SizedBox(height: 4),
            Text(
              'Signed in as ${user?.name ?? 'System Admin'} (${user?.email ?? ''})',
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('System Admin Workspace', style: AppTypography.h3),
                  const SizedBox(height: 6),
                  Text(
                    'Authentication, session guards, and profile management (Steps 1 & 2) are active. Company provisioning and manager password reset screens (SCR-04 to SCR-08) will be connected in Step 3.',
                    style: AppTypography.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  SecondaryButton(
                    label: 'Open Profile & Password (SCR-23)',
                    icon: Icons.manage_accounts_outlined,
                    onPressed: () => context.push('/profile'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
