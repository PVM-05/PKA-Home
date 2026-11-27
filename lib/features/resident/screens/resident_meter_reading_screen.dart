import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/utils/network_error_handler.dart';
import '../../../core/utils/utility_anomaly_detector.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../core/widgets/app_skeleton_shimmer.dart';
import '../../../core/widgets/app_unsaved_changes_guard.dart';
import '../../../data/models/meter_reading_submission_model.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/meter_reading_provider.dart';
import '../../../data/providers/vehicle_provider.dart';
import '../../../data/services/meter_ocr_service.dart';
import '../widgets/meter/meter_reading_dialogs.dart';
import '../widgets/meter/meter_reading_history_section.dart';
import '../widgets/meter/meter_reading_input_card.dart';
import '../widgets/meter/resident_meter_card.dart';

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

      final ocrService = ref.read(meterOcrServiceProvider);
      final ocrResult = await ocrService.recognizeMeterReading(
        imagePath: image.path,
        meterType: type,
      );

      if (!mounted) return;

      setState(() {
        if (type == MeterType.electric) {
          _isElectricOcrScanning = false;
          if (ocrResult.isValid) {
            final valStr =
                ocrResult.detectedReading ==
                    ocrResult.detectedReading.roundToDouble()
                ? ocrResult.detectedReading.toInt().toString()
                : ocrResult.detectedReading.toString();
            _electricController.text = valStr;
          }
        } else {
          _isWaterOcrScanning = false;
          if (ocrResult.isValid) {
            final valStr =
                ocrResult.detectedReading ==
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
            backgroundColor: AppTheme.textWarning,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isElectricOcrScanning = false;
        _isWaterOcrScanning = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(formatErrorMessage(e)),
          backgroundColor: AppTheme.textError,
        ),
      );
    }
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
      final val = type == MeterType.electric
          ? r.electricConsumed
          : r.waterConsumed;
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
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final elecVal = double.tryParse(_electricController.text.trim()) ?? 0.0;
    final waterVal = double.tryParse(_waterController.text.trim()) ?? 0.0;

    final existingReadings =
        ref.read(residentMeterReadingsProvider).valueOrNull ?? [];
    final avgElec = _calculateDynamicAverageUsage(
      existingReadings,
      MeterType.electric,
    );
    final avgWater = _calculateDynamicAverageUsage(
      existingReadings,
      MeterType.water,
    );

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
          backgroundColor: AppTheme.textError,
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
          backgroundColor: AppTheme.textError,
        ),
      );
      return;
    }

    if (elecAnalysis.severity == AnomalySeverity.danger &&
        _electricImagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Mức tiêu thụ điện tăng vọt ở mức NGUY HIỂM (>300% trung bình). Bạn bắt buộc phải chụp ảnh mặt công tơ thật để gửi BQL đối soát.',
          ),
          backgroundColor: AppTheme.textError,
        ),
      );
      return;
    }

    if (waterAnalysis.severity == AnomalySeverity.danger &&
        _waterImagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Mức tiêu thụ nước tăng vọt ở mức NGUY HIỂM (>300% trung bình). Bạn bắt buộc phải chụp ảnh mặt đồng hồ nước thật để gửi BQL đối soát.',
          ),
          backgroundColor: AppTheme.textError,
        ),
      );
      return;
    }

    final isDanger =
        elecAnalysis.severity == AnomalySeverity.danger ||
        waterAnalysis.severity == AnomalySeverity.danger;

    final hasSevereAnomaly =
        (elecAnalysis.isAnomaly &&
            (elecAnalysis.severity == AnomalySeverity.warning ||
                elecAnalysis.severity == AnomalySeverity.danger)) ||
        (waterAnalysis.isAnomaly &&
            (waterAnalysis.severity == AnomalySeverity.warning ||
                waterAnalysis.severity == AnomalySeverity.danger));

    String? residentExplanation;

    if (hasSevereAnomaly) {
      final reasons = <String>[
        if (elecAnalysis.isAnomaly &&
            (elecAnalysis.severity == AnomalySeverity.warning ||
                elecAnalysis.severity == AnomalySeverity.danger) &&
            elecAnalysis.reason != null)
          elecAnalysis.reason!,
        if (waterAnalysis.isAnomaly &&
            (waterAnalysis.severity == AnomalySeverity.warning ||
                waterAnalysis.severity == AnomalySeverity.danger) &&
            waterAnalysis.reason != null)
          waterAnalysis.reason!,
      ];

      final dialogResult = await showMeterAnomalyConfirmDialog(
        context: context,
        isDanger: isDanger,
        reasons: reasons,
      );

      if (!dialogResult.proceed) return;
      residentExplanation = dialogResult.explanation;
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
          backgroundColor: AppTheme.textError,
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
          backgroundColor: AppTheme.textError,
        ),
      );
      return;
    }

    if (_electricImagePath == null && _waterImagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Lưu ý: Bạn gửi chỉ số nhập tay mà không đính kèm ảnh công tơ thật. Ban Quản Lý có thể yêu cầu đối soát trực tiếp.',
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(meterReadingRepositoryProvider);

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

      final confidence =
          (_electricImagePath != null || _waterImagePath != null) ? 1.0 : 0.85;
      final isAnomaly = elecAnalysis.isAnomaly || waterAnalysis.isAnomaly;
      final severity = isDanger
          ? 'danger'
          : ((elecAnalysis.severity == AnomalySeverity.warning ||
                    waterAnalysis.severity == AnomalySeverity.warning)
                ? 'warning'
                : 'normal');

      final anomalyReason =
          residentExplanation != null && residentExplanation.isNotEmpty
          ? residentExplanation
          : (elecAnalysis.reason ?? waterAnalysis.reason);

      await repo.submitReading(
        apartmentId: aptId,
        userId: user.id,
        period: period,
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
            backgroundColor: AppTheme.textSuccess,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(NetworkErrorHandler.getMessage(e)),
            backgroundColor: AppTheme.textError,
          ),
        );
      }
    }
  }

  bool get _hasUnsavedChanges =>
      _electricController.text.trim().isNotEmpty ||
      _waterController.text.trim().isNotEmpty ||
      _electricImagePath != null ||
      _waterImagePath != null;

  @override
  Widget build(BuildContext context) {
    final aptReadingsAsync = ref.watch(currentApartmentReadingsProvider);
    final historyAsync = ref.watch(residentMeterReadingsProvider);

    return AppUnsavedChangesGuard(
      hasUnsavedChanges: _hasUnsavedChanges && !_isSubmitting,
      child: Scaffold(
        appBar: AppBar(title: const Text('Khai Báo Chỉ Số Điện Nước')),
        body: aptReadingsAsync.when(
          data: (aptData) {
            if (aptData == null) {
              return Center(
                child: Padding(
                  padding: AppSpacing.p24,
                  child: AppEmptyState(
                    icon: Icons.apartment_outlined,
                    title: 'Chưa có dữ liệu căn hộ liên kết.',
                    description:
                        'Vui lòng liên kết căn hộ tại trang chủ trước khi gửi chỉ số.',
                    actionLabel: 'Quay lại trang chủ',
                    onAction: () => Navigator.pop(context),
                  ),
                ),
              );
            }

            final aptCode = aptData['code'] as String? ?? '';
            final oldElec =
                (aptData['electric_reading'] as num?)?.toDouble() ?? 0.0;
            final oldWater =
                (aptData['water_reading'] as num?)?.toDouble() ?? 0.0;

            final currentElecInput = double.tryParse(
              _electricController.text.trim(),
            );
            final currentWaterInput = double.tryParse(
              _waterController.text.trim(),
            );

            final historyList = historyAsync.valueOrNull ?? [];
            final avgElec = _calculateDynamicAverageUsage(
              historyList,
              MeterType.electric,
            );
            final avgWater = _calculateDynamicAverageUsage(
              historyList,
              MeterType.water,
            );

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
            final warningWidget = DateTime.now().day > 25
                ? _buildOverdueWarning(context)
                : null;
            final previousCard = ResidentPreviousMeterCard(
              aptCode: aptCode,
              oldElec: oldElec,
              oldWater: oldWater,
            );
            final electricCard = MeterReadingInputCard(
              meterType: MeterType.electric,
              controller: _electricController,
              previousReading: oldElec,
              imagePath: _electricImagePath,
              isOcrScanning: _isElectricOcrScanning,
              analysis: elecAnalysis,
              onPickCamera: () => _pickMeterImage(
                MeterType.electric,
                ImageSource.camera,
              ),
              onPickGallery: () => _pickMeterImage(
                MeterType.electric,
                ImageSource.gallery,
              ),
              onClearImage: () => setState(() => _electricImagePath = null),
            );
            final waterCard = MeterReadingInputCard(
              meterType: MeterType.water,
              controller: _waterController,
              previousReading: oldWater,
              imagePath: _waterImagePath,
              isOcrScanning: _isWaterOcrScanning,
              analysis: waterAnalysis,
              onPickCamera: () => _pickMeterImage(
                MeterType.water,
                ImageSource.camera,
              ),
              onPickGallery: () => _pickMeterImage(
                MeterType.water,
                ImageSource.gallery,
              ),
              onClearImage: () => setState(() => _waterImagePath = null),
            );
            final periodField = _buildPeriodField();
            final submitButton = _buildSubmitButton(context, oldElec, oldWater);
            final historySection = MeterReadingHistorySection(
              historyAsync: historyAsync,
              dateFormat: _dateFormat,
              onRetry: () => ref.invalidate(residentMeterReadingsProvider),
              onEdit: (item) => showEditMeterSubmissionDialog(
                context: context,
                ref: ref,
                item: item,
              ),
              onCancel: (item) => showCancelMeterSubmissionDialog(
                context: context,
                ref: ref,
                item: item,
              ),
            );

            final Widget content;
            if (isDesktop) {
              content = Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ?warningWidget,
                              previousCard,
                              AppSpacing.h24,
                              historySection,
                            ],
                          ),
                        ),
                        AppSpacing.w24,
                        Expanded(
                          flex: 7,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              electricCard,
                              AppSpacing.h16,
                              waterCard,
                              AppSpacing.h16,
                              periodField,
                              AppSpacing.h20,
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
                padding: AppSpacing.p16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ?warningWidget,
                    previousCard,
                    AppSpacing.h16,
                    electricCard,
                    AppSpacing.h16,
                    waterCard,
                    AppSpacing.h16,
                    periodField,
                    AppSpacing.h20,
                    submitButton,
                    AppSpacing.h24,
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
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const AlwaysScrollableScrollPhysics(),
                child: Form(
                  key: _formKey,
                  child: content,
                ),
              ),
            );
          },
          loading: () => ListView(
            padding: AppSpacing.p16,
            children: [
              AppSkeletonShimmer.cardList(count: 3, itemHeight: 140),
            ],
          ),
          error: (e, _) => Center(
            child: AppErrorCard(
              error: e,
              onRetry: () => ref.invalidate(currentApartmentReadingsProvider),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverdueWarning(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final warningColor = AppTheme.getSemanticWarning(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: AppSpacing.p12,
      decoration: BoxDecoration(
        color: warningColor.withValues(alpha: isDark ? 0.14 : 0.08),
        borderRadius: AppRadius.r12,
        border: Border.all(
          color: warningColor.withValues(alpha: isDark ? 0.45 : 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: warningColor,
            size: 22,
          ),
          AppSpacing.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lưu ý: Đã quá hạn chốt số tháng này (Hạn chót: ngày 25)',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: warningColor,
                  ),
                ),
                AppSpacing.h4,
                Text(
                  'Vui lòng gửi chỉ số sớm nhất có thể để tránh bị tạm tính chỉ số theo mức trung bình của căn hộ.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
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

  Widget _buildSubmitButton(
    BuildContext context,
    double oldElec,
    double oldWater,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: colorScheme.onPrimary,
            minimumSize: const Size(double.infinity, 48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.r12,
            ),
          ),
          icon: _isSubmitting
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.onPrimary,
                  ),
                )
              : const Icon(Icons.send_outlined),
          label: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _isSubmitting ? 'Đang gửi...' : 'Gửi chỉ số cho Ban Quản Lý',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onPrimary,
              ),
            ),
          ),
          onPressed: _isSubmitting ? null : () => _submit(oldElec, oldWater),
        ),
      ),
    );
  }
}
