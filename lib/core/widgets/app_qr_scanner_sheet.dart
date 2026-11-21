import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

/// Modal Bottom Sheet quét mã QR / Barcode chuẩn cho Vivona.
/// Hỗ trợ:
/// 1. Quét trực tiếp bằng Camera qua `mobile_scanner`.
/// 2. Điều khiển Flash (bật/tắt) và đổi Camera trước/sau.
/// 3. Tab "Nhập mã tay" để dự phòng khi camera lỗi, phòng tối, hoặc chạy trên máy bàn.
/// 4. Khung quét trực quan với viền nhận diện chuẩn Material 3.
class AppQrScannerSheet extends StatefulWidget {
  final String title;
  final String hintText;
  final String manualInputHint;
  final ValueChanged<String>? onScanned;

  const AppQrScannerSheet({
    super.key,
    this.title = 'Quét mã QR',
    this.hintText = 'Căn chỉnh mã QR vào trong khung hình vuông',
    this.manualInputHint = 'VD: VP-202611-00001',
    this.onScanned,
  });

  /// Hiển thị Scanner Modal Sheet và trả về mã quét được (hoặc null nếu đóng)
  static Future<String?> show(
    BuildContext context, {
    String title = 'Quét mã QR',
    String hintText = 'Căn chỉnh mã QR vào trong khung hình vuông',
    String manualInputHint = 'VD: VP-202611-00001',
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AppQrScannerSheet(
        title: title,
        hintText: hintText,
        manualInputHint: manualInputHint,
      ),
    );
  }

  @override
  State<AppQrScannerSheet> createState() => _AppQrScannerSheetState();
}

class _AppQrScannerSheetState extends State<AppQrScannerSheet> {
  late final MobileScannerController _controller;
  final TextEditingController _manualInputCtrl = TextEditingController();
  bool _isManualMode = false;
  bool _hasDetected = false;
  bool _isTorchOn = false;
  bool _isCameraError = false;
  String? _cameraErrorMessage;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _manualInputCtrl.dispose();
    super.dispose();
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_hasDetected) return;
    final barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final code = barcode.rawValue ?? barcode.displayValue;
      if (code != null && code.trim().isNotEmpty) {
        _hasDetected = true;
        _returnResult(code.trim());
        break;
      }
    }
  }

  void _returnResult(String code) {
    if (widget.onScanned != null) {
      widget.onScanned!(code);
    }
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context, code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final sheetHeight = mediaQuery.size.height * 0.78;

    return Container(
      height: sheetHeight,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.title,
                    style: context.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Nút chuyển chế độ Camera / Nhập tay
                IconButton(
                  tooltip: _isManualMode ? 'Bật Camera' : 'Nhập mã tay',
                  icon: Icon(
                    _isManualMode
                        ? Icons.camera_alt_outlined
                        : Icons.keyboard_alt_outlined,
                  ),
                  onPressed: () {
                    setState(() {
                      _isManualMode = !_isManualMode;
                    });
                  },
                ),
                IconButton(
                  tooltip: 'Đóng',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Body: Camera hoặc Manual Input
          Expanded(
            child: _isManualMode || _isCameraError
                ? _buildManualInputView(context)
                : _buildCameraScannerView(context),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraScannerView(BuildContext context) {
    final isDesktop = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS);

    if (isDesktop) {
      return _buildManualInputView(
        context,
        notice: 'Thiết bị máy bàn: Vui lòng nhập mã hoặc dùng đầu đọc mã vạch quét trực tiếp vào ô bên dưới.',
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        // Camera View
        MobileScanner(
          controller: _controller,
          onDetect: _handleBarcode,
          errorBuilder: (context, error) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_isCameraError) {
                setState(() {
                  _isCameraError = true;
                  _cameraErrorMessage = error.errorDetails?.message ??
                      'Không thể kết nối camera trên thiết bị này.';
                });
              }
            });
            return const SizedBox.shrink();
          },
        ),

        // Khung ngắm quét QR (Viewfinder Overlay)
        Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.primary,
              width: 3,
            ),
          ),
        ),

        // Hint text ở trên
        Positioned(
          top: 20,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.hintText,
              textAlign: TextAlign.center,
              style: context.bodySmall?.copyWith(color: Colors.white),
            ),
          ),
        ),

        // Controls bar (Flash & Flip camera) ở dưới
        Positioned(
          bottom: 24,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Nút Flash
              FloatingActionButton.small(
                heroTag: 'scanner_torch',
                backgroundColor: _isTorchOn
                    ? Colors.amber
                    : Colors.black.withValues(alpha: 0.6),
                foregroundColor: Colors.white,
                onPressed: () async {
                  await _controller.toggleTorch();
                  setState(() {
                    _isTorchOn = !_isTorchOn;
                  });
                },
                child: Icon(
                  _isTorchOn ? Icons.flash_on : Icons.flash_off,
                  size: 20,
                ),
              ),
              const SizedBox(width: 20),
              // Nút Đổi Camera
              FloatingActionButton.small(
                heroTag: 'scanner_switch',
                backgroundColor: Colors.black.withValues(alpha: 0.6),
                foregroundColor: Colors.white,
                onPressed: () async {
                  await _controller.switchCamera();
                },
                child: const Icon(Icons.cameraswitch_outlined, size: 20),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildManualInputView(BuildContext context, {String? notice}) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (notice != null || _cameraErrorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      notice ?? _cameraErrorMessage!,
                      style: context.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          Text(
            'Nhập mã vé / mã xác thực thủ công:',
            style: context.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _manualInputCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: widget.manualInputHint,
              prefixIcon: const Icon(Icons.confirmation_number_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onSubmitted: (val) {
              if (val.trim().isNotEmpty) {
                _returnResult(val.trim());
              }
            },
          ),
          const Spacer(),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.check_circle_outline, size: 20),
              label: const Text('Xác nhận mã', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                final text = _manualInputCtrl.text.trim();
                if (text.isNotEmpty) {
                  _returnResult(text);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

