import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/supabase_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_form_scaffold.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/app_storage_image.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../data/models/issue_model.dart';
import '../../../data/providers/resident_issue_provider.dart';
import '../../../data/repositories/issue_repository.dart';

/// Màn hình chỉnh sửa phản ánh sự cố cư dân.
/// Hỗ trợ chuẩn B2B SaaS:
/// - Desktop (>= 900dp): Giới hạn độ rộng biểu mẫu maxWidth: 720dp, căn giữa thanh lịch.
/// - Mobile (< 900dp): Thẻ AppCard viền mỏng, Sticky CTA 48dp, chống tràn 100% trên 320dp (Text Zoom 1.3x).
class EditIssueScreen extends ConsumerStatefulWidget {
  final IssueModel issue;

  const EditIssueScreen({super.key, required this.issue});

  @override
  ConsumerState<EditIssueScreen> createState() => _EditIssueScreenState();
}

class _EditIssueScreenState extends ConsumerState<EditIssueScreen> {
  late final TextEditingController _descriptionController;
  final ImagePicker _picker = ImagePicker();
  late List<String> _existingImages;
  final List<String> _removedImageUrls = [];
  final List<File> _newImageFiles = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(
      text: widget.issue.description,
    );
    _existingImages = List.from(widget.issue.imageUrls);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  int get _totalImageCount => _existingImages.length + _newImageFiles.length;

  bool get _hasUnsavedChanges =>
      _descriptionController.text.trim() != widget.issue.description.trim() ||
      _newImageFiles.isNotEmpty ||
      _removedImageUrls.isNotEmpty;

  Future<void> _pickImage(ImageSource source) async {
    final remaining = 3 - _totalImageCount;
    if (remaining <= 0) return;

    if (source == ImageSource.camera) {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      if (image != null) {
        setState(() {
          _newImageFiles.add(File(image.path));
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
            _newImageFiles.add(File(image.path));
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
              _newImageFiles.add(File(img.path));
            }
          });
        }
      }
    }
  }

  void _showImageSourceDialog() {
    if (_totalImageCount >= 3) {
      AppSnackBar.showWarning(
        context,
        'Đã đạt tối đa 3 hình ảnh cho mỗi phản ánh',
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.add_photo_alternate_outlined,
                        color: colorScheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Chọn nguồn hình ảnh',
                        style: ctx.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                ListTile(
                  leading: Icon(
                    Icons.camera_alt_outlined,
                    color: colorScheme.primary,
                  ),
                  title: const Text(
                    'Chụp ảnh mới',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Sử dụng máy ảnh thiết bị để chụp hiện trường',
                  ),
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
                  title: const Text(
                    'Chọn từ thư viện ảnh',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Tải ảnh đã lưu từ bộ sưu tập của bạn',
                  ),
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

  Future<void> _submitUpdate() async {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      AppSnackBar.showWarning(context, 'Vui lòng nhập mô tả sự cố');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = SupabaseConfig.client.auth.currentUser;
      if (user == null) throw Exception('Chưa đăng nhập');

      final issueRepo = ref.read(issueRepositoryProvider);
      await issueRepo.updateIssue(
        issueId: widget.issue.id,
        reporterId: user.id,
        description: description,
        removedImageUrls: _removedImageUrls.isNotEmpty
            ? _removedImageUrls
            : null,
        newImageFiles: _newImageFiles.isNotEmpty ? _newImageFiles : null,
      );

      ref.invalidate(residentIssueProvider);

      if (mounted) {
        AppSnackBar.showSuccess(context, 'Cập nhật phản ánh thành công!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, formatErrorMessage(e));
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
    final semanticWarning = AppTheme.getSemanticWarning(context);
    final countBadgeColor = _totalImageCount >= 3
        ? semanticWarning
        : colorScheme.primary;

    return AppFormScaffold(
      title: 'Chỉnh sửa phản ánh',
      hasUnsavedChanges: _hasUnsavedChanges,
      primaryButtonLabel: 'Lưu thay đổi',
      onPrimaryPressed: _submitUpdate,
      isPrimaryLoading: _isLoading,
      maxWidth: 720,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Khối 1: Thẻ mô tả sự cố
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Mô tả sự cố',
                        style: context.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Cung cấp thông tin chi tiết giúp đội ngũ kỹ thuật xử lý nhanh chóng.',
                  style: context.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _descriptionController,
                  maxLines: 5,
                  minLines: 4,
                  hintText: 'Nhập chi tiết về sự cố bạn đang gặp phải...',
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Khối 2: Thẻ hình ảnh đính kèm
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.photo_library_outlined,
                            size: 20,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Hình ảnh đính kèm',
                              style: context.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: countBadgeColor.withValues(
                          alpha: isDark ? 0.2 : 0.1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$_totalImageCount/3 ảnh',
                        style: context.labelSmall?.copyWith(
                          color: countBadgeColor,
                          fontWeight: FontWeight.bold,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Hình ảnh chụp trực tiếp tại hiện trường giúp thẩm định chính xác sự cố.',
                  style: context.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),

                // Grid hiển thị ảnh hiện có + ảnh mới + nút thêm
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    // 1. Ảnh hiện có từ Server
                    ..._existingImages.map((imageUrl) {
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AppStorageImage(
                            imageUrl: imageUrl,
                            width: 104,
                            height: 104,
                            fit: BoxFit.cover,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          Positioned(
                            top: -6,
                            right: -6,
                            child: IconButton(
                              tooltip: 'Xóa ảnh',
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                setState(() {
                                  _existingImages.remove(imageUrl);
                                  _removedImageUrls.add(imageUrl);
                                });
                              },
                              icon: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.72),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),

                    // 2. Ảnh mới thêm từ máy
                    ..._newImageFiles.map((file) {
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              file,
                              width: 104,
                              height: 104,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: -6,
                            right: -6,
                            child: IconButton(
                              tooltip: 'Xóa ảnh',
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                setState(() {
                                  _newImageFiles.remove(file);
                                });
                              },
                              icon: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.72),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),

                    // 3. Nút thêm ảnh nếu chưa đủ 3
                    if (_totalImageCount < 3)
                      InkWell(
                        onTap: _showImageSourceDialog,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 104,
                          height: 104,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: colorScheme.primary.withValues(alpha: 0.45),
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: colorScheme.primary.withValues(
                              alpha: isDark ? 0.12 : 0.04,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo_outlined,
                                color: colorScheme.primary,
                                size: 28,
                              ),
                              const SizedBox(height: 6),
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
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
