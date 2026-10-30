import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/batch_import_model.dart';
import 'package:pka_home/data/providers/batch_import_provider.dart';
import 'package:pka_home/data/repositories/batch_import_repository.dart';
import 'package:pka_home/features/management/screens/batch_import_center_screen.dart';

class FakeBatchImportRepository extends BatchImportRepository {
  @override
  Future<Set<String>> fetchExistingApartmentCodes(String buildingId) async {
    return {'A0110', 'B0205'};
  }

  @override
  Future<Map<String, dynamic>> importApartments({
    required String buildingId,
    required List<ApartmentImportItem> apartments,
  }) async {
    return {
      'success': true,
      'total_imported': apartments.length,
      'message': 'Đã nhập thành công ${apartments.length} căn hộ',
    };
  }
}

void main() {
  Widget buildTestWidget({BatchImportRepository? repo}) {
    return ProviderScope(
      overrides: [
        batchImportRepositoryProvider.overrideWithValue(
          repo ?? FakeBatchImportRepository(),
        ),
      ],
      child: const MaterialApp(
        home: BatchImportCenterScreen(),
      ),
    );
  }

  group('BatchImportCenterScreen Widget Tests', () {
    testWidgets('renders all initial UI elements correctly', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Nhập Liệu Hàng Loạt'), findsOneWidget);
      expect(find.text('Quy chuẩn dữ liệu nhập tự động'), findsOneWidget);

      // Check segments
      expect(find.text('Căn hộ'), findsOneWidget);
      expect(find.text('Cư dân'), findsOneWidget);
      expect(find.text('Điện nước'), findsOneWidget);

      // Check step titles
      expect(find.text('Tải File Mẫu Chuẩn Hóa (.xlsx)'), findsOneWidget);
      expect(find.text('Chọn File Dữ Liệu Excel'), findsOneWidget);
      expect(find.text('Kết Quả Thẩm Định & Kiểm Tra'), findsOneWidget);

      // Check template button label
      expect(find.text('Tải mẫu Căn hộ'), findsOneWidget);
    });

    testWidgets('switching tab updates button label and state', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap on 'Cư dân' tab
      await tester.tap(find.text('Cư dân'));
      await tester.pumpAndSettle();

      expect(find.text('Tải mẫu Cư dân'), findsOneWidget);

      // Tap on 'Điện nước' tab
      await tester.tap(find.text('Điện nước'));
      await tester.pumpAndSettle();

      expect(find.text('Tải mẫu Điện nước'), findsOneWidget);
    });

    testWidgets('displays validation summary cards when parsed', (tester) async {
      final fakeRepo = FakeBatchImportRepository();
      final container = ProviderContainer(
        overrides: [
          batchImportRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: BatchImportCenterScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Inject validation result via notifier
      final notifier = container.read(batchImportProvider.notifier);
      container.read(batchImportProvider.notifier).state =
          container.read(batchImportProvider).copyWith(
                selectedFileName: 'test_can_ho.xlsx',
                fileBytes: Uint8List(10),
                validationResult: BatchImportResultModel<ApartmentImportItem>(
                  totalRows: 2,
                  validItems: [
                    ApartmentImportItem(code: 'A0110', area: 70.0),
                  ],
                  rowErrors: const [
                    BatchRowErrorModel(
                      rowNumber: 3,
                      columnName: 'Mã Căn Hộ',
                      invalidValue: 'XYZ',
                      errorMessage: 'Sai định dạng',
                    ),
                  ],
                ),
              );

      await tester.pumpAndSettle();

      expect(find.text('Tổng số dòng'), findsOneWidget);
      expect(find.text('Hợp lệ'), findsOneWidget);
      expect(find.text('Bị lỗi'), findsOneWidget);
      expect(find.text('Phát hiện 1 dòng dữ liệu không hợp lệ'), findsOneWidget);
      expect(find.text('Xuất file Excel danh sách dòng lỗi'), findsOneWidget);
      expect(find.textContaining('Chỉ nạp 1 dòng hợp lệ'), findsOneWidget);
    });
  });
}
