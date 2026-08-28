import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/link_request_provider.dart';

class LinkRequestScreen extends ConsumerStatefulWidget {
  const LinkRequestScreen({super.key});

  @override
  ConsumerState<LinkRequestScreen> createState() => _LinkRequestScreenState();
}

class _LinkRequestScreenState extends ConsumerState<LinkRequestScreen> {
  final _codeController = TextEditingController();
  String _relationRole = 'owner';
  bool _isSubmitting = false;

  String? _selectedBuilding;
  String? _selectedFloor;
  String? _selectedRoom;

  void _submit() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập mã căn hộ'), backgroundColor: AppTheme.warning),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(residentLinkProvider.notifier).submitRequest(code, _relationRole);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã gửi yêu cầu liên kết thành công!'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppTheme.error),
        );
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
              icon: const Icon(FluentIcons.sign_out_24_regular),
              onPressed: () => ref.read(authProvider.notifier).logout(),
            )
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: _buildContent(linkState.status),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(LinkStatus status) {
    switch (status) {
      case LinkStatus.loading:
      case LinkStatus.linked: // Màn hình này không nên hiển thị nếu đã linked, nhưng phòng hờ
        return const Center(child: CircularProgressIndicator());
      case LinkStatus.pending:
        return _buildPendingState();
      case LinkStatus.rejected:
        return _buildRejectedState();
      case LinkStatus.none:
        return _buildFormState();
    }
  }

  Widget _buildPendingState() {
    return Column(
      children: [
        const Icon(FluentIcons.clock_24_regular, size: 80, color: Colors.orange),
        const SizedBox(height: 24),
        Text(
          'Đang chờ phê duyệt',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppTheme.primary),
        ),
        const SizedBox(height: 16),
        const Text(
          'Yêu cầu liên kết căn hộ của bạn đã được gửi. Vui lòng chờ Ban quản lý xác nhận.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRejectedState() {
    return Column(
      children: [
        const Icon(FluentIcons.error_circle_24_regular, size: 80, color: AppTheme.error),
        const SizedBox(height: 24),
        Text(
          'Yêu cầu bị từ chối',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppTheme.error),
        ),
        const SizedBox(height: 16),
        const Text(
          'Ban quản lý đã từ chối yêu cầu liên kết căn hộ của bạn. Vui lòng kiểm tra lại mã căn hộ và thử lại.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => ref.read(residentLinkProvider.notifier).resetToForm(),
          child: const Text('Gửi lại yêu cầu'),
        ),
      ],
    );
  }

  Widget _buildFormState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(FluentIcons.building_home_24_regular, size: 60, color: AppTheme.primary),
            const SizedBox(height: 16),
            const Text(
              'Liên kết căn hộ của bạn',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ref.watch(availableApartmentsProvider).when(
              data: (apartments) {
                if (apartments.isEmpty) {
                  return const Card(
                    color: Color(0xFFFFF3CD),
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Icon(FluentIcons.warning_24_regular, color: Color(0xFF856404), size: 32),
                          SizedBox(height: 8),
                          Text(
                            'Không tải được danh sách căn hộ.\nVui lòng kiểm tra RLS Policy của bảng "apartments" trên Supabase.\nCần cấp quyền SELECT cho user.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF856404)),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final buildings = apartments.map((e) => e.building).toSet().toList()..sort();
                final floors = _selectedBuilding == null 
                  ? <String>[] 
                  : apartments.where((e) => e.building == _selectedBuilding).map((e) => e.floor).toSet().toList()..sort();
                final rooms = _selectedFloor == null 
                  ? <ParsedApartment>[] 
                  : apartments.where((e) => e.building == _selectedBuilding && e.floor == _selectedFloor).toList()..sort((a,b) => a.room.compareTo(b.room));

                return Column(
                  children: [
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Tòa nhà',
                        prefixIcon: Icon(FluentIcons.building_24_regular),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedBuilding,
                          items: buildings.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
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
                      decoration: const InputDecoration(
                        labelText: 'Tầng',
                        prefixIcon: Icon(FluentIcons.layer_24_regular),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedFloor,
                          items: floors.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                          onChanged: _selectedBuilding == null ? null : (val) {
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
                      decoration: const InputDecoration(
                        labelText: 'Phòng',
                        prefixIcon: Icon(FluentIcons.home_24_regular),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedRoom,
                          items: rooms.map((r) => DropdownMenuItem(value: r.code, child: Text(r.room))).toList(),
                          onChanged: _selectedFloor == null ? null : (val) {
                            setState(() {
                              _selectedRoom = val;
                              if (val != null) _codeController.text = val;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, st) => TextField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Mã căn hộ (VD: A101)',
                  prefixIcon: Icon(FluentIcons.number_symbol_24_regular),
                ),
                textInputAction: TextInputAction.done,
              ),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: _relationRole,
              decoration: const InputDecoration(
                labelText: 'Vai trò',
                prefixIcon: Icon(FluentIcons.person_24_regular),
              ),
              items: const [
                DropdownMenuItem(value: 'owner', child: Text('Chủ hộ')),
                DropdownMenuItem(value: 'tenant', child: Text('Khách thuê')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _relationRole = val);
              },
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Gửi yêu cầu'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }
}
