import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/supabase_config.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_storage_image.dart';
import '../../../data/models/issue_model.dart';
import '../../../data/providers/resident_issue_provider.dart';
import '../../../data/repositories/issue_repository.dart';

/// Màn hình chỉnh sửa phản ánh sự cố cư dân.
/// Hỗ trợ chuẩn B2B SaaS Impeccable Taste:
/// - Desktop (>= 900dp): Giới hạn độ rộng biểu mẫu maxWidth: 720dp, căn giữa thanh lịch.
/// - Mobile (< 900dp): Thẻ AppCard viền mỏng mờ, chống tràn 100% trên 320dp (Text Zoom 1.3x).
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
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
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.add_photo_alternate_outlined,
                      color: AppTheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Chọn nguồn hình ảnh',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_outlined,
                  color: AppTheme.primary,
                ),
                title: const Text(
                  'Chụp ảnh mới',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Sử dụng máy ảnh thiết bị để chụp hiện trường'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: AppTheme.primary,
                ),
                title: const Text(
                  'Chọn từ thư viện ảnh',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Tải ảnh đã lưu từ bộ sưu tập của bạn'),
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

  Future<void> _submitUpdate() async {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập mô tả sự cố'),
          backgroundColor: AppTheme.warning,
        ),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cập nhật phản ánh thành công!'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(formatErrorMessage(e)),
            backgroundColor: AppTheme.error,
          ),
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
        title: const Text('Chỉnh sửa phản ánh'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
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
                          const Icon(
                            Icons.description_outlined,
                            size: 20,
                            color: AppTheme.primary,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Mô tả sự cố',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Cung cấp thông tin chi tiết giúp đội ngũ kỹ thuật xử lý nhanh chóng.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _descriptionController,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: 'Nhập chi tiết về sự cố bạn đang gặp phải...',
                          filled: true,
                          fillColor: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white10
                              : Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppTheme.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
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
                          const Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.photo_library_outlined,
                                  size: 20,
                                  color: AppTheme.primary,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Hình ảnh đính kèm',
                                    style: TextStyle(
                                      fontSize: 16,
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
                              color: _totalImageCount >= 3
                                  ? AppTheme.warning.withValues(alpha: 0.1)
                                  : AppTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$_totalImageCount/3 ảnh',
                              style: TextStyle(
                                fontSize: 12,
                                color: _totalImageCount >= 3
                                    ? Colors.orange.shade800
                                    : AppTheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Hình ảnh chụp trực tiếp tại hiện trường giúp thẩm định chính xác sự cố.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
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
                              children: [
                                AppStorageImage(
                                  imageUrl: imageUrl,
                                  width: 104,
                                  height: 104,
                                  fit: BoxFit.cover,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _existingImages.remove(imageUrl);
                                        _removedImageUrls.add(imageUrl);
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.65),
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
                                  top: 6,
                                  right: 6,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _newImageFiles.remove(file);
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.65),
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
                                    color: AppTheme.primary.withValues(alpha: 0.4),
                                    style: BorderStyle.solid,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  color: AppTheme.primary.withValues(alpha: 0.04),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_a_photo_outlined,
                                      color: AppTheme.primary,
                                      size: 28,
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      'Thêm ảnh',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.primary,
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

                const SizedBox(height: 32),
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _submitUpdate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _isLoading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check, size: 20),
                    label: const Text(
                      'Lưu thay đổi',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
