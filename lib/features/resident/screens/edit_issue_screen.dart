import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/supabase_config.dart';
import '../../../data/models/issue_model.dart';
import '../../../data/providers/resident_issue_provider.dart';
import '../../../data/repositories/issue_repository.dart';

class EditIssueScreen extends ConsumerStatefulWidget {
  final IssueModel issue;

  const EditIssueScreen({
    super.key,
    required this.issue,
  });

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
    _descriptionController = TextEditingController(text: widget.issue.description);
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
      final XFile? image = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
      if (image != null) {
        setState(() {
          _newImageFiles.add(File(image.path));
        });
      }
    } else {
      if (remaining == 1) {
        final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
        if (image != null) {
          setState(() {
            _newImageFiles.add(File(image.path));
          });
        }
      } else {
        final List<XFile> images = await _picker.pickMultiImage(limit: remaining, imageQuality: 80);
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

  Future<void> _submitUpdate() async {
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

      final issueRepo = ref.read(issueRepositoryProvider);
      await issueRepo.updateIssue(
        issueId: widget.issue.id,
        reporterId: user.id,
        description: description,
        removedImageUrls: _removedImageUrls.isNotEmpty ? _removedImageUrls : null,
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
        title: const Text('Chỉnh sửa phản ánh'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Mô tả sự cố',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Nhập chi tiết về sự cố bạn đang gặp phải...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Hình ảnh đính kèm',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '$_totalImageCount/3 ảnh',
                  style: TextStyle(
                    fontSize: 13,
                    color: _totalImageCount >= 3 ? AppTheme.warning : AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Grid hiển thị ảnh hiện có + ảnh mới + nút thêm
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                // 1. Ảnh hiện có từ Server
                ..._existingImages.map((imageUrl) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imageUrl,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 100,
                            height: 100,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _existingImages.remove(imageUrl);
                              _removedImageUrls.add(imageUrl);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 14, color: Colors.white),
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
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          file,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _newImageFiles.remove(file);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 14, color: Colors.white),
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
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.primary, style: BorderStyle.solid),
                        borderRadius: BorderRadius.circular(8),
                        color: AppTheme.primary.withValues(alpha: 0.05),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined, color: AppTheme.primary, size: 28),
                          SizedBox(height: 4),
                          Text(
                            'Thêm ảnh',
                            style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitUpdate,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Lưu thay đổi', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
