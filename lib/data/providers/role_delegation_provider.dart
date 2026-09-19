import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/role_delegation_model.dart';
import 'management_provider.dart';

/// Provider danh sách toàn bộ ủy quyền (Dành cho Quản trị viên)
final delegationsListProvider = FutureProvider.autoDispose<List<RoleDelegationModel>>((ref) async {
  final repo = ref.watch(managementRepositoryProvider);
  return repo.fetchDelegations();
});

/// Provider cung cấp danh sách tên vai trò (ví dụ: ['accountant']) đang được ủy quyền
/// active cho tài khoản hiện tại.
/// Tự động đánh giá thời gian thực và làm mới mỗi 30 giây để triệt tiêu độ trễ
/// khi ủy quyền vượt qua mốc ends_at mà không có mutation từ CSDL.
final activeDelegationsProvider = StreamProvider.autoDispose<List<String>>((ref) async* {
  final repo = ref.watch(managementRepositoryProvider);

  Future<List<String>> getActiveRoles() async {
    try {
      final list = await repo.fetchMyActiveDelegations();
      final now = DateTime.now();
      return list
          .where((d) => d.isActiveAt(now))
          .map((d) => d.delegatedRole)
          .toSet()
          .toList();
    } catch (_) {
      return [];
    }
  }

  // Phát giá trị ngay khi khởi tạo
  yield await getActiveRoles();

  // Phát lại định kỳ mỗi 30 giây
  final ticker = Stream.periodic(const Duration(seconds: 30), (_) => null);
  await for (final _ in ticker) {
    yield await getActiveRoles();
  }
});
