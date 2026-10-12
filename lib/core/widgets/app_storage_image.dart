import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _CachedUrl {
  final String url;
  final DateTime expiresAt;
  _CachedUrl(this.url, this.expiresAt);
  bool get isValid => DateTime.now().isBefore(expiresAt);
}

/// Widget hiển thị ảnh từ Supabase Storage thông minh:
/// - Tự động nhận diện Object Path (vd: staffId/issueId/proof.jpg) hoặc URL công khai
/// - Tự động sinh và làm mới Signed URL đối với private bucket
/// - Có bộ nhớ đệm (cache) giúp tối ưu hiệu năng không gọi thừa API tạo Signed URL
class AppStorageImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  const AppStorageImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  static final Map<String, _CachedUrl> _cache = {};

  /// Chuyển đổi một chuỗi image_url (có thể là object path hoặc URL) thành Signed URL dùng được
  static Future<String> resolveSignedUrl(String urlOrPath, {int expiresInSeconds = 3600}) async {
    final trimmed = urlOrPath.trim();
    if (trimmed.isEmpty) return '';

    // Nếu là URL bên ngoài (không thuộc issue-images, ví dụ ảnh placeholder)
    if ((trimmed.startsWith('http://') || trimmed.startsWith('https://')) &&
        !trimmed.contains('issue-images')) {
      return trimmed;
    }

    // Trích xuất object path
    String objectPath = trimmed;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      try {
        final uri = Uri.parse(trimmed);
        final segments = uri.pathSegments;
        final bucketIndex = segments.indexOf('issue-images');
        if (bucketIndex != -1 && bucketIndex + 1 < segments.length) {
          objectPath = segments.sublist(bucketIndex + 1).join('/');
        }
      } catch (_) {
        return trimmed;
      }
    }

    // Kiểm tra cache
    final cached = _cache[objectPath];
    if (cached != null && cached.isValid) {
      return cached.url;
    }

    try {
      final signedUrl = await Supabase.instance.client.storage
          .from('issue-images')
          .createSignedUrl(objectPath, expiresInSeconds);
      _cache[objectPath] = _CachedUrl(
        signedUrl,
        DateTime.now().add(Duration(seconds: expiresInSeconds - 60)),
      );
      return signedUrl;
    } catch (_) {
      // Fallback: nếu không tạo được signed URL, trả về chuỗi gốc
      return trimmed;
    }
  }

  /// Resolve danh sách URL phục vụ phóng to ảnh (PhotoViewerScreen)
  static Future<List<String>> resolveSignedUrlList(List<String> list) async {
    return Future.wait(list.map((item) => resolveSignedUrl(item)));
  }

  @override
  State<AppStorageImage> createState() => _AppStorageImageState();
}

class _AppStorageImageState extends State<AppStorageImage> {
  String? _resolvedUrl;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  @override
  void didUpdateWidget(covariant AppStorageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadUrl();
    }
  }

  Future<void> _loadUrl() async {
    if (widget.imageUrl.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
      return;
    }

    try {
      final url = await AppStorageImage.resolveSignedUrl(widget.imageUrl);
      if (mounted) {
        setState(() {
          _resolvedUrl = url;
          _isLoading = false;
          _hasError = url.isEmpty;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (_isLoading) {
      content = widget.placeholder ??
          Container(
            width: widget.width,
            height: widget.height,
            color: Colors.grey.shade200,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
    } else if (_hasError || _resolvedUrl == null || _resolvedUrl!.isEmpty) {
      content = widget.errorWidget ??
          Container(
            width: widget.width,
            height: widget.height,
            color: Colors.grey.shade200,
            child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
          );
    } else {
      content = Image.network(
        _resolvedUrl!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) =>
            widget.errorWidget ??
            Container(
              width: widget.width,
              height: widget.height,
              color: Colors.grey.shade200,
              child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
            ),
      );
    }

    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius!,
        child: content,
      );
    }

    return content;
  }
}
