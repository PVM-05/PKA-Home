import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';

import '../../../core/widgets/app_card.dart';

import '../../../core/widgets/app_error_card.dart';

import 'package:image_picker/image_picker.dart';

import '../../../core/utils/utility_anomaly_detector.dart';

import '../../../data/providers/meter_reading_provider.dart';

import '../../../data/providers/auth_provider.dart';

import '../../../data/providers/vehicle_provider.dart';

import '../../../core/utils/network_error_handler.dart';

import '../../../core/utils/validators.dart';

import '../../../data/models/meter_reading_submission_model.dart';
import '../../../data/services/meter_ocr_service.dart';

class ResidentMeterReadingScreen extends ConsumerStatefulWidget {
  const ResidentMeterReadingScreen({super.key});

  @override
  ConsumerState<ResidentMeterReadingScreen> createState() =>
      _ResidentMeterReadingScreenState();
}

class _ResidentMeterReadingScreenState
    extends ConsumerState<ResidentMeterReadingScreen> {
  final _formKey = GlobalKey<FormState>();

  final _electricController = TextEditingController();

  final _waterController = TextEditingController();

  late final TextEditingController _periodController;

  bool _isSubmitting = false;

  String? _electricImagePath;
  String? _waterImagePath;
  bool _isElectricOcrScanning = false;
  bool _isWaterOcrScanning = false;

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _periodController = TextEditingController(
      text: '${now.month.toString().padLeft(2, '0')}/${now.year}',
    );
    _electricController.addListener(_onFieldChanged);
    _waterController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _electricController.removeListener(_onFieldChanged);
    _waterController.removeListener(_onFieldChanged);
    _electricController.dispose();
    _waterController.dispose();
    _periodController.dispose();
    super.dispose();
  }

  Future<void> _pickMeterImage(MeterType type, ImageSource source) async {
    try {
      final picker = ImagePicker();

      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (image == null) return;

      setState(() {
        if (type == MeterType.electric) {
          _electricImagePath = image.path;
          _isElectricOcrScanning = true;
        } else {
          _waterImagePath = image.path;
          _isWaterOcrScanning = true;
        }
      });

      // Tự động quét và nhận diện chỉ số bằng Real OCR Service
      final ocrService = ref.read(meterOcrServiceProvider);
      final ocrResult = await ocrService.recognizeMeterReading(
        imagePath: image.path,
        meterType: type,
      );

      if (mounted) {
        setState(() {
          if (type == MeterType.electric) {
            _isElectricOcrScanning = false;
            if (ocrResult.isValid) {
              final valStr = ocrResult.detectedReading ==
                      ocrResult.detectedReading.roundToDouble()
                  ? ocrResult.detectedReading.toInt().toString()
                  : ocrResult.detectedReading.toString();
              _electricController.text = valStr;
            }
          } else {
            _isWaterOcrScanning = false;
            if (ocrResult.isValid) {
              final valStr = ocrResult.detectedReading ==
                      ocrResult.detectedReading.roundToDouble()
                  ? ocrResult.detectedReading.toInt().toString()
                  : ocrResult.detectedReading.toString();
              _waterController.text = valStr;
            }
          }
        });

        if (ocrResult.isValid) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'OCR nhận diện thành công: ${ocrResult.detectedReading} ${ocrResult.unit} (Độ tin cậy: ${(ocrResult.confidence * 100).toInt()}%). Đã tự động điền vào ô chỉ số.',
              ),
              backgroundColor: AppTheme.primary,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Đã đính kèm ảnh công tơ ${type == MeterType.electric ? "điện" : "nước"}. ${ocrResult.errorMessage} Vui lòng tự nhập số hiển thị trên đồng hồ.',
              ),
              backgroundColor: AppTheme.warning,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isElectricOcrScanning = false;
          _isWaterOcrScanning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể chụp/chọn ảnh: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Widget _buildAnomalyBanner(AnomalyAnalysisResult analysis) {
    if (!analysis.isAnomaly) return const SizedBox.shrink();

    Color borderColor;

    Color bgColor;

    Color textColor;

    IconData icon;

    switch (analysis.severity) {
      case AnomalySeverity.danger:
        borderColor = AppTheme.error;

        bgColor = AppTheme.error.withValues(alpha: 0.08);

        textColor = AppTheme.error;

        icon = Icons.error_outline;

        break;

      case AnomalySeverity.warning:
        borderColor = Colors.orange;

        bgColor = Colors.orange.withValues(alpha: 0.08);

        textColor = Colors.orange.shade900;

        icon = Icons.warning_amber_rounded;

        break;

      case AnomalySeverity.info:
      case AnomalySeverity.normal:
        borderColor = Colors.blue;

        bgColor = Colors.blue.withValues(alpha: 0.08);

        textColor = Colors.blue.shade900;

        icon = Icons.info_outline;

        break;
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),

      padding: const EdgeInsets.all(10),

      decoration: BoxDecoration(
        color: bgColor,

        borderRadius: BorderRadius.circular(8),

        border: Border.all(color: borderColor),
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Icon(icon, color: borderColor, size: 18),

          const SizedBox(width: 8),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  'Cảnh báo: ${analysis.severityDisplayName}',

                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),

                if (analysis.reason != null) ...[
                  const SizedBox(height: 2),

                  Text(
                    analysis.reason!,

                    style: TextStyle(fontSize: 12, color: textColor),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _calculateDynamicAverageUsage(
    List<MeterReadingSubmissionModel> history,
    MeterType type,
  ) {
    final valid = history.where((r) => !r.isRejected).toList();
    if (valid.isEmpty) {
      return type == MeterType.electric ? 130.0 : 12.0;
    }
    final recent = valid.take(6).toList();
    final usages = <double>[];
    for (final r in recent) {
      final val = type == MeterType.electric ? r.electricConsumed : r.waterConsumed;
      if (val != null && val > 0) {
        usages.add(val);
      }
    }
    if (usages.isEmpty) {
      return type == MeterType.electric ? 130.0 : 12.0;
    }
    return usages.reduce((a, b) => a + b) / usages.length;
  }

  Future<void> _submit(double oldElec, double oldWater) async {
    if (_isSubmitting) return;

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final elecVal = double.tryParse(_electricController.text.trim()) ?? 0.0;
    final waterVal = double.tryParse(_waterController.text.trim()) ?? 0.0;

    final existingReadings =
        ref.read(residentMeterReadingsProvider).valueOrNull ?? [];
    final avgElec = _calculateDynamicAverageUsage(existingReadings, MeterType.electric);
    final avgWater = _calculateDynamicAverageUsage(existingReadings, MeterType.water);

    // Phân tích bất thường dựa trên mức trung bình động của căn hộ (P0-#17)
    final elecAnalysis = UtilityAnomalyDetector.analyzeReading(
      currentReading: elecVal,
      previousReading: oldElec,
      averageUsage: avgElec,
      meterType: MeterType.electric,
    );

    final waterAnalysis = UtilityAnomalyDetector.analyzeReading(
      currentReading: waterVal,
      previousReading: oldWater,
      averageUsage: avgWater,
      meterType: MeterType.water,
    );

    if (elecVal < oldElec) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Chỉ số điện mới ($elecVal) không được nhỏ hơn chỉ số cũ ($oldElec kWh).',
          ),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    if (waterVal < oldWater) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Chỉ số nước mới ($waterVal) không được nhỏ hơn chỉ số cũ ($oldWater m³).',
          ),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    // P0-#17: Bắt buộc đính kèm ảnh công tơ thật khi chỉ số ở mức danger
    if (elecAnalysis.severity == AnomalySeverity.danger && _electricImagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Mức tiêu thụ điện tăng vọt ở mức NGUY HIỂM (>300% trung bình). Bạn bắt buộc phải chụp ảnh mặt công tơ thật để gửi BQL đối soát.',
          ),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    if (waterAnalysis.severity == AnomalySeverity.danger && _waterImagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Mức tiêu thụ nước tăng vọt ở mức NGUY HIỂM (>300% trung bình). Bạn bắt buộc phải chụp ảnh mặt đồng hồ nước thật để gửi BQL đối soát.',
          ),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    // Nếu phát hiện tiêu thụ tăng cao bất thường (warning hoặc danger), hiển thị dialog xác nhận
    final bool isDanger = elecAnalysis.severity == AnomalySeverity.danger ||
        waterAnalysis.severity == AnomalySeverity.danger;

    final bool hasSevereAnomaly = (elecAnalysis.isAnomaly &&
            (elecAnalysis.severity == AnomalySeverity.warning ||
                elecAnalysis.severity == AnomalySeverity.danger)) ||
        (waterAnalysis.isAnomaly &&
            (waterAnalysis.severity == AnomalySeverity.warning ||
                waterAnalysis.severity == AnomalySeverity.danger));

    String? residentExplanation;

    if (hasSevereAnomaly) {
      final reasons = <String>[];
      if (elecAnalysis.isAnomaly &&
          (elecAnalysis.severity == AnomalySeverity.warning ||
              elecAnalysis.severity == AnomalySeverity.danger) &&
          elecAnalysis.reason != null) {
        reasons.add(elecAnalysis.reason!);
      }
      if (waterAnalysis.isAnomaly &&
          (waterAnalysis.severity == AnomalySeverity.warning ||
              waterAnalysis.severity == AnomalySeverity.danger) &&
          waterAnalysis.reason != null) {
        reasons.add(waterAnalysis.reason!);
      }

      final explanationController = TextEditingController();

      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                isDanger ? Icons.error_outline : Icons.warning_amber_rounded,
                color: isDanger ? AppTheme.error : Colors.orange,
                size: 28,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isDanger
                      ? 'Cảnh Báo Tiêu Thụ Tăng Vọt Nguy Hiểm'
                      : 'Cảnh Báo Tiêu Thụ Bất Thường',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDanger
                      ? 'Hệ thống AI phát hiện mức tiêu thụ tăng vọt bất thường (>300% so với trung bình các kỳ trước):'
                      : 'Hệ thống AI/OCR phát hiện mức tiêu thụ kỳ này có dấu hiệu tăng cao bất thường so với tháng trước:',
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 10),
                ...reasons.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '• $r',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDanger ? AppTheme.error : null,
                      ),
                    ),
                  ),
                ),
                if (isDanger) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: explanationController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Giải trình lý do tăng cao (Bắt buộc) *',
                      hintText: 'VD: Lắp thêm thiết bị, gia đình có khách đông, sửa chữa...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Bạn đã kiểm tra đối chiếu kỹ chữ số trên mặt công tơ thực tế chưa?',
                    style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Kiểm tra lại công tơ'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDanger ? AppTheme.error : AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (isDanger && explanationController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Vui lòng nhập giải trình lý do tiêu thụ tăng cao đột biến.'),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                  return;
                }
                residentExplanation = explanationController.text.trim();
                Navigator.pop(ctx, true);
              },
              child: const Text('Tôi đã kiểm tra & Tiếp tục gửi'),
            ),
          ],
        ),
      );

      if (proceed != true) {
        return;
      }
    }

    final period = _periodController.text.trim();
    final alreadySubmitted = existingReadings.any(
      (r) => r.period == period && !r.isRejected,
    );

    if (alreadySubmitted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Kỳ $period đã được gửi khai báo trước đó. Vui lòng chờ Ban Quản Lý xử lý.',
          ),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    final user = ref.read(authProvider).valueOrNull;
    final aptId = await ref.read(residentApartmentIdProvider.future);
    if (!mounted) return;

    if (user == null || aptId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không tìm thấy thông tin căn hộ liên kết của bạn.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    if (_electricImagePath == null && _waterImagePath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Lưu ý: Bạn gửi chỉ số nhập tay mà không đính kèm ảnh công tơ thật. Ban Quản Lý có thể yêu cầu đối soát trực tiếp.',
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(meterReadingRepositoryProvider);

      // P0-#16: Upload ảnh công tơ lên Storage thật trước khi lưu URL
      String? uploadedElectricUrl = _electricImagePath;
      if (_electricImagePath != null) {
        uploadedElectricUrl = await repo.uploadMeterImage(
          _electricImagePath!,
          apartmentId: aptId,
          meterType: 'electric',
        );
      }

      String? uploadedWaterUrl = _waterImagePath;
      if (_waterImagePath != null) {
        uploadedWaterUrl = await repo.uploadMeterImage(
          _waterImagePath!,
          apartmentId: aptId,
          meterType: 'water',
        );
      }

      final double confidence =
          (_electricImagePath != null || _waterImagePath != null) ? 1.0 : 0.85;

      final bool isAnomaly = elecAnalysis.isAnomaly || waterAnalysis.isAnomaly;
      final String severity = isDanger
          ? 'danger'
          : ((elecAnalysis.severity == AnomalySeverity.warning ||
                  waterAnalysis.severity == AnomalySeverity.warning)
              ? 'warning'
              : 'normal');

      final anomalyReason = residentExplanation != null && residentExplanation!.isNotEmpty
          ? residentExplanation
          : (elecAnalysis.reason ?? waterAnalysis.reason);

      await repo.submitReading(
        apartmentId: aptId,
        userId: user.id,
        period: _periodController.text.trim(),
        electricReading: elecVal,
        waterReading: waterVal,
        electricImageUrl: uploadedElectricUrl,
        waterImageUrl: uploadedWaterUrl,
        ocrConfidence: confidence,
        isAnomaly: isAnomaly,
        anomalySeverity: severity,
        anomalyReason: anomalyReason,
      );

      ref.invalidate(residentMeterReadingsProvider);

      if (mounted) {
        setState(() {
          _isSubmitting = false;

          _electricController.clear();

          _waterController.clear();

          _electricImagePath = null;

          _waterImagePath = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Đã gửi chỉ số điện nước thành công! Ban Quản Lý sẽ sớm kiểm tra và xác nhận.',
            ),

            backgroundColor: AppStatusColors.paid,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(NetworkErrorHandler.getMessage(e)),

            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final aptReadingsAsync = ref.watch(currentApartmentReadingsProvider);

    final historyAsync = ref.watch(residentMeterReadingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Khai Báo Chỉ Số Điện Nước')),

      body: aptReadingsAsync.when(
        data: (aptData) {
          if (aptData == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),

                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,

                  children: [
                    const Icon(
                      Icons.apartment_outlined,
                      size: 64,
                      color: AppTheme.textSecondary,
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'Chưa có dữ liệu căn hộ liên kết.',

                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'Vui lòng liên kết căn hộ tại trang chủ trước khi gửi chỉ số.',

                      style: TextStyle(color: AppTheme.textSecondary),

                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 20),

                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),

                      child: const Text('Quay lại trang chủ'),
                    ),
                  ],
                ),
              ),
            );
          }

          final aptCode = aptData['code'] as String? ?? '';

          final oldElec =
              (aptData['electric_reading'] as num?)?.toDouble() ?? 0.0;

          final oldWater =
              (aptData['water_reading'] as num?)?.toDouble() ?? 0.0;

          // Phân tích bất thường thời gian thực khi người dùng gõ hoặc quét

          final currentElecInput = double.tryParse(
            _electricController.text.trim(),
          );

          final currentWaterInput = double.tryParse(
            _waterController.text.trim(),
          );

          final historyList = historyAsync.valueOrNull ?? [];
          final avgElec = _calculateDynamicAverageUsage(historyList, MeterType.electric);
          final avgWater = _calculateDynamicAverageUsage(historyList, MeterType.water);

          final elecAnalysis = currentElecInput != null
              ? UtilityAnomalyDetector.analyzeReading(
                  currentReading: currentElecInput,
                  previousReading: oldElec,
                  averageUsage: avgElec,
                  meterType: MeterType.electric,
                )
              : null;

          final waterAnalysis = currentWaterInput != null
              ? UtilityAnomalyDetector.analyzeReading(
                  currentReading: currentWaterInput,
                  previousReading: oldWater,
                  averageUsage: avgWater,
                  meterType: MeterType.water,
                )
              : null;

          final isDesktop = MediaQuery.of(context).size.width >= 900;
          final warningWidget = DateTime.now().day > 25 ? _buildOverdueWarning() : null;
          final previousCard = _buildPreviousReadingsCard(aptCode, oldElec, oldWater);
          final electricCard = _buildElectricCard(elecAnalysis, oldElec);
          final waterCard = _buildWaterCard(waterAnalysis, oldWater);
          final periodField = _buildPeriodField();
          final submitButton = _buildSubmitButton(oldElec, oldWater);
          final historySection = _buildHistorySection(historyAsync);

          Widget content;
          if (isDesktop) {
            content = Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cột trái: Đối chiếu chỉ số cũ & Lịch sử khai báo
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ?warningWidget,
                            previousCard,
                            const SizedBox(height: 24),
                            historySection,
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Cột phải: Form khai báo chỉ số
                      Expanded(
                        flex: 7,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            electricCard,
                            const SizedBox(height: 16),
                            waterCard,
                            const SizedBox(height: 16),
                            periodField,
                            const SizedBox(height: 20),
                            submitButton,
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          } else {
            content = Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ?warningWidget,
                  previousCard,
                  const SizedBox(height: 16),
                  electricCard,
                  const SizedBox(height: 16),
                  waterCard,
                  const SizedBox(height: 16),
                  periodField,
                  const SizedBox(height: 20),
                  submitButton,
                  const SizedBox(height: 28),
                  historySection,
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(currentApartmentReadingsProvider);
              ref.invalidate(residentMeterReadingsProvider);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Form(
                key: _formKey,
                child: content,
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: AppErrorCard(error: e)),
      ),
    );
  }

  Widget _buildOverdueWarning() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade400),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.amber.shade800,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lưu ý: Đã quá hạn chốt số tháng này (Hạn chót: ngày 25)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.amber.shade900,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Vui lòng gửi chỉ số sớm nhất có thể để tránh bị tạm tính chỉ số theo mức trung bình của căn hộ.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviousReadingsCard(
    String aptCode,
    double oldElec,
    double oldWater,
  ) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.history_toggle_off,
                color: AppTheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Chỉ số kỳ trước • Căn hộ $aptCode',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.amber.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.bolt,
                            color: Colors.amber.shade800,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          const Expanded(
                            child: Text(
                              'Điện cũ',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '$oldElec kWh',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.blue.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.water_drop,
                            color: Colors.blue.shade800,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          const Expanded(
                            child: Text(
                              'Nước cũ',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '$oldWater m³',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
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
    );
  }

  Widget _buildElectricCard(AnomalyAnalysisResult? elecAnalysis, double oldElec) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt, color: Colors.amber),
                  SizedBox(width: 6),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Công tơ Điện (kWh)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.filledTonal(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Chụp ảnh công tơ điện',
                    icon: const Icon(
                      Icons.camera_alt_outlined,
                      size: 18,
                    ),
                    onPressed: () => _pickMeterImage(
                      MeterType.electric,
                      ImageSource.camera,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton.outlined(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Chọn ảnh từ thư viện',
                    icon: const Icon(
                      Icons.photo_library_outlined,
                      size: 18,
                    ),
                    onPressed: () => _pickMeterImage(
                      MeterType.electric,
                      ImageSource.gallery,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_electricImagePath != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppTheme.success.withValues(
                    alpha: 0.3,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 16,
                    color: AppTheme.success,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Đã đính kèm ảnh công tơ điện: ${_electricImagePath!.split(r'/').last.split(r'\\').last}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.success,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                    onPressed: () => setState(
                      () => _electricImagePath = null,
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ],
          if (_isElectricOcrScanning) ...[
            const SizedBox(height: 8),
            const Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text(
                  'Đang xử lý OCR bóc tách chỉ số từ ảnh công tơ...',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.primary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: _electricController,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            decoration: const InputDecoration(
              labelText: 'Chỉ số điện mới *',
              suffixText: 'kWh',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.electric_meter_outlined),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Vui lòng nhập chỉ số điện';
              }
              if (double.tryParse(val.trim()) == null) {
                return 'Chỉ số phải là số hợp lệ';
              }
              return null;
            },
          ),
          if (elecAnalysis != null)
            _buildAnomalyBanner(elecAnalysis),
        ],
      ),
    );
  }

  Widget _buildWaterCard(AnomalyAnalysisResult? waterAnalysis, double oldWater) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.water_drop, color: Colors.blue),
                  SizedBox(width: 6),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Công tơ Nước (m³)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.filledTonal(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Chụp ảnh công tơ nước',
                    icon: const Icon(
                      Icons.camera_alt_outlined,
                      size: 18,
                    ),
                    onPressed: () => _pickMeterImage(
                      MeterType.water,
                      ImageSource.camera,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton.outlined(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Chọn ảnh từ thư viện',
                    icon: const Icon(
                      Icons.photo_library_outlined,
                      size: 18,
                    ),
                    onPressed: () => _pickMeterImage(
                      MeterType.water,
                      ImageSource.gallery,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_waterImagePath != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppTheme.success.withValues(
                    alpha: 0.3,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 16,
                    color: AppTheme.success,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Đã đính kèm ảnh công tơ nước: ${_waterImagePath!.split(r'/').last.split(r'\\').last}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.success,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                    onPressed: () =>
                        setState(() => _waterImagePath = null),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ],
          if (_isWaterOcrScanning) ...[
            const SizedBox(height: 8),
            const Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text(
                  'Đang xử lý OCR bóc tách chỉ số từ ảnh công tơ...',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.primary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: _waterController,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            decoration: const InputDecoration(
              labelText: 'Chỉ số nước mới *',
              suffixText: 'm³',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.water_damage_outlined),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Vui lòng nhập chỉ số nước';
              }
              if (double.tryParse(val.trim()) == null) {
                return 'Chỉ số phải là số hợp lệ';
              }
              return null;
            },
          ),
          if (waterAnalysis != null)
            _buildAnomalyBanner(waterAnalysis),
        ],
      ),
    );
  }

  Widget _buildPeriodField() {
    return TextFormField(
      controller: _periodController,
      decoration: const InputDecoration(
        labelText: 'Kỳ khai báo (MM/yyyy) *',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.calendar_month_outlined),
      ),
      validator: validateInvoicePeriod,
    );
  }

  Widget _buildSubmitButton(double oldElec, double oldWater) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send_outlined),
          label: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _isSubmitting
                  ? 'Đang gửi...'
                  : 'Gửi chỉ số cho Ban Quản Lý',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          onPressed: _isSubmitting
              ? null
              : () => _submit(oldElec, oldWater),
        ),
      ),
    );
  }

  Widget _buildHistorySection(
    AsyncValue<List<MeterReadingSubmissionModel>> historyAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Lịch Sử Khai Báo Chỉ Số',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        historyAsync.when(
          data: (history) {
            if (history.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Chưa có lịch sử khai báo chỉ số nào.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final item = history[index];
                Color statusColor = AppTheme.warning;
                if (item.isApproved) {
                  statusColor = AppStatusColors.paid;
                }
                if (item.isRejected) statusColor = AppTheme.error;
                if (item.isCancelled) statusColor = Colors.grey;

                return AppCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              'Kỳ: ${item.period}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 100),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(
                                  8,
                                ),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  item.statusDisplayName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Điện: ${item.electricReading} kWh',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Nước: ${item.waterReading} m³',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Gửi lúc: ${_dateFormat.format(item.createdAt)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      if (item.hasAnomaly &&
                          item.anomalyReason != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: item.isDangerAnomaly
                                ? AppTheme.error.withValues(
                                    alpha: 0.08,
                                  )
                                : Colors.orange.withValues(
                                    alpha: 0.08,
                                  ),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: item.isDangerAnomaly
                                  ? AppTheme.error
                                  : Colors.orange,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                item.isDangerAnomaly
                                    ? Icons.error_outline
                                    : Icons.warning_amber_rounded,
                                size: 16,
                                color: item.isDangerAnomaly
                                    ? AppTheme.error
                                    : Colors.orange.shade800,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Lưu ý BQL: ${item.anomalyReason}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: item.isDangerAnomaly
                                        ? AppTheme.error
                                        : Colors.orange.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (item.isRejected &&
                          item.rejectReason != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withValues(
                              alpha: 0.08,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                size: 16,
                                color: AppTheme.error,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Lý do từ chối: ${item.rejectReason}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (item.isPending) ...[
                        const SizedBox(height: 10),
                        const Divider(height: 1),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primary,
                                visualDensity:
                                    VisualDensity.compact,
                              ),
                              icon: const Icon(
                                Icons.edit_outlined,
                                size: 16,
                              ),
                              label: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Sửa chỉ số'),
                              ),
                              onPressed: () =>
                                  _showEditSubmissionDialog(
                                    context,
                                    item,
                                  ),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.error,
                                visualDensity:
                                    VisualDensity.compact,
                              ),
                              icon: const Icon(
                                Icons.cancel_outlined,
                                size: 16,
                              ),
                              label: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Hủy phiếu'),
                              ),
                              onPressed: () =>
                                  _confirmCancelSubmission(
                                    context,
                                    item,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => AppErrorCard(error: e),
        ),
      ],
    );
  }

  void _showEditSubmissionDialog(
    BuildContext context,
    MeterReadingSubmissionModel item,
  ) {
    final elecController = TextEditingController(
      text: item.electricReading.toString(),
    );

    final waterController = TextEditingController(
      text: item.waterReading.toString(),
    );

    final formKey = GlobalKey<FormState>();

    bool clearElectricImg = false;

    bool clearWaterImg = false;

    bool isSaving = false;

    showDialog(
      context: context,

      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),

          title: Row(
            children: [
              const Icon(Icons.edit_note, color: AppTheme.primary),

              const SizedBox(width: 8),

              Expanded(child: Text('Sửa Chỉ Số Kỳ ${item.period}')),
            ],
          ),

          content: SingleChildScrollView(
            child: Form(
              key: formKey,

              child: Column(
                mainAxisSize: MainAxisSize.min,

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  const Text(
                    'Bạn có thể điều chỉnh lại chỉ số điện nước khi phiếu đang chờ Ban Quản Lý phê duyệt.',

                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: elecController,

                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),

                    decoration: const InputDecoration(
                      labelText: 'Chỉ số điện (kWh) *',

                      border: OutlineInputBorder(),

                      prefixIcon: Icon(Icons.bolt, color: Colors.orange),
                    ),

                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Vui lòng nhập chỉ số điện';
                      }

                      final num = double.tryParse(val.trim());

                      if (num == null || num < 0) {
                        return 'Chỉ số điện phải là số không âm';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 12),

                  TextFormField(
                    controller: waterController,

                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),

                    decoration: const InputDecoration(
                      labelText: 'Chỉ số nước (m³) *',

                      border: OutlineInputBorder(),

                      prefixIcon: Icon(Icons.water_drop, color: Colors.blue),
                    ),

                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Vui lòng nhập chỉ số nước';
                      }

                      final num = double.tryParse(val.trim());

                      if (num == null || num < 0) {
                        return 'Chỉ số nước phải là số không âm';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 12),

                  if (item.electricImageUrl != null)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,

                      dense: true,

                      title: const Text(
                        'Xóa ảnh công tơ điện đã gửi',
                        style: TextStyle(fontSize: 13),
                      ),

                      value: clearElectricImg,

                      onChanged: (val) =>
                          setDialogState(() => clearElectricImg = val ?? false),
                    ),

                  if (item.waterImageUrl != null)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,

                      dense: true,

                      title: const Text(
                        'Xóa ảnh công tơ nước đã gửi',
                        style: TextStyle(fontSize: 13),
                      ),

                      value: clearWaterImg,

                      onChanged: (val) =>
                          setDialogState(() => clearWaterImg = val ?? false),
                    ),

                  const SizedBox(height: 8),

                  Container(
                    padding: const EdgeInsets.all(10),

                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,

                      borderRadius: BorderRadius.circular(8),
                    ),

                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.blue.shade700,
                        ),

                        const SizedBox(width: 6),

                        Expanded(
                          child: Text(
                            'Hệ thống sẽ giữ nguyên ảnh công tơ trước đó nếu bạn không chủ động xóa.',

                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),

              child: const Text('Đóng'),
            ),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,

                foregroundColor: Colors.white,
              ),

              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;

                      final newElec = double.parse(elecController.text.trim());

                      final newWater = double.parse(
                        waterController.text.trim(),
                      );

                      setDialogState(() => isSaving = true);

                      try {
                        await ref
                            .read(meterReadingRepositoryProvider)
                            .updatePendingSubmission(
                              submissionId: item.id,

                              electricReading: newElec,

                              waterReading: newWater,

                              clearElectricImage: clearElectricImg,

                              clearWaterImage: clearWaterImg,
                            );

                        ref.invalidate(residentMeterReadingsProvider);

                        if (context.mounted) {
                          Navigator.pop(dialogCtx);

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Cập nhật chỉ số điện nước thành công!',
                              ),

                              backgroundColor: AppStatusColors.paid,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(NetworkErrorHandler.getMessage(e)),

                              backgroundColor: AppTheme.error,
                            ),
                          );
                        }
                      }
                    },

              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Lưu thay đổi'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmCancelSubmission(
    BuildContext context,
    MeterReadingSubmissionModel item,
  ) {
    showDialog(
      context: context,

      builder: (dialogCtx) => AlertDialog(
        title: const Text('Hủy Phiếu Khai Báo'),

        content: Text(
          'Bạn có chắc chắn muốn hủy phiếu khai báo chỉ số kỳ ${item.period} không? Hành động này không thể hoàn tác.',
        ),

        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),

            child: const Text('Không'),
          ),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,

              foregroundColor: Colors.white,
            ),

            onPressed: () async {
              Navigator.pop(dialogCtx);

              try {
                await ref
                    .read(meterReadingRepositoryProvider)
                    .cancelPendingSubmission(item.id);

                ref.invalidate(residentMeterReadingsProvider);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã hủy phiếu khai báo chỉ số.'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(NetworkErrorHandler.getMessage(e)),

                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
              }
            },

            child: const Text('Xác nhận hủy'),
          ),
        ],
      ),
    );
  }
}
