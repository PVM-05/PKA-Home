import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pka_home/data/repositories/management_repository.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  group('ManagementRepository - fetchAssignableStaff tests', () {
    late MockSupabaseClient mockClient;
    late ManagementRepository repository;

    setUp(() {
      mockClient = MockSupabaseClient();
      repository = ManagementRepository(mockClient);
    });

    test('fetchAssignableStaff tồn tại dưới dạng phương thức bất đồng bộ', () {
      expect(repository.fetchAssignableStaff, isA<Function>());
    });

    test('fetchAssignableStaff trả về mảng rỗng an toàn khi có ngoại lệ kết nối', () async {
      when(() => mockClient.from(any())).thenThrow(Exception('Lỗi kết nối cơ sở dữ liệu'));

      final staff = await repository.fetchAssignableStaff();
      expect(staff, isEmpty);
    });
  });
}
