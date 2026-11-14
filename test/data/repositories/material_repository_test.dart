import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/utils/guard_helper.dart';
import 'package:pka_home/data/models/maintenance_material_model.dart';
import 'package:pka_home/data/repositories/material_repository.dart';

void main() {
  group('MaterialRepository Fail-Closed Tests', () {
    late MaterialRepository repository;

    setUp(() {
      repository = MaterialRepository(null);
    });

    test('1. fetchMaterials ném AppException khi không có kết nối Supabase', () async {
      expect(
        () => repository.fetchMaterials(),
        throwsA(isA<AppException>()),
      );
    });

    test('2. fetchIssueMaterials ném AppException khi không có kết nối Supabase', () async {
      expect(
        () => repository.fetchIssueMaterials('issue-01'),
        throwsA(isA<AppException>()),
      );
    });

    test('3. recordMaterialsUsage ném AppException khi không có kết nối Supabase', () async {
      expect(
        () => repository.recordMaterialsUsage(
          issueId: 'issue-01',
          materials: [
            {'material_id': 'mat-01', 'quantity': 2},
          ],
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('4. fetchSlaStats ném AppException khi không có kết nối Supabase', () async {
      expect(
        () => repository.fetchSlaStats(),
        throwsA(isA<AppException>()),
      );
    });

    test('5. createMaterial ném AppException khi không có kết nối Supabase', () async {
      final mat = MaintenanceMaterialModel(
        id: 'mat-test',
        code: 'MAT-TEST',
        name: 'Vật tư test',
        category: 'electrical',
        unit: 'cái',
        unitPrice: 50000,
        stockQuantity: 10,
        createdAt: DateTime.now(),
      );
      expect(
        () => repository.createMaterial(mat),
        throwsA(isA<AppException>()),
      );
    });
  });
}
