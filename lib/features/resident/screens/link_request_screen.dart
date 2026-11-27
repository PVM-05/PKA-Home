import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/link_request_provider.dart';
import '../widgets/accept_invitation_dialog.dart';

class LinkRequestScreen extends ConsumerStatefulWidget {
  const LinkRequestScreen({super.key});

  @override
  ConsumerState<LinkRequestScreen> createState() => _LinkRequestScreenState();
}

class _LinkRequestScreenState extends ConsumerState<LinkRequestScreen> {
  final _codeController = TextEditingController();
  String _relationRole = 'owner';
  bool _isSubmitting = false;
  bool _manualInputMode = false;

  String? _selectedBuilding;
  String? _selectedFloor;
  String? _selectedRoom;

  void _submit() async {
    final code = _codeController.text.trim().toUpperCase();
    final validationError = validateApartmentCode(code);
    if (validationError != null) {
      AppSnackBar.showWarning(context, validationError);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(residentLinkProvider.notifier)
          .submitRequest(code, _relationRole);
      if (mounted) {
        AppSnackBar.showSuccess(context, 'Đã gửi yêu cầu liên kết thành công!');
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, formatErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final linkState = ref.watch(residentLinkProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Liên kết căn hộ'),
        actions: [
          if (!Navigator.of(context).canPop())
            IconButton(
              tooltip: 'Đăng xuất',
              icon: const Icon(Icons.logout_outlined),
              onPressed: () => ref.read(authProvider.notifier).logout(),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 20.0,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: _buildContent(linkState),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ResidentLinkStatus linkState) {
    switch (linkState.status) {
      case LinkStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case LinkStatus.linked:
        // Nếu mở từ Profile (Navigator.canPop), cho phép gửi yêu cầu liên kết căn hộ khác
        if (Navigator.of(context).canPop()) {
          return _buildFormState();
        }
        return const Center(child: CircularProgressIndicator());
      case LinkStatus.pending:
        return _buildPendingState(linkState);
      case LinkStatus.rejected:
        return _buildRejectedState();
      case LinkStatus.none:
        return _buildFormState();
    }
  }

  Widget _buildPendingState(ResidentLinkStatus linkState) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final pendingColor = AppStatusColors.getPending(context);
    final semanticError = AppTheme.getSemanticError(context);

    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: pendingColor.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.schedule, size: 56, color: pendingColor),
          ),
          const SizedBox(height: 20),
          Text(
            'Đang chờ phê duyệt',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            linkState.apartmentCode != null
                ? 'Yêu cầu liên kết căn hộ ${linkState.apartmentCode} của bạn đã được gửi. Vui lòng chờ Ban quản lý xác nhận.'
                : 'Yêu cầu liên kết căn hộ của bạn đã được gửi. Vui lòng chờ Ban quản lý xác nhận.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                foregroundColor: semanticError,
                side: BorderSide(color: semanticError),
              ),
              onPressed: _isSubmitting
                  ? null
                  : () => _confirmCancelLinkRequest(linkState.requestId),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Hủy yêu cầu này'),
            ),
          ),
          if (Navigator.of(context).canPop()) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Quay lại'),
            ),
          ],
        ],
      ),
    );
  }

  void _confirmCancelLinkRequest(String? requestId) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Hủy Yêu Cầu Liên Kết'),
        content: const Text(
          'Bạn có chắc chắn muốn hủy yêu cầu liên kết căn hộ này? Bạn có thể gửi lại yêu cầu khác sau khi hủy.',
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Không'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(88, 48),
              backgroundColor: AppTheme.textError,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              setState(() => _isSubmitting = true);
              try {
                await ref
                    .read(residentLinkProvider.notifier)
                    .cancelPendingRequest(requestId);
                if (mounted) {
                  AppSnackBar.showSuccess(
                    context,
                    'Đã hủy yêu cầu liên kết căn hộ.',
                  );
                }
              } catch (e) {
                if (mounted) {
                  AppSnackBar.showError(
                    context,
                    formatErrorMessage(e),
                  );
                }
              } finally {
                if (mounted) setState(() => _isSubmitting = false);
              }
            },
            child: const Text('Xác nhận hủy'),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectedState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semanticError = AppTheme.getSemanticError(context);

    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: semanticError.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.error_outline, size: 56, color: semanticError),
          ),
          const SizedBox(height: 20),
          Text(
            'Yêu cầu bị từ chối',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: semanticError,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Ban quản lý đã từ chối yêu cầu liên kết căn hộ của bạn. Vui lòng kiểm tra lại mã căn hộ và thử lại.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
              onPressed: () =>
                  ref.read(residentLinkProvider.notifier).resetToForm(),
              child: const Text('Gửi lại yêu cầu'),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _dropdownDecoration(
    BuildContext context, {
    required String label,
    required IconData icon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: colorScheme.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: AppTheme.radiusMd,
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppTheme.radiusMd,
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    );
  }

  Widget _buildManualCodeField() {
    return AppTextField(
      controller: _codeController,
      labelText: 'Mã căn hộ (VD: A0110)',
      prefixIcon: const Icon(Icons.tag),
      textCapitalization: TextCapitalization.characters,
      textInputAction: TextInputAction.done,
      validator: validateApartmentCode,
      autovalidateMode: AutovalidateMode.onUserInteraction,
    );
  }

  Widget _buildFormState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final semanticWarning = AppTheme.getSemanticWarning(context);
    final semanticError = AppTheme.getSemanticError(context);

    return AppCard(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.apartment_outlined,
            size: 56,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Liên kết căn hộ của bạn',
            textAlign: TextAlign.center,
            style: context.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          ref
              .watch(availableApartmentsProvider)
              .when(
                data: (apartments) {
                  if (apartments.isEmpty) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: semanticWarning.withValues(
                              alpha: isDark ? 0.16 : 0.1,
                            ),
                            borderRadius: AppTheme.radiusMd,
                            border: Border.all(
                              color: semanticWarning.withValues(
                                alpha: isDark ? 0.45 : 0.35,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: semanticWarning,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Chưa tải được danh mục căn hộ tự động. Bạn có thể nhập trực tiếp mã căn hộ (VD: A0110) ở ô bên dưới.',
                                      style: context.bodySmall?.copyWith(
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(48, 48),
                                  ),
                                  icon: Icon(
                                    Icons.refresh,
                                    color: semanticWarning,
                                    size: 16,
                                  ),
                                  label: Text(
                                    'Tải lại danh mục',
                                    style: context.labelSmall?.copyWith(
                                      color: semanticWarning,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onPressed: () => ref.invalidate(
                                    availableApartmentsProvider,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildManualCodeField(),
                      ],
                    );
                  }

                  if (_manualInputMode) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildManualCodeField(),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48),
                            ),
                            onPressed: () {
                              setState(() {
                                _manualInputMode = false;
                                _codeController.clear();
                              });
                            },
                            icon: const Icon(Icons.list_alt, size: 16),
                            label: const Text('Chọn theo Tòa - Tầng - Phòng'),
                          ),
                        ),
                      ],
                    );
                  }

                  final buildings =
                      apartments.map((e) => e.building).toSet().toList()
                        ..sort();
                  final floors = _selectedBuilding == null
                      ? <String>[]
                      : (apartments
                              .where((e) => e.building == _selectedBuilding)
                              .map((e) => e.floor)
                              .toSet()
                              .toList()
                            ..sort());
                  final rooms = _selectedFloor == null
                      ? <ParsedApartment>[]
                      : (apartments
                              .where(
                                (e) =>
                                    e.building == _selectedBuilding &&
                                    e.floor == _selectedFloor,
                              )
                              .toList()
                            ..sort((a, b) => a.room.compareTo(b.room)));

                  return Column(
                    children: [
                      InputDecorator(
                        decoration: _dropdownDecoration(
                          context,
                          label: 'Tòa nhà',
                          icon: Icons.domain,
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedBuilding,
                            items: buildings
                                .map(
                                  (b) => DropdownMenuItem(
                                    value: b,
                                    child: Text(b),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedBuilding = val;
                                _selectedFloor = null;
                                _selectedRoom = null;
                                _codeController.clear();
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      InputDecorator(
                        decoration: _dropdownDecoration(
                          context,
                          label: 'Tầng',
                          icon: Icons.layers_outlined,
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedFloor,
                            items: floors
                                .map(
                                  (f) => DropdownMenuItem(
                                    value: f,
                                    child: Text(f),
                                  ),
                                )
                                .toList(),
                            onChanged: _selectedBuilding == null
                                ? null
                                : (val) {
                                    setState(() {
                                      _selectedFloor = val;
                                      _selectedRoom = null;
                                      _codeController.clear();
                                    });
                                  },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      InputDecorator(
                        decoration: _dropdownDecoration(
                          context,
                          label: 'Phòng',
                          icon: Icons.home_outlined,
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedRoom,
                            items: rooms
                                .map(
                                  (r) => DropdownMenuItem(
                                    value: r.code,
                                    child: Text(r.room),
                                  ),
                                )
                                .toList(),
                            onChanged: _selectedFloor == null
                                ? null
                                : (val) {
                                    setState(() {
                                      _selectedRoom = val;
                                      if (val != null) {
                                        _codeController.text = val;
                                      }
                                    });
                                  },
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          onPressed: () {
                            setState(() {
                              _manualInputMode = true;
                            });
                          },
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Nhập mã trực tiếp'),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, st) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: semanticError.withValues(
                          alpha: isDark ? 0.16 : 0.08,
                        ),
                        borderRadius: AppTheme.radiusMd,
                        border: Border.all(
                          color: semanticError.withValues(
                            alpha: isDark ? 0.45 : 0.35,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: semanticError,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Không thể tải danh mục căn hộ. Bạn có thể nhập trực tiếp mã căn hộ ở ô bên dưới.',
                                  style: context.bodySmall?.copyWith(
                                    color: semanticError,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              style: TextButton.styleFrom(
                                minimumSize: const Size(48, 48),
                              ),
                              icon: Icon(
                                Icons.refresh,
                                color: semanticError,
                                size: 16,
                              ),
                              label: Text(
                                'Tải lại danh mục',
                                style: context.labelSmall?.copyWith(
                                  color: semanticError,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: () => ref.invalidate(
                                availableApartmentsProvider,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildManualCodeField(),
                  ],
                ),
              ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _relationRole,
            decoration: _dropdownDecoration(
              context,
              label: 'Vai trò',
              icon: Icons.person_outline,
            ),
            items: const [
              DropdownMenuItem(value: 'owner', child: Text('Chủ hộ')),
              DropdownMenuItem(value: 'tenant', child: Text('Khách thuê')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _relationRole = val);
            },
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Gửi yêu cầu'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: Divider(color: colorScheme.outlineVariant)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'HOẶC',
                  style: context.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(child: Divider(color: colorScheme.outlineVariant)),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (_) => const AcceptInvitationDialog(),
              );
            },
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('Gia nhập bằng mã mời'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }
}
