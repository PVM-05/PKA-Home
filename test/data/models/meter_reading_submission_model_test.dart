import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/meter_reading_submission_model.dart';

void main() {
  group('MeterReadingSubmissionModel Tests', () {
    test('Khởi tạo và parse fromJson / toJson đầy đủ trường dữ liệu', () {
      final json = {
        'id': 'sub-123',
        'apartment_id': 'apt-001',
        'apartment_code': 'A0110',
        'submitted_by': 'user-001',
        'submitter_name': 'Nguyễn Văn A',
        'period': '10/2026',
        'electric_reading': 1390.5,
        'water_reading': 91.0,
        'electric_image_url': 'https://example.com/electric.jpg',
        'water_image_url': 'https://example.com/water.jpg',
        'status': 'pending',
        'reject_reason': null,
        'reviewed_by': null,
        'reviewed_at': null,
        'created_at': '2026-10-05T10:00:00.000Z',
        'updated_at': '2026-10-05T10:00:00.000Z',
      };

      final model = MeterReadingSubmissionModel.fromJson(json);

      expect(model.id, 'sub-123');
      expect(model.apartmentId, 'apt-001');
      expect(model.apartmentCode, 'A0110');
      expect(model.submitterName, 'Nguyễn Văn A');
      expect(model.period, '10/2026');
      expect(model.electricReading, 1390.5);
      expect(model.waterReading, 91.0);
      expect(model.electricImageUrl, 'https://example.com/electric.jpg');
      expect(model.waterImageUrl, 'https://example.com/water.jpg');
      expect(model.status, 'pending');
      expect(model.isPending, isTrue);
      expect(model.isApproved, isFalse);
      expect(model.isRejected, isFalse);
      expect(model.statusDisplayName, 'Chờ phê duyệt');

      final serialized = model.toJson();
      expect(serialized['id'], 'sub-123');
      expect(serialized['electric_reading'], 1390.5);
      expect(serialized['water_reading'], 91.0);
    });

    test('Helper getters cho trạng thái approved và rejected', () {
      final approvedModel = MeterReadingSubmissionModel(
        id: 'sub-2',
        apartmentId: 'apt-2',
        submittedBy: 'u-2',
        period: '10/2026',
        electricReading: 1500,
        waterReading: 100,
        status: 'approved',
        createdAt: DateTime.now(),
      );

      expect(approvedModel.isApproved, isTrue);
      expect(approvedModel.statusDisplayName, 'Đã phê duyệt');

      final rejectedModel = approvedModel.copyWith(
        status: 'rejected',
        rejectReason: 'Ảnh mờ không nhìn rõ số',
      );

      expect(rejectedModel.isRejected, isTrue);
      expect(rejectedModel.statusDisplayName, 'Đã từ chối');
      expect(rejectedModel.rejectReason, 'Ảnh mờ không nhìn rõ số');
    });
  });
}
