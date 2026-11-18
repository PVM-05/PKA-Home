import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/core/widgets/app_skeleton_shimmer.dart';
import 'package:vivona/core/widgets/app_storage_image.dart';

void main() {
  group('Kiểm thử xử lý đường dẫn ảnh trong AppStorageImage', () {
    test('Giữ nguyên các URL công khai không thuộc issue-images', () async {
      const publicUrl = 'https://placehold.co/600x400/png?text=HienTruongSuCo';
      final resolved = await AppStorageImage.resolveSignedUrl(publicUrl);
      expect(resolved, publicUrl);
    });

    test('Trích xuất đúng chuỗi rỗng khi chuỗi truyền vào rỗng', () async {
      final resolved = await AppStorageImage.resolveSignedUrl('');
      expect(resolved, '');
    });

    testWidgets('AppStorageImage hiển thị AppSkeletonShimmer khi đang tải và không dùng CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppStorageImage(
              imageUrl: 'issue-images/test/image.jpg',
              width: 120,
              height: 120,
            ),
          ),
        ),
      );

      // Khi vừa mount và đang tải URL, phải render AppSkeletonShimmer thay vì CircularProgressIndicator
      expect(find.byType(AppSkeletonShimmer), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('AppStorageImage hiển thị icon broken_image khi đường dẫn ảnh rỗng', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppStorageImage(
              imageUrl: '',
              width: 120,
              height: 120,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    });
  });
}
