/// Model đóng gói dữ liệu phân trang chuẩn mực cho danh sách lớn (B2B SaaS Architecture).
/// Hỗ trợ lazy loading / infinite scroll với các cờ trạng thái hasMore và isLoadingMore.
class PaginatedList<T> {
  final List<T> items;
  final int page;
  final int pageSize;
  final bool hasMore;
  final bool isLoadingMore;

  const PaginatedList({
    required this.items,
    this.page = 1,
    this.pageSize = 20,
    required this.hasMore,
    this.isLoadingMore = false,
  });

  PaginatedList<T> copyWith({
    List<T>? items,
    int? page,
    int? pageSize,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return PaginatedList<T>(
      items: items ?? this.items,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaginatedList<T> &&
          runtimeType == other.runtimeType &&
          items == other.items &&
          page == other.page &&
          pageSize == other.pageSize &&
          hasMore == other.hasMore &&
          isLoadingMore == other.isLoadingMore;

  @override
  int get hashCode =>
      items.hashCode ^
      page.hashCode ^
      pageSize.hashCode ^
      hasMore.hashCode ^
      isLoadingMore.hashCode;
}

