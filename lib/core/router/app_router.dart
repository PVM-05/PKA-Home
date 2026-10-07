import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/verify_otp_screen.dart';
import '../../features/auth/screens/reset_password_screen.dart';
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
import '../../features/resident/screens/resident_announcement_detail_screen.dart';
import '../../features/resident/screens/payment_history_screen.dart';
import '../../features/resident/screens/resident_meter_reading_screen.dart';
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
import 'route_names.dart';
import 'page_transitions.dart';

/// Provider cho GoRouter, lắng nghe auth state để redirect tự động.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.login,
    debugLogDiagnostics: true,
    refreshListenable: GoRouterAuthNotifier(ref),
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final user = authState.valueOrNull;
      final isLoggedIn = user != null;
      final isAuthRoute = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register ||
          state.matchedLocation == AppRoutes.forgotPassword;
      final isRecoveryRoute = state.matchedLocation == AppRoutes.verifyOtp ||
          state.matchedLocation == AppRoutes.resetPassword;

      // Đang loading auth state → không redirect
      if (authState.isLoading) return null;

      // Đang trong luồng khôi phục mật khẩu (xác thực OTP hoặc đặt lại mật khẩu) → không tự redirect ra trang chủ
      if (isRecoveryRoute) return null;

      // Chưa đăng nhập → về login
      if (!isLoggedIn && !isAuthRoute) return AppRoutes.login;

      // Đã đăng nhập nhưng đang ở trang auth → redirect theo role
      if (isLoggedIn && isAuthRoute) {
        if (user.isManagement) return AppRoutes.managementHome;
        return AppRoutes.residentHome;
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
                  final invoice = state.extra as InvoiceModel;
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
                  final issue = state.extra as IssueModel;
                  return AppPageTransitions.slideFromRight(
                    state: state,
                    child: EditIssueScreen(issue: issue),
                  );
                },
              ),
              GoRoute(
                path: 'detail',
                pageBuilder: (context, state) {
                  final issue = state.extra as IssueModel;
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
            path: 'amenity-booking',
            pageBuilder: (context, state) {
              final amenity = state.extra as BuildingAmenityModel;
              return AppPageTransitions.slideFromRight(
                state: state,
                child: AmenityBookingScreen(amenity: amenity),
              );
            },
          ),
          GoRoute(
            path: 'announcement',
            pageBuilder: (context, state) {
              final announcement = state.extra as AnnouncementModel;
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
            path: 'meter-reading',
            pageBuilder: (context, state) => AppPageTransitions.slideFromRight(
              state: state,
              child: const ResidentMeterReadingScreen(),
            ),
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
                  final invoice = state.extra as InvoiceModel;
                  return AppPageTransitions.slideFromRight(
                    state: state,
                    child: EditInvoiceScreen(invoice: invoice),
                  );
                },
              ),
              GoRoute(
                path: 'detail',
                pageBuilder: (context, state) {
                  final invoice = state.extra as InvoiceModel;
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
                  final issue = state.extra as IssueModel;
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
                  final equipment = state.extra as BuildingEquipmentModel;
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
              const Icon(Icons.error_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Trang "${state.matchedLocation}" không tồn tại.',
                style: const TextStyle(fontSize: 16),
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

/// Wrapper để kiểm tra link status của cư dân trước khi hiển thị
/// home screen. Nếu chưa liên kết → hiển thị LinkRequestScreen.
class _ResidentShellWrapper extends ConsumerWidget {
  const _ResidentShellWrapper();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

/// Notifier giúp GoRouter lắng nghe thay đổi auth state.
class GoRouterAuthNotifier extends ChangeNotifier {
  GoRouterAuthNotifier(this._ref) {
    _ref.listen(authProvider, (prev, next) {
      notifyListeners();
    });
  }

  final Ref _ref;
}
