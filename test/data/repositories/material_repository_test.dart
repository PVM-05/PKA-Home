import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/repositories/material_repository.dart';

void main() {
  group('MaterialRepository Offline Fallback Engine Tests', () {
    late MaterialRepository repository;

    setUp(() {
      repository = MaterialRepository(null, true);
    });

    test('1. fetchMaterials trả về danh sách vật tư mẫu khi offline', () async {
      final materials = await repository.fetchMaterials();

      expect(materials, isNotEmpty);
      expect(materials.length, greaterThanOrEqualTo(10));

      final bulb = materials.firstWhere((m) => m.code == 'MAT-ELEC-01');
      expect(bulb.name, contains('Bóng đèn LED'));
      expect(bulb.category, 'electrical');
      expect(bulb.stockQuantity, greaterThan(0));
    });

    test('2. fetchMaterials hỗ trợ lọc theo category', () async {
      final electricalOnly = await repository.fetchMaterials(category: 'electrical');
      expect(electricalOnly.every((m) => m.category == 'electrical'), isTrue);

      final plumbingOnly = await repository.fetchMaterials(category: 'plumbing');
      expect(plumbingOnly.every((m) => m.category == 'plumbing'), isTrue);
    });

    test('3. recordMaterialsUsage ghi nhận vật tư và trừ tồn kho chính xác', () async {
      final initialMaterials = await repository.fetchMaterials();
      final bulb = initialMaterials.firstWhere((m) => m.code == 'MAT-ELEC-01');
      final initialStock = bulb.stockQuantity;

      // Xuất 2 bóng đèn cho sự cố iss-01
      final result = await repository.recordMaterialsUsage(
        issueId: 'iss-01',
        materials: [
          {
            'material_id': bulb.id,
            'quantity': 2,
            'is_chargeable': true,
            'note': 'Thay bóng đèn phòng khách',
          }
        ],
      );

      expect(result['success'], isTrue);

      // Kiểm tra tồn kho sau khi xuất
      final updatedMaterials = await repository.fetchMaterials();
      final updatedBulb = updatedMaterials.firstWhere((m) => m.id == bulb.id);
      expect(updatedBulb.stockQuantity, initialStock - 2);

      // Kiểm tra danh sách vật tư của sự cố
      final issueMaterials = await repository.fetchIssueMaterials('iss-01');
      expect(issueMaterials, isNotEmpty);
      expect(issueMaterials.any((im) => im.materialId == bulb.id && im.quantity == 2 && im.isChargeable), isTrue);
    });

    test('4. fetchSlaStats trả về thống kê KPI SLA hợp lệ', () async {
      final stats = await repository.fetchSlaStats();

      expect(stats.totalIssues, greaterThanOrEqualTo(0));
      expect(stats.complianceRate, inInclusiveRange(0.0, 100.0));
    });

    test('5. updateMaterialStock cho phép BQL nhập thêm hàng vào kho', () async {
      final materials = await repository.fetchMaterials();
      final firstMat = materials.first;
      final currentStock = firstMat.stockQuantity;

      final res = await repository.updateMaterialStock(
        materialId: firstMat.id,
        newStock: currentStock + 10,
      );

      expect(res['success'], isTrue);

      final afterUpdate = await repository.fetchMaterials();
      final updated = afterUpdate.firstWhere((m) => m.id == firstMat.id);
      expect(updated.stockQuantity, currentStock + 10);
    });

    test('6. adjustMaterialStockDelta cho phép điều chỉnh tăng/giảm tồn kho an toàn kèm lý do', () async {
      final materials = await repository.fetchMaterials();
      final mat = materials.first;
      final currentStock = mat.stockQuantity;

      // 6.1 Nhập thêm +15 cái
      final resImport = await repository.adjustMaterialStockDelta(
        materialId: mat.id,
        delta: 15,
        reason: 'Nhập lô hàng bổ sung đợt 1',
      );
      expect(resImport['success'], isTrue);
      expect(resImport['new_stock'], currentStock + 15);

      // 6.2 Xuất giảm / Hao hụt -5 cái
      final resLoss = await repository.adjustMaterialStockDelta(
        materialId: mat.id,
        delta: -5,
        reason: 'Hao hụt kiểm kê cuối tháng',
      );
      expect(resLoss['success'], isTrue);
      expect(resLoss['new_stock'], currentStock + 10);
    });
  });
}
