import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/providers/role_delegation_provider.dart';
import '../constants/permissions.dart';
import '../theme/app_theme.dart';

/// Widget phòng thủ tầng UI (Defense-in-depth).
/// Kiểm tra xem người dùng hiện tại có đủ thẩm quyền truy cập hay không
/// dựa trên vai trò chính thức và các ủy quyền vai trò tạm thời đang có hiệu lực.
class RoleGuard extends ConsumerWidget {
  final PermissionItem permission;
  final Widget child;
  final Widget? fallback;

  const RoleGuard({
    required this.permission,
    required this.child,
    this.fallback,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    final activeDelegations = ref.watch(activeDelegationsProvider).valueOrNull ?? [];

    final hasAccess = permission.allows(
      user?.role,
      activeDelegations: activeDelegations,
    );

    if (hasAccess) {
      return child;
    }

    if (fallback != null) {
      return fallback!;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(permission.name),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline,
                  color: AppTheme.error,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Không có quyền truy cập',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Bạn không có quyền truy cập chức năng "${permission.name}".',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                'Vai trò hiện tại: ${user?.roleDisplayName ?? "Chưa xác định"}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              if (Navigator.canPop(context))
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Quay lại'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
