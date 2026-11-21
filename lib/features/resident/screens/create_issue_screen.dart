import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/supabase_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/utils/issue_smart_triage_engine.dart';
import '../../../core/widgets/app_form_scaffold.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../data/providers/resident_apartment_provider.dart';
import '../../../data/providers/resident_issue_provider.dart';
import '../../../data/repositories/issue_repository.dart';

class CreateIssueScreen extends ConsumerStatefulWidget {
  const CreateIssueScreen({super.key});

  @override
  ConsumerState<CreateIssueScreen> createState() => _CreateIssueScreenState();
}

class _CreateIssueScreenState extends ConsumerState<CreateIssueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _descriptionFieldKey = GlobalKey();
  final _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final List<File> _imageFiles = [];
  bool _isLoading = false;
  String _selectedCategory = 'electrical';
  String _selectedPriority = 'low';
  IssueTriageResult? _triageResult;

  bool get _hasUnsavedChanges =>
      _descriptionController.text.trim().isNotEmpty ||
      _imageFiles.isNotEmpty ||
      _selectedCategory != 'electrical' ||
      _selectedPriority != 'low';

  @override
  void initState() {
    super.initState();
    _descriptionController.addListener(_onDescriptionChanged);
  }

  @override
  void dispose() {
    _descriptionController.removeListener(_onDescriptionChanged);
    _descriptionController.dispose();
    _scrollController.dispose();
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

  Future<void> _callNumber(String phoneNumber, String label) async {
    final uri = Uri.parse('tel:$phoneNumber');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          AppSnackBar.showInfo(context, '$label: $phoneNumber');
        }
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.showInfo(context, '$label: $phoneNumber');
      }
    }
  }

  Future<void> _callHotline() =>
      _callNumber('02439998888', 'Hotline Ban Quản Lý (24/7)');
  Future<void> _callFireEmergency() =>
      _callNumber('114', 'Cứu hỏa & Cứu nạn PCCC');
  Future<void> _callMedicalEmergency() => _callNumber('115', 'Cấp cứu y tế');

  Future<void> _pickImage(ImageSource source) async {
    final remaining = 3 - _imageFiles.length;
    if (remaining <= 0) return;

    if (source == ImageSource.camera) {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      if (image != null) {
        setState(() {
          _imageFiles.add(File(image.path));
        });
      }
    } else {
      if (remaining == 1) {
        final XFile? image = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 80,
        );
        if (image != null) {
          setState(() {
            _imageFiles.add(File(image.path));
          });
        }
      } else {
        final List<XFile> images = await _picker.pickMultiImage(
          limit: remaining,
          imageQuality: 80,
        );
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
      AppSnackBar.showInfo(
        context,
        'Đã đạt tối đa 3 hình ảnh cho mỗi phản ánh',
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Chọn nguồn ảnh',
                  style: ctx.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: Icon(
                    Icons.camera_alt_outlined,
                    color: colorScheme.primary,
                  ),
                  title: const Text('Chụp ảnh mới'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.photo_library_outlined,
                    color: colorScheme.primary,
                  ),
                  title: const Text('Chọn từ Thư viện ảnh'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      final descContext = _descriptionFieldKey.currentContext;
      if (descContext != null) {
        Scrollable.ensureVisible(
          descContext,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
      return;
    }
    final description = _descriptionController.text.trim();

    setState(() {
      _isLoading = true;
    });

    try {
      final user = SupabaseConfig.client.auth.currentUser;
      if (user == null) throw Exception('Chưa đăng nhập');

      final currentApartment = ref.read(currentSelectedApartmentProvider);
      final activeAptId =
          currentApartment?['apartment_id'] as String? ??
          ref.read(selectedApartmentIdProvider);

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
      ref.invalidate(residentIssuePaginatedProvider);

      if (mounted) {
        if (result.imageUploadFailed) {
          AppSnackBar.showWarning(
            context,
            'Đã gửi phản ánh nhưng ảnh tải lên thất bại, vui lòng thử đính kèm lại sau',
          );
        } else {
          AppSnackBar.showSuccess(
            context,
            'Gửi phản ánh thành công!',
          );
        }
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          formatErrorMessage(e),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final semanticError = AppTheme.getSemanticError(context);
    final semanticWarning = AppTheme.getSemanticWarning(context);
    final semanticSecondary = AppTheme.getSemanticSecondary(context);

    final slaColor = _selectedPriority == 'high'
        ? semanticError
        : (_selectedPriority == 'medium' ? semanticWarning : semanticSecondary);

    return AppFormScaffold(
      title: 'Gửi Phản Ánh',
      hasUnsavedChanges: _hasUnsavedChanges,
      primaryButtonKey: const Key('submit_issue_button'),
      primaryButtonLabel: 'GỬI YÊU CẦU',
      onPrimaryPressed: _submit,
      isPrimaryLoading: _isLoading,
      scrollController: _scrollController,
      maxWidth: 800,
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Chuyên môn sự cố:',
              style: context.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: const Key('issue_category_dropdown'),
              isExpanded: true,
              initialValue: _selectedCategory,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.handyman_outlined),
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
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'electrical',
                  child: Text('Điện / Thiết bị điện'),
                ),
                DropdownMenuItem(
                  value: 'plumbing',
                  child: Text('Nước / Thiết bị vệ sinh'),
                ),
                DropdownMenuItem(
                  value: 'construction',
                  child: Text('Xây dựng / Cửa / Sơn bả'),
                ),
                DropdownMenuItem(
                  value: 'elevator',
                  child: Text('Thang máy / Cửa từ'),
                ),
                DropdownMenuItem(
                  value: 'fire_safety',
                  child: Text('PCCC & Cảnh báo an toàn'),
                ),
                DropdownMenuItem(value: 'other', child: Text('Sự cố khác')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedCategory = val);
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Mức độ khẩn cấp & Cam kết SLA:',
              style: context.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: SegmentedButton<String>(
                      key: const Key('issue_priority_segmented'),
                      segments: const [
                        ButtonSegment(value: 'low', label: Text('Thường (72h)')),
                        ButtonSegment(
                          value: 'medium',
                          label: Text('Ưu tiên (24h)'),
                        ),
                        ButtonSegment(
                          value: 'high',
                          label: Text('Khẩn cấp (2h)'),
                        ),
                      ],
                      selected: {_selectedPriority},
                      onSelectionChanged: (set) {
                        setState(() => _selectedPriority = set.first);
                      },
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: slaColor.withValues(alpha: isDark ? 0.16 : 0.09),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: slaColor.withValues(alpha: isDark ? 0.4 : 0.28),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _selectedPriority == 'high'
                        ? Icons.timer_outlined
                        : Icons.info_outline,
                    size: 18,
                    color: slaColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedPriority == 'high'
                          ? 'Cam kết SLA: Tiếp nhận và xử lý trong vòng 2 giờ (Chập cháy điện, vỡ ống nước, kẹt thang).'
                          : (_selectedPriority == 'medium'
                                ? 'Cam kết SLA: Đội kỹ thuật xử lý trong vòng 24 giờ.'
                                : 'Cam kết SLA: Xử lý theo lịch bảo trì định kỳ trong vòng 72 giờ.'),
                      style: context.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: slaColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Vui lòng mô tả sự cố hoặc yêu cầu hỗ trợ:',
              style: context.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            KeyedSubtree(
              key: _descriptionFieldKey,
              child: AppTextField(
                key: const Key('issue_description_field'),
                controller: _descriptionController,
                maxLines: 5,
                minLines: 4,
                hintText: 'Ví dụ: Bóng đèn hành lang tầng 5 bị cháy...',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập chi tiết mô tả sự cố';
                  }
                  return null;
                },
              ),
            ),
            if (_triageResult != null) ...[
              const SizedBox(height: 12),
              if (_triageResult!.isHazardous)
                _buildHazardousAlertBanner(context, isDark, semanticError)
              else
                _buildAiSuggestionBanner(context, isDark),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Đính kèm hình ảnh (Tối đa 3 ảnh):',
                    style: context.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_imageFiles.length}/3',
                  style: context.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_imageFiles.isEmpty)
              InkWell(
                onTap: _showImageSourceDialog,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                    color: colorScheme.surfaceContainerLow,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo_outlined,
                        size: 40,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '+ Chọn ảnh từ máy',
                        style: context.labelLarge?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '(Chụp ảnh hoặc chọn từ thư viện - Tối đa 3 ảnh)',
                        textAlign: TextAlign.center,
                        style: context.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
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
                          top: -8,
                          right: -8,
                          child: IconButton(
                            tooltip: 'Xóa ảnh',
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 40,
                            ),
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              setState(() {
                                _imageFiles.removeAt(index);
                              });
                            },
                            icon: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.72),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                  if (_imageFiles.length < 3)
                    InkWell(
                      onTap: _showImageSourceDialog,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: colorScheme.primary.withValues(alpha: 0.5),
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color: colorScheme.primary.withValues(
                            alpha: isDark ? 0.12 : 0.05,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              color: colorScheme.primary,
                              size: 28,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Thêm ảnh',
                              style: context.labelSmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHazardousAlertBanner(
    BuildContext context,
    bool isDark,
    Color semanticError,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('ai_hazardous_alert_banner'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: semanticError.withValues(alpha: isDark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: semanticError, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: semanticError,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'CẢNH BÁO NGUY HIỂM KHẨN CẤP',
                  style: context.titleSmall?.copyWith(
                    color: semanticError,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _triageResult!.reason,
            style: context.bodySmall?.copyWith(color: colorScheme.onSurface),
          ),
          const SizedBox(height: 12),
          if (_triageResult!.isFireHazard) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    key: const Key('call_114_button'),
                    onPressed: _callFireEmergency,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      backgroundColor: AppTheme.textError,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.local_fire_department, size: 16),
                    label: Text(
                      'GỌI 114 (CỨU HỎA)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('call_hotline_emergency_button'),
                    onPressed: _callHotline,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      foregroundColor: semanticError,
                      side: BorderSide(color: semanticError),
                    ),
                    icon: const Icon(Icons.phone_in_talk, size: 16),
                    label: Text(
                      'GỌI TRỰC BAN BQL',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.labelSmall?.copyWith(
                        color: semanticError,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (_triageResult!.isTrappedPersonHazard) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    key: const Key('call_114_rescue_button'),
                    onPressed: _callFireEmergency,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      backgroundColor: AppTheme.textError,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.emergency, size: 16),
                    label: Text(
                      'GỌI 114 (CỨU NẠN)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    key: const Key('call_115_button'),
                    onPressed: _callMedicalEmergency,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      backgroundColor: AppTheme.textSuccess,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.medical_services, size: 16),
                    label: Text(
                      'GỌI 115 (CẤP CỨU)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('call_hotline_emergency_button'),
                onPressed: _callHotline,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  foregroundColor: semanticError,
                  side: BorderSide(color: semanticError),
                ),
                icon: const Icon(Icons.phone_in_talk, size: 16),
                label: Text(
                  'GỌI TRỰC BAN BQL: 024.3999.8888',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.labelSmall?.copyWith(
                    color: semanticError,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const Key('call_hotline_emergency_button'),
                onPressed: _callHotline,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  backgroundColor: AppTheme.textError,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.phone_in_talk, size: 16),
                label: Text(
                  'GỌI HOTLINE KHẨN CẤP BQL (24/7): 024.3999.8888',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAiSuggestionBanner(BuildContext context, bool isDark) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('ai_suggestion_banner'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: isDark ? 0.16 : 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: isDark ? 0.45 : 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: colorScheme.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Gợi ý phân loại tự động',
                  style: context.titleSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton(
                key: const Key('apply_ai_suggestion_button'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onPressed: () {
                  setState(() {
                    _selectedCategory = _triageResult!.category;
                    _selectedPriority = _triageResult!.priority;
                  });
                  AppSnackBar.showSuccess(
                    context,
                    'Đã tự động áp dụng phân loại và mức ưu tiên gợi ý!',
                  );
                },
                child: const Text(
                  'Áp dụng gợi ý',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          Text(
            'Đề xuất: ${_triageResult!.suggestedStaffRole} • Ưu tiên: ${_triageResult!.priorityDisplayName}',
            style: context.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _triageResult!.reason,
            style: context.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
