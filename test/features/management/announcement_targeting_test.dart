import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/data/models/announcement_model.dart';
import 'package:pka_home/data/providers/announcement_provider.dart';
import 'package:pka_home/data/repositories/announcement_repository.dart';
import 'package:pka_home/features/management/screens/announcement_management_screen.dart';

class MockAnnouncementRepository implements AnnouncementRepository {
  bool createCalled = false;
  String? lastTargetType;
  String? lastTargetApartment;

  @override
  Stream<List<Map<String, dynamic>>> streamAnnouncements() => const Stream.empty();

  @override
  Future<void> createAnnouncement({
    required String title,
    required String content,
    required bool isUrgent,
    String targetType = 'all',
    String? targetApartment,
  }) async {
    createCalled = true;
    lastTargetType = targetType;
    lastTargetApartment = targetApartment;
  }

  @override
  Future<void> updateAnnouncement({
    required String id,
    required String title,
    required String content,
    required bool isUrgent,
    String targetType = 'all',
    String? targetApartment,
  }) async {}

  @override
  Future<void> deleteAnnouncement(String id) async {}
}

void main() {
  testWidgets('AnnouncementManagementScreen hiển thị nhãn phân nhóm đối tượng và cho phép chọn đối tượng khi tạo thông báo', (tester) async {
    final mockRepo = MockAnnouncementRepository();

    final testAnnouncements = [
      AnnouncementModel(
        id: 'ann-1',
        title: 'Bảo trì thang máy',
        content: 'Bảo trì toàn bộ thang máy tòa nhà.',
        isUrgent: false,
        targetType: 'all',
        createdAt: DateTime(2026, 10, 5, 8, 0),
      ),
      AnnouncementModel(
        id: 'ann-2',
        title: 'Vệ sinh hành lang Tòa A',
        content: 'Vệ sinh định kỳ các tầng Tòa A.',
        isUrgent: false,
        targetType: 'block_a',
        createdAt: DateTime(2026, 10, 5, 9, 0),
      ),
      AnnouncementModel(
        id: 'ann-3',
        title: 'Sửa đường ống nước',
        content: 'Khắc phục rò rỉ nước phòng A0110.',
        isUrgent: true,
        targetType: 'apartment',
        targetApartment: 'A0110',
        createdAt: DateTime(2026, 10, 5, 10, 0),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          announcementRepositoryProvider.overrideWithValue(mockRepo),
          announcementsStreamProvider.overrideWith((ref) => Stream.value(testAnnouncements)),
        ],
        child: const MaterialApp(
          home: AnnouncementManagementScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Kiểm tra hiển thị tiêu đề và danh sách thông báo
    expect(find.text('Quản lý Thông báo'), findsOneWidget);
    expect(find.text('Bảo trì thang máy'), findsOneWidget);
    expect(find.text('Vệ sinh hành lang Tòa A'), findsOneWidget);
    expect(find.text('Sửa đường ống nước'), findsOneWidget);

    // 2. Kiểm tra các nhãn đối tượng (Audience targeting tags)
    expect(find.text('Tất cả cư dân'), findsOneWidget);
    expect(find.text('Tòa A'), findsOneWidget);
    expect(find.text('Căn hộ A0110'), findsOneWidget);

    // 3. Mở dialog tạo thông báo mới
    final fab = find.byType(FloatingActionButton);
    expect(fab, findsOneWidget);
    await tester.tap(fab);
    await tester.pumpAndSettle();

    expect(find.text('Tạo thông báo mới'), findsOneWidget);
    expect(find.text('Đối tượng nhận thông báo'), findsOneWidget);

    // 4. Điền tiêu đề, nội dung và chuyển sang chọn Căn hộ cụ thể
    await tester.enterText(find.widgetWithText(TextFormField, 'Tiêu đề *'), 'Thông báo thử nghiệm');
    await tester.enterText(find.widgetWithText(TextFormField, 'Nội dung *'), 'Nội dung kiểm tra phân nhóm đối tượng.');

    // Chọn Dropdown Đối tượng nhận thông báo
    await tester.tap(find.text('Tất cả cư dân (Toàn tòa)'));
    await tester.pumpAndSettle();

    // Chọn mục "Căn hộ cụ thể"
    await tester.tap(find.text('Căn hộ cụ thể').last);
    await tester.pumpAndSettle();

    // Nhập mã căn hộ
    expect(find.text('Mã căn hộ nhận tin *'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Mã căn hộ nhận tin *'), 'A0110');

    // Bấm nút Đăng
    await tester.tap(find.text('Đăng'));
    await tester.pumpAndSettle();

    expect(mockRepo.createCalled, isTrue);
    expect(mockRepo.lastTargetType, 'apartment');
    expect(mockRepo.lastTargetApartment, 'A0110');
    expect(find.text('Tạo thông báo thành công!'), findsOneWidget);
  });
}
