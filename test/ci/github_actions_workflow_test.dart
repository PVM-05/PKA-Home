import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Kiểm tra Cấu Hình CI/CD GitHub Actions (INF-01)', () {
    const ciWorkflowPath = '.github/workflows/ci.yml';

    test('File .github/workflows/ci.yml phải tồn tại và không rỗng', () {
      final file = File(ciWorkflowPath);
      expect(file.existsSync(), isTrue, reason: 'File workflow CI phải tồn tại tại .github/workflows/ci.yml');
      final content = file.readAsStringSync();
      expect(content.trim().isNotEmpty, isTrue, reason: 'Nội dung workflow CI không được rỗng');
    });

    test('Workflow phải kích hoạt trên nhánh main khi push và pull_request', () {
      final content = File(ciWorkflowPath).readAsStringSync();
      expect(content.contains('push:'), isTrue, reason: 'Phải kích hoạt khi push');
      expect(content.contains('pull_request:'), isTrue, reason: 'Phải kích hoạt khi pull_request');
      expect(content.contains('main'), isTrue, reason: 'Phải chỉ định nhánh main');
    });

    test('Workflow phải cài đặt Flutter Action chuẩn và chạy kiểm thử đầy đủ', () {
      final content = File(ciWorkflowPath).readAsStringSync();
      expect(content.contains('actions/checkout'), isTrue, reason: 'Phải checkout mã nguồn');
      expect(content.contains('subosito/flutter-action'), isTrue, reason: 'Phải dùng flutter-action');
      expect(content.contains('flutter pub get'), isTrue, reason: 'Phải cài đặt dependencies');
      expect(content.contains('dart analyze') || content.contains('flutter analyze'), isTrue,
          reason: 'Phải chạy Static Analysis');
      expect(content.contains('flutter test'), isTrue, reason: 'Phải chạy automated tests');
    });
  });
}
