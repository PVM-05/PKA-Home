import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/widgets/app_storage_image.dart';

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
  });
}
