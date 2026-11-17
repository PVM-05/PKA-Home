import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../data/models/apartment_model.dart';
import '../../../../data/models/resident_model.dart';

/// Card đại diện cho 1 cư dân trên giao diện danh sách mobile
class ManagementResidentListCard extends StatelessWidget {
  final ResidentModel resident;
  final List<ApartmentModel> apartments;
  final bool isCurrentUserAdmin;
  final VoidCallback onTap;
  final VoidCallback onChangeRole;
  final VoidCallback onAssignApartment;
  final Color roleColor;
  final Widget roleChip;
  final Widget statusChip;

  const ManagementResidentListCard({
    super.key,
    required this.resident,
    required this.apartments,
    required this.isCurrentUserAdmin,
    required this.onTap,
    required this.onChangeRole,
    required this.onAssignApartment,
    required this.roleColor,
    required this.roleChip,
    required this.statusChip,
  });

  @override
  Widget build(BuildContext context) {
    final hasApartments =
        resident.apartments.isNotEmpty || resident.apartment != null;

    return AppCard(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12.0),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: roleColor.withValues(alpha: 0.15),
                child: Text(
                  resident.fullName.isNotEmpty
                      ? resident.fullName[0].toUpperCase()
                      : '?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: roleColor,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              AppSpacing.w10,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resident.fullName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    AppSpacing.h4,
                    if (resident.email != null && resident.email!.isNotEmpty)
                      Row(
                        children: [
                          const Icon(
                            Icons.email_outlined,
                            size: 13,
                            color: AppTheme.textSecondary,
                          ),
                          AppSpacing.w4,
                          Expanded(
                            child: Text(
                              resident.email!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    if (resident.phone != null && resident.phone!.isNotEmpty)
                      Row(
                        children: [
                          const Icon(
                            Icons.phone_outlined,
                            size: 13,
                            color: AppTheme.textSecondary,
                          ),
                          AppSpacing.w4,
                          Expanded(
                            child: Text(
                              resident.phone!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    AppSpacing.h4,
                    Row(
                      children: [
                        Icon(
                          hasApartments
                              ? Icons.domain
                              : Icons.domain_disabled_outlined,
                          size: 14,
                          color: hasApartments
                              ? AppTheme.success
                              : AppTheme.textSecondary,
                        ),
                        AppSpacing.w4,
                        Expanded(
                          child: Text(
                            resident.apartmentSummary,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: hasApartments
                                          ? AppTheme.success
                                          : AppTheme.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isCurrentUserAdmin)
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      iconSize: 20,
                      tooltip: 'Phân quyền vai trò',
                      icon: const Icon(
                        Icons.manage_accounts_outlined,
                        color: AppTheme.secondary,
                      ),
                      onPressed: onChangeRole,
                    ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    iconSize: 20,
                    tooltip: 'Gán căn hộ',
                    icon: const Icon(
                      Icons.add_home_work_outlined,
                      color: AppTheme.primary,
                    ),
                    onPressed: onAssignApartment,
                  ),
                ],
              ),
            ],
          ),
          AppSpacing.h6,
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              roleChip,
              statusChip,
            ],
          ),
        ],
      ),
    );
  }
}

