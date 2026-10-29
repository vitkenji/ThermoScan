import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thermoscan/core/network/api_exception.dart';
import 'package:thermoscan/core/theme/app_colors.dart';
import 'package:thermoscan/core/theme/app_typography.dart';
import 'package:thermoscan/core/widgets/app_buttons.dart';
import 'package:thermoscan/core/widgets/status_chips.dart';
import 'package:thermoscan/core/widgets/temporary_password_modal.dart';
import 'package:thermoscan/core/widgets/top_app_bar.dart';
import 'package:thermoscan/features/auth/presentation/auth_controller.dart';
import 'package:thermoscan/features/companies/data/company_repository.dart';
import 'package:thermoscan/features/companies/domain/company_models.dart';
import 'package:thermoscan/features/companies/presentation/companies_controller.dart';

/// SCR-06: Company Details & Manager Reset Selection
/// SCR-08: Reset Manager Password Confirmation + Temporary Password Modal
class CompanyDetailsScreen extends ConsumerWidget {
  const CompanyDetailsScreen({
    super.key,
    required this.companyId,
  });

  final String companyId;

  Future<void> _openResetManagerDialog(
    BuildContext context,
    WidgetRef ref,
    CompanyManagerSummary manager,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ResetManagerConfirmationDialog(manager: manager),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final result =
          await ref.read(companyRepositoryProvider).resetManagerPassword(
                companyId: companyId,
                managerId: manager.id,
              );

      ref.invalidate(companyDetailsProvider(companyId));

      if (!context.mounted) return;
      await showTemporaryPasswordModal(
        context: context,
        title: 'Temporary Password',
        userName: result.user.name,
        userEmail: result.user.email,
        temporaryPassword: result.temporaryPassword,
      );
    } on ApiException catch (err) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err.message),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to reset manager password.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final detailsAsync = ref.watch(companyDetailsProvider(companyId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ThermoScanAppBar(
        title: 'Company Details',
        role: user?.role ?? 'system_admin',
        showBack: true,
      ),
      body: SafeArea(
        child: detailsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (err, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.error,
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    err.toString(),
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SecondaryButton(
                    label: 'Retry',
                    icon: Icons.refresh,
                    fullWidth: false,
                    onPressed: () =>
                        ref.invalidate(companyDetailsProvider(companyId)),
                  ),
                ],
              ),
            ),
          ),
          data: (details) {
            final company = details.company;
            final managers = details.managers;
            final hasAddress = company.address != null &&
                company.address!.trim().isNotEmpty;

            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                ref.invalidate(companyDetailsProvider(companyId));
                await ref.read(companyDetailsProvider(companyId).future);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Company Overview Card (SCR-06)
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
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'COMPANY OVERVIEW',
                                      style: AppTypography.caption.copyWith(
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      company.name,
                                      style: AppTypography.h2,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              StatusChip(isActive: company.isActive),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Divider(),
                          const SizedBox(height: 14),
                          _MetadataRow(
                            icon: Icons.location_on_outlined,
                            label: 'Address',
                            value: hasAddress
                                ? company.address!
                                : 'No address specified',
                          ),
                          const SizedBox(height: 10),
                          _MetadataRow(
                            icon: Icons.calendar_today_outlined,
                            label: 'Registered',
                            value: company.formattedCreatedDate,
                          ),
                          const SizedBox(height: 10),
                          _MetadataRow(
                            icon: Icons.supervisor_account_outlined,
                            label: 'Managers',
                            value:
                                '${managers.length} ${managers.length == 1 ? 'Manager' : 'Managers'}',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Assigned Managers Section
                    Text(
                      'Company Managers',
                      style: AppTypography.h3,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select a Manager to issue a one-time temporary password reset.',
                      style: AppTypography.bodySmall,
                    ),
                    const SizedBox(height: 14),

                    if (managers.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          'No Managers found for this company.',
                          style: AppTypography.bodySmall,
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: managers.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final manager = managers[index];
                          return _ManagerRowCard(
                            manager: manager,
                            onResetPassword: () => _openResetManagerDialog(
                              context,
                              ref,
                              manager,
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        SizedBox(
          width: 88,
          child: Text(label, style: AppTypography.caption),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _ManagerRowCard extends StatelessWidget {
  const _ManagerRowCard({
    required this.manager,
    required this.onResetPassword,
  });

  final CompanyManagerSummary manager;
  final VoidCallback onResetPassword;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  manager.name,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  manager.email,
                  style: AppTypography.bodySmall,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    StatusChip(isActive: manager.isActive),
                    if (manager.isDefaultManager)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          'Default Manager',
                          style: AppTypography.caption.copyWith(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (manager.mustChangePassword)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warningBackground,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.warningBorder),
                        ),
                        child: Text(
                          'Temp Password Active',
                          style: AppTypography.caption.copyWith(
                            fontSize: 11,
                            color: AppColors.warning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onResetPassword,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              backgroundColor: AppColors.background,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.lock_reset, size: 18),
            label: Text(
              'Reset',
              style: AppTypography.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// SCR-08: Reset Manager Password Confirmation Modal
class _ResetManagerConfirmationDialog extends StatelessWidget {
  const _ResetManagerConfirmationDialog({required this.manager});

  final CompanyManagerSummary manager;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.warningBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.warningBorder),
                  ),
                  child: const Icon(
                    Icons.lock_reset,
                    color: AppColors.warning,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Reset Password?',
                    style: AppTypography.h3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Generate a new temporary password for ${manager.name} (${manager.email})?',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryButton(
                    label: 'Reset',
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
