import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/providers/resident_lifecycle_provider.dart';

class CreateApartmentInvitationSheet extends ConsumerStatefulWidget {
  final String apartmentId;
  final String apartmentCode;

  const CreateApartmentInvitationSheet({
    super.key,
    required this.apartmentId,
    required this.apartmentCode,
  });

  @override
  ConsumerState<CreateApartmentInvitationSheet> createState() =>
      _CreateApartmentInvitationSheetState();
}

class _CreateApartmentInvitationSheetState
    extends ConsumerState<CreateApartmentInvitationSheet> {
  String _selectedRole = 'member';
  int _selectedHours = 48;
  bool _isLoading = false;
  Map<String, dynamic>? _createdInvite;

  Future<void> _handleCreateInvite() async {
    setState(() => _isLoading = true);
    final repo = ref.read(residentLifecycleRepositoryProvider);
    final res = await repo.createInvitation(
      apartmentId: widget.apartmentId,
      targetRole: _selectedRole,
      expiresHours: _selectedHours,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res['success'] == true) {
          _createdInvite = res;
        }
      });
      ref.invalidate(apartmentInvitationsProvider(widget.apartmentId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.qr_code_2_rounded, color: AppTheme.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mã Mời Căn Hộ ${widget.apartmentCode}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        'Mời cư dân / người thuê kích hoạt tự phục vụ',
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 24),

            if (_createdInvite == null) ...[
              const Text(
                'Vai trò người được mời',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'member',
                    label: Text('Thành viên ở cùng'),
                    icon: Icon(Icons.person_outline),
                  ),
                  ButtonSegment(
                    value: 'tenant',
                    label: Text('Người thuê'),
                    icon: Icon(Icons.key_outlined),
                  ),
                ],
                selected: {_selectedRole},
                onSelectionChanged: (set) {
                  setState(() => _selectedRole = set.first);
                },
              ),
              const SizedBox(height: 16),

              const Text(
                'Thời hạn mã mời',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: _selectedHours,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                items: const [
                  DropdownMenuItem(value: 24, child: Text('24 giờ')),
                  DropdownMenuItem(value: 48, child: Text('48 giờ (2 ngày)')),
                  DropdownMenuItem(value: 168, child: Text('7 ngày')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedHours = val);
                },
              ),
              const SizedBox(height: 24),

              FilledButton.icon(
                onPressed: _isLoading ? null : _handleCreateInvite,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.generating_tokens_outlined, size: 20),
                label: const Text('Tạo Mã Mời & Mã QR'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ] else ...[
              // Hiển thị mã mời đã tạo
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: QrImageView(
                        data: 'https://pkahome.vn/invite?code=${_createdInvite!['invite_code']}',
                        version: QrVersions.auto,
                        size: 160.0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'MÃ KÍCH HOẠT',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      _createdInvite!['invite_code'] ?? '',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                        color: AppTheme.primary,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Hiệu lực: $_selectedHours giờ • Vai trò: ${_selectedRole == 'tenant' ? 'Người thuê' : 'Thành viên'}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _createdInvite!['invite_code'] ?? ''));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã sao chép mã mời vào bộ nhớ đệm')),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Sao chép mã'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        final link = 'https://pkahome.vn/invite?code=${_createdInvite!['invite_code']}';
                        Clipboard.setData(ClipboardData(text: link));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã sao chép liên kết mời')),
                        );
                      },
                      icon: const Icon(Icons.share_outlined, size: 18),
                      label: const Text('Sao chép link'),
                      style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
