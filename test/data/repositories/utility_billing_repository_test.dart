import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/building_utility_rate_model.dart';
import 'package:pka_home/data/repositories/meter_reading_repository.dart';

class FakeMeterReadingRepository implements MeterReadingRepository {
  bool getUtilityRatesCalled = false;
  bool batchRecordCalled = false;
  bool approveReadingCalled = false;

  String? lastPeriod;
  List<Map<String, dynamic>>? lastReadings;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<BuildingUtilityRateModel>> getUtilityRates() async {
    getUtilityRatesCalled = true;
    return [
      const BuildingUtilityRateModel(
        id: 'rate-elec-1',
        utilityType: 'electricity',
        baseUnitPrice: 3500.0,
      ),
      const BuildingUtilityRateModel(
        id: 'rate-water-1',
        utilityType: 'water',
        baseUnitPrice: 25000.0,
        vatPercentage: 5.0,
        environmentFeePercentage: 10.0,
      ),
    ];
  }

  @override
  Future<Map<String, dynamic>> batchRecordReadings({
    required String period,
    required List<Map<String, dynamic>> readings,
  }) async {
    batchRecordCalled = true;
    lastPeriod = period;
    lastReadings = readings;
    return {
      'success': true,
      'inserted_count': readings.length,
      'message': 'Đã chốt thành công ${readings.length} căn hộ',
    };
  }

  @override
  Future<Map<String, dynamic>> approveReading({
    required String submissionId,
    bool generateInvoice = true,
    DateTime? dueDate,
  }) async {
    approveReadingCalled = true;
    return {
      'success': true,
      'submission_id': submissionId,
      'invoice_id': 'inv-test-999',
      'utility_total': 500000.0,
    };
  }
}

void main() {
  group('Utility Billing Repository Tests', () {
    late FakeMeterReadingRepository repo;

    setUp(() {
      repo = FakeMeterReadingRepository();
    });

    test('getUtilityRates trả về danh sách biểu giá chuẩn', () async {
      final rates = await repo.getUtilityRates();
      expect(repo.getUtilityRatesCalled, isTrue);
      expect(rates.length, 2);
      expect(rates.first.isElectricity, isTrue);
      expect(rates.first.baseUnitPrice, 3500.0);
    });

    test('batchRecordReadings truyền dữ liệu chốt số hàng loạt', () async {
      final readings = [
        {
          'apartment_id': 'apt-1',
          'electric_reading': 120.0,
          'water_reading': 15.0,
        },
        {
          'apartment_id': 'apt-2',
          'electric_reading': 240.0,
          'water_reading': 28.0,
        },
      ];

      final res = await repo.batchRecordReadings(
        period: '11/2026',
        readings: readings,
      );

      expect(repo.batchRecordCalled, isTrue);
      expect(repo.lastPeriod, '11/2026');
      expect(repo.lastReadings?.length, 2);
      expect(res['inserted_count'], 2);
    });

    test('approveReading phê duyệt và sinh hóa đơn', () async {
      final res = await repo.approveReading(
        submissionId: 'sub-test-1',
        generateInvoice: true,
      );

      expect(repo.approveReadingCalled, isTrue);
      expect(res['invoice_id'], 'inv-test-999');
      expect(res['utility_total'], 500000.0);
    });
  });
}
