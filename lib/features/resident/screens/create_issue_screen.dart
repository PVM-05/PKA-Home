import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/utils/issue_smart_triage_engine.dart';
import '../../../core/supabase_config.dart';
import '../../../data/providers/resident_apartment_provider.dart';
import '../../../data/providers/resident_issue_provider.dart';
import '../../../data/repositories/issue_repository.dart';

class CreateIssueScreen extends ConsumerStatefulWidget {
  const CreateIssueScreen({super.key});

  @override
  ConsumerState<CreateIssueScreen> createState() => _CreateIssueScreenState();
}

class _CreateIssueScreenState extends ConsumerState<CreateIssueScreen> {
  final _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final List<File> _imageFiles = [];
  bool _isLoading = false;
  String _selectedCategory = 'electrical';
  String _selectedPriority = 'low';
  IssueTriageResult? _triageResult;

  @override
  void initState() {
    super.initState();
    _descriptionController.addListener(_onDescriptionChanged);
  }

  @override
  void dispose() {
    _descriptionController.removeListener(_onDescriptionChanged);
    _descriptionController.dispose();
    super.dispose();
  }

  void _onDescriptionChanged() {
    final text = _descriptionController.text.trim();
    if (text.length >= 6) {
      final result = IssueSmartTriageEngine.triage(text);
      if (mounted) {
        setState(() {
          _triageResult = result;
        });
      }
    } else if (_triageResult != null) {
      if (mounted) {
        setState(() {
          _triageResult = null;
        });
      }
    }
  }

  Future<void> _callHotline() async {
    final uri = Uri.parse('tel:02439998888');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Hotline Ban Quản Lý: 024.3999.8888 (24/7)'),
              backgroundColor: AppTheme.primary,
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hotline Ban Quản Lý: 024.3999.8888 (24/7)'),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final remaining = 3 - _imageFiles.length;
    if (remaining <= 0) return;

    if (source == ImageSource.camera) {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
      if (image != null) {
        setState(() {
          _imageFiles.add(File(image.path));
        });
      }
    } else {
      if (remaining == 1) {
        final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
        if (image != null) {
          setState(() {
            _imageFiles.add(File(image.path));
          });
        }
      } else {
        final List<XFile> images = await _picker.pickMultiImage(limit: remaining, imageQuality: 80);
        if (images.isNotEmpty) {
          setState(() {
            for (final img in images.take(remaining)) {
              _imageFiles.add(File(img.path));
            }
          });
        }
      }
    }
  }

  void _showImageSourceDialog() {
    if (_imageFiles.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã đạt tối đa 3 hình ảnh cho mỗi phản ánh'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Chọn nguồn ảnh',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppTheme.primary),
                title: const Text('Chụp ảnh mới'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppTheme.primary),
                title: const Text('Chọn từ Thư viện ảnh'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập mô tả sự cố'), backgroundColor: AppTheme.warning),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = SupabaseConfig.client.auth.currentUser;
      if (user == null) throw Exception('Chưa đăng nhập');

      final currentApartment = ref.read(currentSelectedApartmentProvider);
      final activeAptId = currentApartment?['apartment_id'] as String? ?? ref.read(selectedApartmentIdProvider);

      final issueRepo = ref.read(issueRepositoryProvider);
      final result = await issueRepo.createIssue(
        reporterId: user.id,
        apartmentId: activeAptId,
        description: description,
        priority: _selectedPriority,
        category: _selectedCategory,
        imageFiles: _imageFiles,
        aiCategoryConfidence: _triageResult?.confidence,
        aiSuggestedCategory: _triageResult?.category,
        aiSuggestedPriority: _triageResult?.priority,
        aiTriageReason: _triageResult?.reason,
        isHazardous: _triageResult?.isHazardous ?? false,
        autoAssign: true,
      );

      ref.invalidate(residentIssueProvider);

      if (mounted) {
        if (result.imageUploadFailed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã gửi phản ánh nhưng ảnh tải lên thất bại, vui lòng thử đính kèm lại sau'),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gửi phản ánh thành công!'), backgroundColor: AppTheme.success),
          );
        }
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(formatErrorMessage(e)), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gửi Phản Ánh'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Chuyên môn sự cố:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: const Key('issue_category_dropdown'),
              initialValue: _selectedCategory,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.handyman_outlined),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(value: 'electrical', child: Text('Điện / Thiết bị điện')),
                DropdownMenuItem(value: 'plumbing', child: Text('Nước / Thiết bị vệ sinh')),
                DropdownMenuItem(value: 'construction', child: Text('Xây dựng / Cửa / Sơn bả')),
                DropdownMenuItem(value: 'elevator', child: Text('Thang máy / Cửa từ')),
                DropdownMenuItem(value: 'fire_safety', child: Text('PCCC & Cảnh báo an toàn')),
                DropdownMenuItem(value: 'other', child: Text('Sự cố khác')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedCategory = val);
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Mức độ khẩn cấp & Cam kết SLA:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              key: const Key('issue_priority_segmented'),
              segments: const [
                ButtonSegment(value: 'low', label: Text('Thường (72h)')),
                ButtonSegment(value: 'medium', label: Text('Ưu tiên (24h)')),
                ButtonSegment(value: 'high', label: Text('Khẩn cấp (2h)')),
              ],
              selected: {_selectedPriority},
              onSelectionChanged: (set) {
                setState(() => _selectedPriority = set.first);
              },
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _selectedPriority == 'high'
                    ? AppTheme.error.withValues(alpha: 0.1)
                    : (_selectedPriority == 'medium' ? Colors.orange.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.08)),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _selectedPriority == 'high'
                      ? AppTheme.error.withValues(alpha: 0.3)
                      : (_selectedPriority == 'medium' ? Colors.orange.withValues(alpha: 0.3) : Colors.blue.withValues(alpha: 0.2)),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _selectedPriority == 'high'
                        ? Icons.timer_outlined
                        : Icons.info_outline,
                    size: 18,
                    color: _selectedPriority == 'high'
                        ? AppTheme.error
                        : (_selectedPriority == 'medium' ? Colors.orange.shade800 : Colors.blue.shade800),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedPriority == 'high'
                          ? 'Cam kết SLA: Tiếp nhận và xử lý trong vòng 2 giờ (Chập cháy điện, vỡ ống nước, kẹt thang).'
                          : (_selectedPriority == 'medium'
                              ? 'Cam kết SLA: Đội kỹ thuật xử lý trong vòng 24 giờ.'
                              : 'Cam kết SLA: Xử lý theo lịch bảo trì định kỳ trong vòng 72 giờ.'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _selectedPriority == 'high'
                            ? AppTheme.error
                            : (_selectedPriority == 'medium' ? Colors.orange.shade800 : Colors.blue.shade800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Vui lòng mô tả sự cố hoặc yêu cầu hỗ trợ:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('issue_description_field'),
              controller: _descriptionController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Ví dụ: Bóng đèn hành lang tầng 5 bị cháy, hoặc vỡ ống nước...',
                alignLabelWithHint: true,
              ),
            ),
            if (_triageResult != null) ...[
              const SizedBox(height: 12),
              if (_triageResult!.isHazardous)
                Container(
                  key: const Key('ai_hazardous_alert_banner'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.error, width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'CẢNH BÁO NGUY HIỂM KHẨN CẤP',
                              style: TextStyle(
                                color: AppTheme.error,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _triageResult!.reason,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          key: const Key('call_hotline_emergency_button'),
                          onPressed: _callHotline,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.error,
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.phone_in_talk, size: 16),
                          label: const Text(
                            'GỌI HOTLINE KHẨN CẤP BQL (24/7): 024.3999.8888',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  key: const Key('ai_suggestion_banner'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: AppTheme.primary, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Gợi ý phân loại tự động',
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          TextButton(
                            key: const Key('apply_ai_suggestion_button'),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            onPressed: () {
                              setState(() {
                                _selectedCategory = _triageResult!.category;
                                _selectedPriority = _triageResult!.priority;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Đã tự động áp dụng phân loại và mức ưu tiên theo AI!'),
                                  duration: Duration(seconds: 2),
                                  backgroundColor: AppTheme.primary,
                                ),
                              );
                            },
                            child: const Text('Áp dụng gợi ý', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      Text(
                        'Đề xuất: ${_triageResult!.suggestedStaffRole} • Ưu tiên: ${_triageResult!.priorityDisplayName}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _triageResult!.reason,
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Đính kèm hình ảnh (Tối đa 3 ảnh):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  '${_imageFiles.length}/3',
                  style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_imageFiles.isEmpty)
              GestureDetector(
                onTap: _showImageSourceDialog,
                child: Container(
                  height: 140,
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined, size: 40, color: AppTheme.primary),
                      SizedBox(height: 8),
                      Text(
                        '+ Chọn ảnh từ máy',
                        style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '(Chụp ảnh hoặc chọn từ thư viện - Tối đa 3 ảnh)',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ..._imageFiles.asMap().entries.map((entry) {
                    final index = entry.key;
                    final file = entry.value;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            file,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: -6,
                          right: -6,
                          child: Material(
                            color: Colors.black87,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () {
                                setState(() {
                                  _imageFiles.removeAt(index);
                                });
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(4.0),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                  if (_imageFiles.length < 3)
                    GestureDetector(
                      onTap: _showImageSourceDialog,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5)),
                          borderRadius: BorderRadius.circular(12),
                          color: AppTheme.primary.withValues(alpha: 0.05),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, color: AppTheme.primary, size: 28),
                            SizedBox(height: 4),
                            Text(
                              'Thêm ảnh',
                              style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 32),
            ElevatedButton(
              key: const Key('submit_issue_button'),
              onPressed: _isLoading ? null : _submit,
              child: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('GỬI YÊU CẦU'),
            ),
          ],
        ),
      ),
    );
  }
}
