import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thermoscan/core/theme/app_colors.dart';
import 'package:thermoscan/core/theme/app_typography.dart';
import 'package:thermoscan/core/widgets/app_buttons.dart';
import 'package:thermoscan/core/widgets/status_chips.dart';
import 'package:thermoscan/core/widgets/top_app_bar.dart';
import 'package:thermoscan/features/auth/presentation/auth_controller.dart';
import 'package:thermoscan/features/modules/data/module_repository.dart';
import 'package:thermoscan/features/modules/domain/module_models.dart';
import 'package:thermoscan/features/modules/presentation/modules_controller.dart';

/// SCR-14: Module Access and Responsible Managers (Manager only)
class ModuleAccessScreen extends ConsumerStatefulWidget {
  const ModuleAccessScreen({
    super.key,
    required this.moduleId,
  });

  final String moduleId;

  @override
  ConsumerState<ModuleAccessScreen> createState() => _ModuleAccessScreenState();
}

class _ModuleAccessScreenState extends ConsumerState<ModuleAccessScreen> {
  final Set<String> _selectedManagerIds = {};
  final Set<String> _selectedClientIds = {};
  bool _initialized = false;

  bool _savingManagers = false;
  bool _savingClients = false;
  String? _togglingTechId;

  void _syncSelections(ModuleDetails details) {
    if (_initialized) return;
    _initialized = true;
    _selectedManagerIds
      ..clear()
      ..addAll(details.responsibleManagers.map((m) => m.id));
    _selectedClientIds
      ..clear()
      ..addAll(
        details.companyClients.where((c) => c.isAssigned).map((c) => c.id),
      );
  }

  Future<void> _saveResponsibleManagers() async {
    if (_selectedManagerIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('At least one active responsible Manager must remain assigned.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _savingManagers = true);
    try {
      final updated =
          await ref.read(moduleRepositoryProvider).setModuleManagers(
                moduleId: widget.moduleId,
                managerIds: _selectedManagerIds.toList(),
              );
      _initialized = false;
      _syncSelections(updated);
      ref.invalidate(moduleDetailsProvider(widget.moduleId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Responsible Managers updated.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err.toString()),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _savingManagers = false);
      }
    }
  }

  Future<void> _toggleTechnicianAccess(
    ModuleTechnicianAccess tech,
    bool canView,
  ) async {
    setState(() => _togglingTechId = tech.id);
    try {
      await ref.read(moduleRepositoryProvider).setTechnicianAccess(
            moduleId: widget.moduleId,
            technicianId: tech.id,
            canView: canView,
          );
      ref.invalidate(moduleDetailsProvider(widget.moduleId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            canView
                ? 'Access granted to ${tech.name}.'
                : 'Access revoked for ${tech.name}.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err.toString()),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _togglingTechId = null);
      }
    }
  }

  Future<void> _saveAssignedClients() async {
    setState(() => _savingClients = true);
    try {
      final updated =
          await ref.read(moduleRepositoryProvider).setModuleClients(
                moduleId: widget.moduleId,
                clientIds: _selectedClientIds.toList(),
              );
      _initialized = false;
      _syncSelections(updated);
      ref.invalidate(moduleDetailsProvider(widget.moduleId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assigned Clients updated.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err.toString()),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _savingClients = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    final detailsAsync = ref.watch(moduleDetailsProvider(widget.moduleId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ThermoScanAppBar(
        title: 'Module Access',
        role: user?.role ?? 'manager',
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
              child: Text(err.toString(), style: AppTypography.body),
            ),
          ),
          data: (details) {
            _syncSelections(details);
            final mod = details.module;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mod.name,
                    style: AppTypography.h2,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage responsible Managers, Technician permissions, and assigned Clients.',
                    style: AppTypography.bodySmall,
                  ),
                  const SizedBox(height: 20),

                  // 1. Responsible Managers Section
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
                        Text(
                          'Responsible Managers',
                          style: AppTypography.h3,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Every module must have at least one active responsible Manager.',
                          style: AppTypography.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        ...details.companyManagers.map((mgr) {
                          final selected = _selectedManagerIds.contains(mgr.id);
                          return CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            activeColor: AppColors.primary,
                            value: selected,
                            onChanged: (val) {
                              setState(() {
                                if (val ?? false) {
                                  _selectedManagerIds.add(mgr.id);
                                } else {
                                  _selectedManagerIds.remove(mgr.id);
                                }
                              });
                            },
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    mgr.name,
                                    style: AppTypography.body.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (mgr.isDefaultManager) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primarySoft,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      'Default',
                                      style: AppTypography.chip.copyWith(
                                        fontSize: 10,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(
                              mgr.email,
                              style: AppTypography.caption,
                            ),
                          );
                        }),
                        const SizedBox(height: 12),
                        PrimaryButton(
                          label: 'Save Responsible Managers',
                          icon: Icons.supervisor_account_outlined,
                          isLoading: _savingManagers,
                          onPressed: _saveResponsibleManagers,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Technician Access Section
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
                        Text(
                          'Technician Access',
                          style: AppTypography.h3,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Grant or revoke viewing permission for company Technicians. Revoking the installer blocks their data and configuration access while preserving installation history; regranting restores installer editing rights.',
                          style: AppTypography.bodySmall,
                        ),
                        const SizedBox(height: 14),
                        if (details.companyTechnicians.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              'No Technicians registered in your company yet.',
                              style: AppTypography.bodySmall,
                            ),
                          )
                        else
                          ...details.companyTechnicians.map((tech) {
                            final isBusy = _togglingTechId == tech.id;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                tech.name,
                                                style: AppTypography.body
                                                    .copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            if (tech.isInstaller) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primarySoft,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          999),
                                                ),
                                                child: Text(
                                                  'Installer',
                                                  style: AppTypography.chip
                                                      .copyWith(
                                                    fontSize: 10,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          tech.email,
                                          style: AppTypography.caption,
                                        ),
                                        const SizedBox(height: 6),
                                        StatusChip(isActive: tech.isActive),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    activeThumbColor: AppColors.primary,
                                    value: tech.canView,
                                    onChanged: isBusy
                                        ? null
                                        : (val) =>
                                            _toggleTechnicianAccess(tech, val),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Assigned Clients Section
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
                        Text(
                          'Assigned Clients',
                          style: AppTypography.h3,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Assigned Clients can view this module and update its inspection interval.',
                          style: AppTypography.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        if (details.companyClients.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              'No Clients registered in your company yet.',
                              style: AppTypography.bodySmall,
                            ),
                          )
                        else ...[
                          ...details.companyClients.map((client) {
                            final selected =
                                _selectedClientIds.contains(client.id);
                            return CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              activeColor: AppColors.primary,
                              value: selected,
                              onChanged: (val) {
                                setState(() {
                                  if (val ?? false) {
                                    _selectedClientIds.add(client.id);
                                  } else {
                                    _selectedClientIds.remove(client.id);
                                  }
                                });
                              },
                              title: Text(
                                client.name,
                                style: AppTypography.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                client.email,
                                style: AppTypography.caption,
                              ),
                            );
                          }),
                          const SizedBox(height: 12),
                          PrimaryButton(
                            label: 'Save Assigned Clients',
                            icon: Icons.groups_outlined,
                            isLoading: _savingClients,
                            onPressed: _saveAssignedClients,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
