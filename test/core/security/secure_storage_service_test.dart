import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/security/secure_storage_service.dart';

// Mock storage generator để kiểm thử cache độc lập mà không cần kết nối mạng
class MockStorageUrlGenerator {
  int callCount = 0;

  Future<String> generate(String bucket, String path, int expiresIn) async {
    callCount++;
    return 'https://supabase.co/storage/v1/object/sign/$bucket/$path?token=mock-token-$callCount';
  }
}

void main() {
  group('SecureStorageService Tests', () {
    late SecureStorageService service;
    late MockStorageUrlGenerator mockGenerator;

    setUp(() {
      mockGenerator = MockStorageUrlGenerator();
      service = SecureStorageService(
        urlGenerator: mockGenerator.generate,
      );
    });

    test('formatSecurePath tạo đường dẫn chuẩn mực có tiền tố tòa nhà và danh mục', () {
      final path = service.formatSecurePath(
        buildingId: 'bld-01',
        category: 'issues',
        fileName: 'broken_pipe.jpg',
      );
      expect(path.startsWith('bld-01/issues/'), isTrue);
      expect(path.endsWith('_broken_pipe.jpg'), isTrue);
    });

    test('getSignedUrl sinh URL mới trong lần gọi đầu tiên', () async {
      final url = await service.getSignedUrl(
        bucket: 'issue-images',
        path: 'bld-01/issues/pipe.jpg',
        expiresInSeconds: 1800,
      );
      expect(url, contains('issue-images/bld-01/issues/pipe.jpg'));
      expect(mockGenerator.callCount, 1);
    });

    test('getSignedUrl sử dụng in-memory cache cho các lần gọi tiếp theo khi chưa hết hạn', () async {
      final url1 = await service.getSignedUrl(
        bucket: 'issue-images',
        path: 'bld-01/issues/pipe.jpg',
        expiresInSeconds: 1800,
      );
      final url2 = await service.getSignedUrl(
        bucket: 'issue-images',
        path: 'bld-01/issues/pipe.jpg',
        expiresInSeconds: 1800,
      );

      expect(url1, equals(url2));
      expect(mockGenerator.callCount, 1, reason: 'Lần gọi thứ 2 phải lấy từ cache, không gọi lại API');
    });

    test('invalidateCache xóa bỏ bản ghi đệm và buộc sinh URL mới', () async {
      await service.getSignedUrl(
        bucket: 'issue-images',
        path: 'bld-01/issues/pipe.jpg',
        expiresInSeconds: 1800,
      );
      expect(mockGenerator.callCount, 1);

      service.invalidateCache(bucket: 'issue-images', path: 'bld-01/issues/pipe.jpg');

      await service.getSignedUrl(
        bucket: 'issue-images',
        path: 'bld-01/issues/pipe.jpg',
        expiresInSeconds: 1800,
      );
      expect(mockGenerator.callCount, 2, reason: 'Sau khi xóa cache, service phải gọi generator để sinh URL mới');
    });

    test('clearAllCache xóa toàn bộ cache lưu trữ', () async {
      await service.getSignedUrl(bucket: 'receipts', path: 'rec1.jpg');
      await service.getSignedUrl(bucket: 'receipts', path: 'rec2.jpg');
      expect(mockGenerator.callCount, 2);

      service.clearAllCache();

      await service.getSignedUrl(bucket: 'receipts', path: 'rec1.jpg');
      expect(mockGenerator.callCount, 3);
    });
  });
}

