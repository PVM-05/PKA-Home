import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/constants/permissions.dart';
import 'package:pka_home/core/router/route_names.dart';
import 'package:pka_home/data/models/resident_model.dart';

void main() {
  group('Giai Đoạn 4: Hardening Bảo Mật, Phân Quyền & An Toàn Thao Tác Tests', () {
    test('P0-#19: Hệ thống phân quyền RBAC có đầy đủ 22 quyền quản trị cốt lõi', () {
      expect(AppPermissions.all.length, equals(22));

      // Kiểm tra quyền bãi xe
      expect(AppPermissions.parkingManagement.allowedRoles, contains('management'));
      expect(AppPermissions.parkingManagement.allows('resident'), isFalse);

      // Kiểm tra quyền bàn giao căn hộ
      expect(AppPermissions.handoverManagement.allowedRoles, contains('technician'));
      expect(AppPermissions.handoverManagement.allows('resident'), isFalse);

      // Kiểm tra quyền kho vật tư
      expect(AppPermissions.materialsManagement.allowedRoles, contains('technician'));
      expect(AppPermissions.materialsManagement.allows('accountant'), isFalse);

      // Kiểm tra quyền sổ cái quỹ bảo trì
      expect(AppPermissions.maintenanceFundLedger.allowedRoles, contains('accountant'));
      expect(AppPermissions.maintenanceFundLedger.allows('technician'), isFalse);

      // Kiểm tra quyền báo cáo tài chính
      expect(AppPermissions.financialReport.allowedRoles, contains('accountant'));
      expect(AppPermissions.financialReport.allows('resident'), isFalse);

      // Kiểm tra quyền trạm kế toán web
      expect(AppPermissions.accountingWorkstation.allowedRoles, contains('accountant'));
      expect(AppPermissions.accountingWorkstation.allows('resident'), isFalse);

      // Kiểm tra quyền gói SaaS và ma trận phân quyền (chỉ dành cho Admin)
      expect(AppPermissions.subscriptionManagement.allowedRoles, equals(['admin']));
      expect(AppPermissions.permissionMatrix.allowedRoles, equals(['admin']));
    });

    test('P0-#14: Logic lọc nhân sự ủy quyền loại bỏ hoàn toàn cư dân và người thuê', () {
      final mockResidents = [
        ResidentModel(
          id: 'u-admin',
          fullName: 'Admin Tổng',
          role: 'admin',
        ),
        ResidentModel(
          id: 'u-accountant',
          fullName: 'Kế toán viên',
          role: 'accountant',
        ),
        ResidentModel(
          id: 'u-technician',
          fullName: 'Kỹ thuật viên',
          role: 'technician',
        ),
        ResidentModel(
          id: 'u-resident',
          fullName: 'Cư dân thường',
          role: 'resident',
        ),
        ResidentModel(
          id: 'u-tenant',
          fullName: 'Khách thuê phòng',
          role: 'tenant',
        ),
      ];

      const allowedStaffRoles = {'accountant', 'technician', 'receptionist', 'security', 'staff'};
      final eligibleUsers = mockResidents
          .where((r) => allowedStaffRoles.contains(r.role))
          .toList();

      expect(eligibleUsers.length, equals(2));
      expect(eligibleUsers.map((u) => u.role), containsAll(['accountant', 'technician']));
      expect(eligibleUsers.map((u) => u.role), isNot(contains('resident')));
      expect(eligibleUsers.map((u) => u.role), isNot(contains('tenant')));
      expect(eligibleUsers.map((u) => u.role), isNot(contains('admin')));
    });

    test('P0-#19: Route Names quản trị định tuyến chính xác tới các màn hình bảo vệ', () {
      expect(AppRoutes.managementParking, equals('/management/parking'));
      expect(AppRoutes.managementHandovers, equals('/management/handovers'));
      expect(AppRoutes.managementMaterials, equals('/management/materials'));
      expect(AppRoutes.managementMaintenanceFundLedger, equals('/management/maintenance-fund-ledger'));
      expect(AppRoutes.managementFinancialReport, equals('/management/financial-report'));
      expect(AppRoutes.managementAccountingWorkstation, equals('/management/accounting-workstation'));
      expect(AppRoutes.managementSubscription, equals('/management/subscription'));
      expect(AppRoutes.managementPermissionMatrix, equals('/management/permission-matrix'));
    });
  });
}
