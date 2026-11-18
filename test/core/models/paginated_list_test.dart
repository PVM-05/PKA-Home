import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/core/models/paginated_list.dart';

void main() {
  group('PaginatedList Model Tests', () {
    test('khoi tao dung gia tri mac dinh', () {
      const list = PaginatedList<String>(
        items: ['a', 'b', 'c'],
        hasMore: true,
      );

      expect(list.items.length, 3);
      expect(list.page, 1);
      expect(list.pageSize, 20);
      expect(list.hasMore, isTrue);
      expect(list.isLoadingMore, isFalse);
    });

    test('copyWith cap nhat dung cac truong', () {
      const list = PaginatedList<int>(
        items: [1, 2],
        hasMore: true,
      );

      final updated = list.copyWith(
        items: [1, 2, 3, 4],
        page: 2,
        hasMore: false,
        isLoadingMore: true,
      );

      expect(updated.items, [1, 2, 3, 4]);
      expect(updated.page, 2);
      expect(updated.hasMore, isFalse);
      expect(updated.isLoadingMore, isTrue);
    });
  });
}

