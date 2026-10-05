import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/meter_reading_submission_model.dart';
import 'package:pka_home/data/repositories/meter_reading_repository.dart';

class MockMeterReadingRepository implements MeterReadingRepository {
  bool submitCalled = false;
  bool approveCalled = false;
  bool rejectCalled = false;

  final List<MeterReadingSubmissionModel> _items = [];

  @override
  Future<MeterReadingSubmissionModel> submitReading({
    required String apartmentId,
    required String userId,
    required String period,
    required double electricReading,
    required double waterReading,
    String? electricImageUrl,
    String? waterImageUrl,
  }) async {
    submitCalled = true;
    final item = MeterReadingSubmissionModel(
      id: 'sub-${_items.length + 1}',
      apartmentId: apartmentId,
      apartmentCode: 'A0110',
      submittedBy: userId,
      period: period,
      electricReading: electricReading,
      waterReading: waterReading,
      electricImageUrl: electricImageUrl,
      waterImageUrl: waterImageUrl,
      status: 'pending',
      createdAt: DateTime.now(),
    );
    _items.add(item);
    return item;
  }

  @override
  Future<List<MeterReadingSubmissionModel>> getMySubmissions(String apartmentId) async {
    return _items.where((i) => i.apartmentId == apartmentId).toList();
  }

  @override
  Future<List<MeterReadingSubmissionModel>> getAllSubmissions({String? status}) async {
    if (status != null) {
      return _items.where((i) => i.status == status).toList();
    }
    return _items;
  }

  @override
  Future<Map<String, dynamic>> approveReading({
    required String submissionId,
    bool generateInvoice = false,
    DateTime? dueDate,
  }) async {
    approveCalled = true;
    final index = _items.indexWhere((i) => i.id == submissionId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(status: 'approved', reviewedAt: DateTime.now());
    }
    return {'success': true, 'message': 'Đã phê duyệt chỉ số thành công!'};
  }

  @override
  Future<Map<String, dynamic>> rejectReading({
    required String submissionId,
    required String reason,
  }) async {
    rejectCalled = true;
    final index = _items.indexWhere((i) => i.id == submissionId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(status: 'rejected', rejectReason: reason);
    }
    return {'success': true, 'message': 'Đã từ chối chỉ số.'};
  }
}

void main() {
  group('MeterReadingRepository Tests', () {
    late MockMeterReadingRepository repo;

    setUp(() {
      repo = MockMeterReadingRepository();
    });

    test('submitReading thêm bản ghi mới ở trạng thái pending', () async {
      final res = await repo.submitReading(
        apartmentId: 'apt-1',
        userId: 'user-1',
        period: '10/2026',
        electricReading: 1390.0,
        waterReading: 91.0,
        electricImageUrl: 'https://img.electric.jpg',
        waterImageUrl: 'https://img.water.jpg',
      );

      expect(repo.submitCalled, isTrue);
      expect(res.status, 'pending');
      expect(res.electricReading, 1390.0);
      expect(res.waterReading, 91.0);

      final mySubmissions = await repo.getMySubmissions('apt-1');
      expect(mySubmissions.length, 1);
    });

    test('approveReading chuyển trạng thái bản ghi sang approved', () async {
      final sub = await repo.submitReading(
        apartmentId: 'apt-1',
        userId: 'user-1',
        period: '10/2026',
        electricReading: 1390.0,
        waterReading: 91.0,
      );

      final res = await repo.approveReading(submissionId: sub.id, generateInvoice: true);

      expect(repo.approveCalled, isTrue);
      expect(res['success'], isTrue);

      final all = await repo.getAllSubmissions(status: 'approved');
      expect(all.length, 1);
      expect(all.first.isApproved, isTrue);
    });

    test('rejectReading cập nhật trạng thái rejected kèm lý do từ chối', () async {
      final sub = await repo.submitReading(
        apartmentId: 'apt-1',
        userId: 'user-1',
        period: '10/2026',
        electricReading: 1390.0,
        waterReading: 91.0,
      );

      final res = await repo.rejectReading(
        submissionId: sub.id,
        reason: 'Ảnh mờ không nhìn rõ số công tơ',
      );

      expect(repo.rejectCalled, isTrue);
      expect(res['success'], isTrue);

      final rejectedList = await repo.getAllSubmissions(status: 'rejected');
      expect(rejectedList.length, 1);
      expect(rejectedList.first.isRejected, isTrue);
      expect(rejectedList.first.rejectReason, 'Ảnh mờ không nhìn rõ số công tơ');
    });
  });
}
