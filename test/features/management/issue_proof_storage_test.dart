import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Kiểm thử xử lý đường dẫn ảnh minh chứng sự cố', () {
    test('Trích xuất đường dẫn object từ URL Supabase Storage', () {
      final sampleUrl = 'https://abc.supabase.co/storage/v1/object/public/issue-images/staff1/issue1/proof_123.jpg';
      final uri = Uri.parse(sampleUrl);
      final segments = uri.pathSegments;
      final bucketIndex = segments.indexOf('issue-images');
      final path = (bucketIndex != -1 && bucketIndex + 1 < segments.length)
          ? segments.sublist(bucketIndex + 1).join('/')
          : segments.last;

      expect(path, 'staff1/issue1/proof_123.jpg');
    });

    test('Xử lý đường dẫn thuần không phải URL', () {
      const samplePath = 'staff1/issue1/proof_123.jpg';
      final isFullUrl = samplePath.startsWith('http://') || samplePath.startsWith('https://');
      expect(isFullUrl, isFalse);
    });
  });
}
