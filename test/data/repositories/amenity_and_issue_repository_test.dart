import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/repositories/issue_repository.dart';

void main() {
  group('IssueRepository.extractStoragePath', () {
    test('trích xuất object path chính xác từ URL đầy đủ', () {
      const fullUrl = 'https://vpgimjyyechhuofjghsb.supabase.co/storage/v1/object/public/issue-images/user1/issue1/123456_0.jpg';
      final path = IssueRepository.extractStoragePath(fullUrl);
      expect(path, 'user1/issue1/123456_0.jpg');
    });

    test('giữ nguyên nếu đã là object path thuần', () {
      const objectPath = 'user1/issue1/123456_0.jpg';
      final path = IssueRepository.extractStoragePath(objectPath);
      expect(path, 'user1/issue1/123456_0.jpg');
    });

    test('trả về chuỗi rỗng nếu đầu vào rỗng', () {
      expect(IssueRepository.extractStoragePath(''), '');
    });
  });
}
