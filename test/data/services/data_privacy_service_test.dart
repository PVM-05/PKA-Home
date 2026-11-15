import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/services/data_privacy_service.dart';

class MockDataPrivacySource extends Mock implements DataPrivacySource {}

void main() {
  late MockDataPrivacySource mockSource;

  setUp(() {
    mockSource = MockDataPrivacySource();
  });

  group('DataPrivacyService PDPL Compliance Tests', () {
    final testUser = UserModel(
      id: 'user-pdpl-123',
      fullName: 'Trần Cư Dân',
      phone: '0988776655',
      role: 'resident',
    );

    test('exportUserData xuất đúng cấu trúc chuẩn PDPL và mã băm SHA-256 toàn vẹn', () async {
      when(() => mockSource.fetchApartments(testUser.id)).thenAnswer((_) async => [
        {
          'id': 'link-1',
          'relation_role': 'Chủ hộ',
          'apartments': {'id': 'apt-101', 'code': 'A0110', 'area': 75.5},
        }
      ]);
      when(() => mockSource.fetchVehicles(testUser.id)).thenAnswer((_) async => [
        {'id': 'veh-1', 'plate_number': '29A-99999', 'vehicle_type': 'car', 'status': 'approved'}
      ]);
      when(() => mockSource.fetchIssues(testUser.id)).thenAnswer((_) async => []);
      when(() => mockSource.fetchInvoices(['apt-101'])).thenAnswer((_) async => [
        {'id': 'inv-1', 'period': '11/2026', 'total_amount': 1500000, 'status': 'paid'}
      ]);
      when(() => mockSource.recordAuditLog(
            actorId: any(named: 'actorId'),
            action: any(named: 'action'),
            entityName: any(named: 'entityName'),
            entityId: any(named: 'entityId'),
            details: any(named: 'details'),
          )).thenAnswer((_) async {});

      final service = DataPrivacyService(source: mockSource);
      final exportResult = await service.exportUserData(user: testUser);

      expect(exportResult['export_metadata']['export_standard'], 'PDPL_VN_91_2025_QH15_ART15');
      expect(exportResult['export_metadata']['platform'], contains('PKA-Home'));
      expect(exportResult['subject_identity']['user_id'], 'user-pdpl-123');
      expect(exportResult['subject_identity']['full_name'], 'Trần Cư Dân');
      expect(exportResult['subject_identity']['account_status'], 'ACTIVE');
      expect((exportResult['apartments'] as List).length, 1);
      expect((exportResult['registered_vehicles'] as List).length, 1);
      expect((exportResult['service_invoices'] as List).length, 1);

      final integrity = exportResult['integrity_verification'] as Map<String, dynamic>;
      expect(integrity['algorithm'], 'SHA-256');
      expect(integrity['hash'], isNotEmpty);
      expect((integrity['hash'] as String).length, 64); // Độ dài chuỗi SHA-256 hex

      verify(() => mockSource.recordAuditLog(
            actorId: testUser.id,
            action: 'PDPL_DATA_EXPORTED',
            entityName: 'users',
            entityId: testUser.id,
            details: any(named: 'details'),
          )).called(1);
    });

    test('requestDataAnonymization ghi nhận đúng audit log đóng băng PII', () async {
      when(() => mockSource.recordAuditLog(
            actorId: any(named: 'actorId'),
            action: any(named: 'action'),
            entityName: any(named: 'entityName'),
            entityId: any(named: 'entityId'),
            details: any(named: 'details'),
          )).thenAnswer((_) async {});

      final service = DataPrivacyService(source: mockSource);
      final success = await service.requestDataAnonymization(
        userId: testUser.id,
        reason: 'Chấm dứt hợp đồng thuê căn hộ và chuyển đi nơi khác',
        notes: 'Đã thanh toán hết công nợ.',
      );

      expect(success, isTrue);
      verify(() => mockSource.recordAuditLog(
            actorId: testUser.id,
            action: 'PDPL_ANONYMIZATION_REQUEST',
            entityName: 'users',
            entityId: testUser.id,
            details: any(named: 'details'),
          )).called(1);
    });
  });
}
