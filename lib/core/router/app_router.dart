import '../../features/document/screens/document_lookup_screen.dart';
import '../../features/management/screens/community_management_screen.dart';
import '../../features/management/screens/front_desk_workstation_screen.dart';
import '../../features/management/screens/maintenance_materials_screen.dart';
import '../../features/management/screens/parking_management_screen.dart';
import '../../features/management/screens/accounting_web_workstation_screen.dart';
import '../../features/management/screens/subscription_management_screen.dart';
import '../../features/management/screens/batch_import_center_screen.dart';
import '../../features/management/screens/financial_report_screen.dart';
import '../../features/management/screens/handover_management_screen.dart';
import '../../features/management/screens/inspection_workstation_screen.dart';
import '../../features/resident/screens/resident_handover_screen.dart';
import '../../features/resident/screens/resident_handover_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/permissions.dart';
import '../widgets/pdpl_consent_dialog.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/providers/link_request_provider.dart';
import '../../data/models/invoice_model.dart';
import '../../data/models/issue_model.dart';
import '../../data/models/announcement_model.dart';
import '../../data/models/building_amenity_model.dart';
import '../../data/models/building_equipment_model.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/change_password_screen.dart';
import '../../features/auth/screens/resident_activation_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/verify_otp_screen.dart';
import '../../features/auth/screens/reset_password_screen.dart';
import '../../features/auth/screens/mfa_challenge_screen.dart';
import '../../features/resident/screens/resident_home_screen.dart';
import '../../features/resident/screens/resident_invoice_screen.dart';
import '../../features/resident/screens/resident_invoice_detail_screen.dart';
import '../../features/resident/screens/resident_issue_screen.dart';
import '../../features/resident/screens/create_issue_screen.dart';
import '../../features/resident/screens/edit_issue_screen.dart';
import '../../features/resident/screens/issue_detail_screen.dart';
import '../../features/resident/screens/resident_profile_screen.dart';
import '../../features/resident/screens/link_request_screen.dart';
import '../../features/resident/screens/resident_handbook_screen.dart';
import '../../features/resident/screens/notification_center_screen.dart';
import '../../features/resident/screens/vehicle_management_screen.dart';
import '../../features/resident/screens/amenity_booking_screen.dart';
import '../../features/resident/screens/resident_amenities_screen.dart';
import '../../features/resident/screens/resident_announcement_detail_screen.dart';
import '../../features/resident/screens/payment_history_screen.dart';
import '../../features/resident/screens/resident_meter_reading_screen.dart';
import '../../features/resident/screens/resident_visitor_parcel_screen.dart';
import '../../features/resident/screens/resident_community_screen.dart';
import '../../features/management/screens/management_home_screen.dart';
import '../../features/management/screens/resident_management_screen.dart';
import '../../features/management/screens/invoice_management_screen.dart';
import '../../features/management/screens/create_invoice_screen.dart';
import '../../features/management/screens/edit_invoice_screen.dart';
import '../../features/management/screens/management_invoice_detail_screen.dart';
import '../../features/management/screens/issue_management_screen.dart';
import '../../features/management/screens/announcement_management_screen.dart';
import '../../features/management/screens/apartment_management_screen.dart';
import '../../features/management/screens/link_request_management_screen.dart';
import '../../features/management/screens/handbook_management_screen.dart';
import '../../features/management/screens/audit_trail_screen.dart';
import '../../features/management/screens/role_delegation_screen.dart';
import '../../features/management/screens/permission_matrix_screen.dart';
import '../../features/management/screens/service_rating_overview_screen.dart';
import '../../features/management/screens/amenity_management_screen.dart';
import '../../features/management/screens/equipment_management_screen.dart';
import '../../features/management/screens/equipment_detail_screen.dart';
import '../../features/management/screens/management_payment_transactions_screen.dart';
import '../../features/management/screens/vehicle_approval_screen.dart';
import '../../features/management/screens/management_meter_reading_screen.dart';
import '../../features/management/screens/maintenance_fund_ledger_screen.dart';
import 'route_names.dart';
import 'page_transitions.dart';

/// Khóa điều hướng toàn cục cho ứng dụng (hỗ trợ Deep-linking & Push Notification click)
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Hàm chuyển hướng toàn cục từ Notification callback hoặc background message
void navigateToRoute(String route) {
  final ctx = rootNavigatorKey.currentContext;
  if (ctx != null) {
    GoRouter.of(ctx).push(route);
  }
}

/// Bản đồ ánh xạ tuyến đường quản trị (/management/*) sang quyền hạn tương ứng (RBAC)
final Map<String, PermissionItem> _managementRoutePermissions = {
  AppRoutes.managementInvoices: AppPermissions.invoiceManagement,
  AppRoutes.managementPaymentTransactions: AppPermissions.paymentTransactions,
  AppRoutes.managementAccountingWorkstation: AppPermissions.accountingWorkstation,
  AppRoutes.managementMaintenanceFundLedger: AppPermissions.maintenanceFundLedger,
  AppRoutes.managementFinancialReport: AppPermissions.financialReport,
  AppRoutes.managementMeterReading: AppPermissions.meterReadingManagement,

  AppRoutes.managementIssues: AppPermissions.issueManagement,
  AppRoutes.managementEquipment: AppPermissions.equipmentManagement,
  AppRoutes.managementMaterials: AppPermissions.materialsManagement,
  AppRoutes.managementHandovers: AppPermissions.handoverManagement,

  AppRoutes.managementResidents: AppPermissions.residentManagement,
  AppRoutes.managementApartments: AppPermissions.apartmentManagement,
  AppRoutes.managementLinkRequests: AppPermissions.linkRequestManagement,
  AppRoutes.managementVehicleApproval: AppPermissions.vehicleApproval,
  AppRoutes.managementBatchImport: AppPermissions.batchImport,
  AppRoutes.managementParking: AppPermissions.parkingManagement,

  AppRoutes.managementAmenities: AppPermissions.amenityManagement,
  AppRoutes.managementHandbook: AppPermissions.handbookManagement,
  AppRoutes.managementAnnouncements: AppPermissions.announcementManagement,
  AppRoutes.managementFrontDesk: AppPermissions.frontDeskWorkstation,
  AppRoutes.managementCommunity: AppPermissions.communityManagement,
  AppRoutes.managementServiceRatings: AppPermissions.serviceRatingOverview,
  AppRoutes.managementAuditTrail: AppPermissions.auditTrail,
  AppRoutes.managementRoleDelegation: AppPermissions.roleDelegation,
  AppRoutes.managementPermissionMatrix: AppPermissions.permissionMatrix,
  AppRoutes.managementSubscription: AppPermissions.subscriptionManagement,
};

PermissionItem? _findRoutePermission(String location) {
  if (_managementRoutePermissions.containsKey(location)) {
    return _managementRoutePermissions[location];
  }
  for (final entry in _managementRoutePermissions.entries) {
    if (entry.key != AppRoutes.managementHome && location.startsWith(entry.key)) {
      return entry.value;
    }
  }
  return null;
}

/// Provider cho GoRouter, lắng nghe auth state để redirect tự động.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.login,
    debugLogDiagnostics: true,
    refreshListenable: GoRouterAuthNotifier(ref),
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final user = authState.valueOrNull;
      final isLoggedIn = user != null;
      final isAuthRoute = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register ||
          state.matchedLocation == AppRoutes.residentActivation ||
          state.matchedLocation == AppRoutes.forgotPassword;
      final isPublicRoute = state.matchedLocation == AppRoutes.documentLookup;
      final isRecoveryRoute = state.matchedLocation == AppRoutes.verifyOtp ||
          state.matchedLocation == AppRoutes.resetPassword;
      final needsMfa = ref.read(mfaChallengeRequiredProvider);

      // Đang loading auth state → không redirect
      if (authState.isLoading) return null;

      // Tuyến công khai (tra cứu xác thực hóa đơn/biên lai điện tử qua QR)
      if (isPublicRoute) return null;

      // Đang trong luồng khôi phục mật khẩu (xác thực OTP hoặc đặt lại mật khẩu) → không tự redirect ra trang chủ
      if (isRecoveryRoute) return null;

      // Phiên đăng nhập đang ở cấp độ AAL1 nhưng tài khoản yêu cầu AAL2 (MFA TOTP Gate)
      if (isLoggedIn && needsMfa) {
        if (state.matchedLocation != AppRoutes.mfaChallenge) {
          return AppRoutes.mfaChallenge;
        }
        return null;
      }
      if (isLoggedIn && !needsMfa && state.matchedLocation == AppRoutes.mfaChallenge) {
        return user.isManagement ? AppRoutes.managementHome : AppRoutes.residentHome;
      }

      // Chưa đăng nhập → về login
      if (!isLoggedIn && !isAuthRoute) return AppRoutes.login;

      // Đã đăng nhập nhưng đang ở trang auth → redirect theo role
      if (isLoggedIn && isAuthRoute) {
        if (user.isManagement) return AppRoutes.managementHome;
        return AppRoutes.residentHome;
      }

      // Cư dân không được phép truy cập vào khu vực quản trị (/management/*)
      if (isLoggedIn && !user.isManagement && state.matchedLocation.startsWith('/management')) {
        return AppRoutes.residentHome;
      }

      // Quản lý/Nhân viên: Kiểm tra quyền hạn chi tiết (RBAC) theo tuyến đường
      if (isLoggedIn && user.isManagement && state.matchedLocation.startsWith('/management')) {
        final requiredPerm = _findRoutePermission(state.matchedLocation);
        if (requiredPerm != null && !requiredPerm.allows(user.role)) {
          return AppRoutes.managementHome;
        }
      }

      return null;
    },
    routes: [
      // ─── Auth Routes ───
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) => AppPageTransitions.fade(
          state: state,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.register,
        pageBuilder: (context, state) => AppPageTransitions.slideUp(
          state: state,
          child: const RegisterScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.residentActivation,
        pageBuilder: (context, state) => AppPageTransitions.slideFromRight(
          state: state,
          child: const ResidentActivationScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.changePassword,
        pageBuilder: (context, state) => AppPageTransitions.slideFromRight(
          state: state,
          child: const ChangePasswordScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        pageBuilder: (context, state) => AppPageTransitions.slideFromRight(
          state: state,
          child: const ForgotPasswordScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.verifyOtp,
        pageBuilder: (context, state) {
          final email = (state.extra as String?) ?? '';
          return AppPageTransitions.slideFromRight(
            state: state,
            child: VerifyOtpScreen(email: email),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        pageBuilder: (context, state) => AppPageTransitions.slideFromRight(
          state: state,
          child: const ResetPasswordScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.mfaChallenge,
        pageBuilder: (context, state) => AppPageTransitions.fade(
          state: state,
          child: const MfaChallengeScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.documentLookup,
        pageBuilder: (context, state) {
          final initialCode = state.uri.queryParameters['code'] ??
              (state.extra is String ? state.extra as String : null);
          return AppPageTransitions.fade(
            state: state,
            child: DocumentLookupScreen(initialLookupCode: initialCode),
          );
        },
      ),

      // ─── Resident Routes ───
      GoRoute(
        path: AppRoutes.residentHome,
        pageBuilder: (context, state) => AppPageTransitions.fade(
          state: state,
          child: const _ResidentShellWrapper(),
        ),
        routes: [
          GoRoute(
            path: 'invoices',
            pageBuilder: (context, state) => AppPageTransitions.slideFromRight(
              state: state,
              child: const ResidentInvoiceScreen(),
            ),
            routes: [
              GoRoute(
                path: 'detail',
                pageBuilder: (context, state) {
                  final invoice = state.extra is InvoiceModel ? state.extra as InvoiceModel : null;
                  if (invoice == null) {
                    return _missingExtraFallbackPage(
                      state: state,
                      fallbackRoute: AppRoutes.residentInvoices,
                      label: 'Quay lại danh sách hóa đơn',
                    );
                  }
                  return AppPageTransitions.slideFromRight(
                    state: state,
                    child: ResidentInvoiceDetailScreen(invoice: invoice),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: 'issues',
            pageBuilder: (context, state) => AppPageTransitions.slideFromRight(
              state: state,
              child: const ResidentIssueScreen(),
            ),
            routes: [
              GoRoute(
                path: 'create',
                pageBuilder: (context, state) =>
                    AppPageTransitions.slideUp(
                  state: state,
                  child: const CreateIssueScreen(),
                ),
              ),
              GoRoute(
                path: 'edit',
                pageBuilder: (context, state) {
                  final issue = state.extra is IssueModel ? state.extra as IssueModel : null;
                  if (issue == null) {
                    return _missingExtraFallbackPage(
                      state: state,
                      fallbackRoute: AppRoutes.residentIssues,
                      label: 'Quay lại danh sách phản ánh',
                    );
                  }
                  return AppPageTransitions.slideFromRight(
                    state: state,
                    child: EditIssueScreen(issue: issue),
                  );
                },
              ),
              GoRoute(
                path: 'detail',
                pageBuilder: (context, state) {
                  final issue = state.extra is IssueModel ? state.extra as IssueModel : null;
                  if (issue == null) {
                    return _missingExtraFallbackPage(
                      state: state,
                      fallbackRoute: AppRoutes.residentIssues,
                      label: 'Quay lại danh sách phản ánh',
                    );
                  }
                  return AppPageTransitions.slideFromRight(
                    state: state,
                    child: IssueDetailScreen(issue: issue),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: 'profile',
            pageBuilder: (context, state) => AppPageTransitions.slideFromRight(
              state: state,
              child: const ResidentProfileScreen(),
            ),
          ),
          GoRoute(
            path: 'link-request',
            pageBuilder: (context, state) => AppPageTransitions.slideUp(
              state: state,
              child: const LinkRequestScreen(),
            ),
          ),
          GoRoute(
            path: 'handbook',
            pageBuilder: (context, state) {
              final tabIndex = state.extra as int? ?? 0;
              return AppPageTransitions.slideFromRight(
                state: state,
                child: ResidentHandbookScreen(initialTabIndex: tabIndex),
              );
            },
          ),
          GoRoute(
            path: 'notifications',
            pageBuilder: (context, state) => AppPageTransitions.slideFromRight(
              state: state,
              child: const NotificationCenterScreen(),
            ),
          ),
          GoRoute(
            path: 'vehicles',
            pageBuilder: (context, state) => AppPageTransitions.slideFromRight(
              state: state,
              child: const VehicleManagementScreen(),
            ),
          ),
          GoRoute(
            path: 'amenities',
            pageBuilder: (context, state) => AppPageTransitions.slideFromRight(
              state: state,
              child: const ResidentAmenitiesScreen(),
            ),
          ),
          GoRoute(
            path: 'amenity-booking',
            pageBuilder: (context, state) {
              final amenity = state.extra is BuildingAmenityModel
                  ? state.extra as BuildingAmenityModel
                  : null;
              if (amenity == null) {
                return _missingExtraFallbackPage(
                  state: state,
                  fallbackRoute: AppRoutes.residentAmenities,
                  label: 'Quay lại danh sách tiện ích',
                );
              }
              return AppPageTransitions.slideFromRight(
                state: state,
                child: AmenityBookingScreen(amenity: amenity),
              );
            },
          ),
          GoRoute(
            path: 'announcement',
            pageBuilder: (context, state) {
              final announcement = state.extra is AnnouncementModel
                  ? state.extra as AnnouncementModel
                  : null;
              if (announcement == null) {
                return _missingExtraFallbackPage(
                  state: state,
                  fallbackRoute: AppRoutes.residentHome,
                  label: 'Quay lại trang chủ',
                );
              }
              return AppPageTransitions.slideFromRight(
                state: state,
                child: ResidentAnnouncementDetailScreen(
                  announcement: announcement,
                ),
              );
            },
          ),
          GoRoute(
            path: 'payment-history',
            pageBuilder: (context, state) => AppPageTransitions.slideFromRight(
              state: state,
              child: const PaymentHistoryScreen(),
            ),
          ),
          GoRoute(
            path: 'visitor-parcel',
            pageBuilder: (context, state) => AppPageTransitions.slideFromRight(
              state: state,
              child: const ResidentVisitorParcelScreen(),
            ),
          ),
          GoRoute(
            path: 'community',
            pageBuilder: (context, state) => AppPageTransitions.slideFromRight(
              state: state,
              child: const ResidentCommunityScreen(),
            ),
          ),
          GoRoute(
            path: 'meter-reading',
            pageBuilder: (context, state) => AppPageTransitions.slideFromRight(
              state: state,
              child: const ResidentMeterReadingScreen(),
            ),
          ),
          GoRoute(
            path: 'handovers',
            pageBuilder: (context, state) => AppPageTransitions.slideFromRight(
              state: state,
              child: const ResidentHandoverScreen(),
            ),
            routes: [
              GoRoute(
                path: 'detail',
                pageBuilder: (context, state) {
                  final handoverId = (state.extra as String?) ??
                      state.uri.queryParameters['id'] ??
                      '';
                  return AppPageTransitions.slideFromRight(
                    state: state,
                    child: ResidentHandoverDetailScreen(handoverId: handoverId),
                  );
                },
              ),
            ],
          ),
        ],
      ),

      // ─── Management Routes ───
      GoRoute(
        path: AppRoutes.managementHome,
        pageBuilder: (context, state) => AppPageTransitions.fade(
          state: state,
          child: const ManagementHomeScreen(),
        ),
        routes: [
          GoRoute(
            path: 'residents',
            pageBuilder: (context, state) =>
                AppPageTransitions.slideFromRight(
              state: state,
              child: const ResidentManagementScreen(),
            ),
          ),
          GoRoute(
            path: 'invoices',
            pageBuilder: (context, state) =>
                AppPageTransitions.slideFromRight(
              state: state,
              child: const InvoiceManagementScreen(),
            ),
            routes: [
              GoRoute(
                path: 'create',
                pageBuilder: (context, state) =>
                    AppPageTransitions.slideUp(
                  state: state,
                  child: const CreateInvoiceScreen(),
                ),
              ),
              GoRoute(
                path: 'edit',
                pageBuilder: (context, state) {
                  final invoice = state.extra is InvoiceModel ? state.extra as InvoiceModel : null;
                  if (invoice == null) {
                    return _missingExtraFallbackPage(
                      state: state,
                      fallbackRoute: AppRoutes.managementInvoices,
                      label: 'Quay lại quản lý hóa đơn',
                    );
                  }
                  return AppPageTransitions.slideFromRight(
                    state: state,
                    child: EditInvoiceScreen(invoice: invoice),
                  );
                },
              ),
              GoRoute(
                path: 'detail',
                pageBuilder: (context, state) {
                  final invoice = state.extra is InvoiceModel ? state.extra as InvoiceModel : null;
                  if (invoice == null) {
                    return _missingExtraFallbackPage(
                      state: state,
                      fallbackRoute: AppRoutes.managementInvoices,
                      label: 'Quay lại quản lý hóa đơn',
                    );
                  }
                  return AppPageTransitions.slideFromRight(
                    state: state,
                    child:
                        ManagementInvoiceDetailScreen(invoice: invoice),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: 'issues',
            pageBuilder: (context, state) =>
                AppPageTransitions.slideFromRight(
              state: state,
              child: const IssueManagementScreen(),
            ),
            routes: [
              GoRoute(
                path: 'detail',
                pageBuilder: (context, state) {
                  final issue = state.extra is IssueModel ? state.extra as IssueModel : null;
                  if (issue == null) {
                    return _missingExtraFallbackPage(
                      state: state,
                      fallbackRoute: AppRoutes.managementIssues,
                      label: 'Quay lại quản lý sự cố',
                    );
                  }
                  return AppPageTransitions.slideFromRight(
                    state: state,
                    child: IssueDetailScreen(issue: issue),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: 'announcements',
            pageBuilder: (context, state) =>
                AppPageTransitions.slideFromRight(
              state: state,
              child: const AnnouncementManagementScreen(),
            ),
          ),
          GoRoute(
            path: 'apartments',
            pageBuilder: (context, state) =>
                AppPageTransitions.slideFromRight(
              state: state,
              child: const ApartmentManagementScreen(),
            ),
          ),
          GoRoute(
            path: 'link-requests',
            pageBuilder: (context, state) =>
                AppPageTransitions.slideFromRight(
              state: state,
              child: const LinkRequestManagementScreen(),
            ),
          ),
          GoRoute(
            path: 'handbook',
            pageBuilder: (context, state) =>
                AppPageTransitions.slideFromRight(
              state: state,
              child: const HandbookManagementScreen(),
            ),
          ),
          GoRoute(
            path: 'audit-trail',
            pageBuilder: (context, state) =>
                AppPageTransitions.slideFromRight(
              state: state,
              child: const AuditTrailScreen(),
            ),
          ),
          GoRoute(
            path: 'notifications',
            pageBuilder: (context, state) =>
                AppPageTransitions.slideFromRight(
              state: state,
              child: const NotificationCenterScreen(),
            ),
          ),
          GoRoute(
            path: 'role-delegation',
            pageBuilder: (context, state) =>
                AppPageTransitions.slideFromRight(
              state: state,
              child: const RoleDelegationScreen(),
            ),
          ),
          GoRoute(
            path: 'permission-matrix',
            pageBuilder: (context, state) =>
                AppPageTransitions.slideFromRight(
              state: state,
              child: const PermissionMatrixScreen(),
            ),
          ),
          GoRoute(
            path: 'service-ratings',
            pageBuilder: (context, state) =>
                AppPageTransitions.slideFromRight(
              state: state,
              child: const ServiceRatingOverviewScreen(),
            ),
          ),
          GoRoute(
            path: 'amenities',
            pageBuilder: (context, state) =>
                AppPageTransitions.slideFromRight(
              state: state,
              child: const AmenityManagementScreen(),
            ),
          ),
          GoRoute(
            path: 'equipment',
            pageBuilder: (context, state) =>
                AppPageTransitions.slideFromRight(
              state: state,
              child: const EquipmentManagementScreen(),
            ),
            routes: [
              GoRoute(
                path: 'detail',
                pageBuilder: (context, state) {
                  final equipment = state.extra is BuildingEquipmentModel
                      ? state.extra as BuildingEquipmentModel
                      : null;
                  if (equipment == null) {
                    return _missingExtraFallbackPage(
                      state: state,
                      fallbackRoute: AppRoutes.managementEquipment,
                      label: 'Quay lại danh sách thiết bị',
                    );
                  }
                  return AppPageTransitions.slideFromRight(
                    state: state,
                    child: EquipmentDetailScreen(equipment: equipment),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: 'payment-transactions',
            pageBuilder: (context, state) =>
                AppPageTransitions.slideFromRight(
              state: state,
              child: const ManagementPaymentTransactionsScreen(),
            ),
          ),
          GoRoute(
            path: 'vehicle-approval',
            pageBuilder: (context, state) =>
                AppPageTransitions.slideFromRight(
              state: state,
              child: const VehicleApprovalScreen(),
            ),
          ),
          GoRoute(
            path: 'meter-readings',
            pageBuilder: (context, state) =>
                AppPageTransitions.slideFromRight(
              state: state,
              child: const ManagementMeterReadingScreen(),
            ),
          ),
          GoRoute(
            path: 'maintenance-fund-ledger',
            pageBuilder: (context, state) =>
                AppPageTransitions.slideFromRight(
              state: state,
              child: const MaintenanceFundLedgerScreen(),
            ),
          ),
          GoRoute(
            path: 'financial-report',
            pageBuilder: (context, state) =>
                AppPageTransitions.slideFromRight(
              state: state,
              child: const FinancialReportScreen(),
            ),
          ),
          GoRoute(
            path: 'batch-import',
            pageBuilder: (context, state) =>
                AppPageTransitions.slideFromRight(
              state: state,
              child: const BatchImportCenterScreen(),
            ),
          ),
          GoRoute(
            path: 'subscription',
            pageBuilder: (context, state) =>
                AppPageTransitions.slideFromRight(
              state: state,
              child: const SubscriptionManagementScreen(),
            ),
          ),
          GoRoute(
            path: 'accounting-workstation',
            pageBuilder: (context, state) =>
                AppPageTransitions.slideFromRight(
              state: state,
              child: const AccountingWebWorkstationScreen(),
            ),
          ),
          GoRoute(
            path: 'parking',
            pageBuilder: (context, state) =>
                AppPageTransitions.slideFromRight(
              state: state,
              child: const ParkingManagementScreen(),
            ),
          ),
          GoRoute(
            path: 'front-desk',
            pageBuilder: (context, state) =>
                AppPageTransitions.slideFromRight(
              state: state,
              child: const FrontDeskWorkstationScreen(),
            ),
          ),
          GoRoute(
            path: 'community',
            pageBuilder: (context, state) =>
                AppPageTransitions.slideFromRight(
              state: state,
              child: const CommunityManagementScreen(),
            ),
          ),
          GoRoute(
            path: 'materials',
            pageBuilder: (context, state) =>
                AppPageTransitions.slideFromRight(
              state: state,
              child: const MaintenanceMaterialsScreen(),
            ),
          ),
          GoRoute(
            path: 'handovers',
            pageBuilder: (context, state) =>
                AppPageTransitions.slideFromRight(
              state: state,
              child: const HandoverManagementScreen(),
            ),
            routes: [
              GoRoute(
                path: 'workstation',
                pageBuilder: (context, state) {
                  final extra = state.extra is Map<String, dynamic>
                      ? state.extra as Map<String, dynamic>
                      : null;
                  final buildingId = extra?['buildingId'] as String?;
                  final apartmentId = extra?['apartmentId'] as String?;
                  final apartmentCode = extra?['apartmentCode'] as String?;
                  if (buildingId == null || apartmentId == null || apartmentCode == null) {
                    return _missingExtraFallbackPage(
                      state: state,
                      fallbackRoute: AppRoutes.managementHandovers,
                      label: 'Quay lại quản lý bàn giao',
                    );
                  }
                  return AppPageTransitions.slideFromRight(
                    state: state,
                    child: InspectionWorkstationScreen(
                      buildingId: buildingId,
                      apartmentId: apartmentId,
                      apartmentCode: apartmentCode,
                      initialType: extra?['initialType'] as String?,
                      existingHandoverId: extra?['existingHandoverId'] as String?,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    ],
    errorPageBuilder: (context, state) => MaterialPage(
      child: Scaffold(
        appBar: AppBar(title: const Text('Không tìm thấy trang')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'Trang "${state.matchedLocation}" không tồn tại.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go(AppRoutes.login),
                child: const Text('Về trang chủ'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
});

Page<void> _missingExtraFallbackPage({
  required GoRouterState state,
  required String fallbackRoute,
  required String label,
}) {
  return AppPageTransitions.fade(
    state: state,
    child: Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Phiên dữ liệu đã làm mới')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.refresh_rounded,
                  size: 56,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  'Dữ liệu chi tiết không còn trong bộ nhớ trình duyệt sau khi tải lại trang.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => context.go(fallbackRoute),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: Text(label),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Wrapper để kiểm tra link status của cư dân trước khi hiển thị
/// home screen. Nếu chưa liên kết → hiển thị LinkRequestScreen.
class _ResidentShellWrapper extends ConsumerWidget {
  const _ResidentShellWrapper();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        PdplConsentManager.showConsentDialogIfNeeded(context);
      }
    });

    final linkState = ref.watch(residentLinkProvider);

    if (linkState.status == LinkStatus.loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (linkState.status == LinkStatus.linked) {
      return const ResidentHomeScreen();
    }

    return const LinkRequestScreen();
  }
}

/// Notifier giúp GoRouter lắng nghe thay đổi auth state và MFA challenge state.
class GoRouterAuthNotifier extends ChangeNotifier {
  GoRouterAuthNotifier(this._ref) {
    _ref.listen(authProvider, (prev, next) {
      notifyListeners();
    });
    _ref.listen(mfaChallengeRequiredProvider, (prev, next) {
      notifyListeners();
    });
  }

  final Ref _ref;
}
