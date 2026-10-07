import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../core/utils/meter_ocr_simulator.dart';
import '../../../data/providers/meter_reading_provider.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/vehicle_provider.dart';
import '../../../core/utils/network_error_handler.dart';
import '../../../core/utils/validators.dart';

class ResidentMeterReadingScreen extends ConsumerStatefulWidget {
  const ResidentMeterReadingScreen({super.key});

  @override
  ConsumerState<ResidentMeterReadingScreen> createState() => _ResidentMeterReadingScreenState();
}

class _ResidentMeterReadingScreenState extends ConsumerState<ResidentMeterReadingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _electricController = TextEditingController();
  final _waterController = TextEditingController();
  late final TextEditingController _periodController;

  bool _isScanningElectric = false;
  bool _isScanningWater = false;
  bool _isSubmitting = false;

  String? _electricImagePath;
  String? _waterImagePath;
  MeterOcrResult? _electricOcrResult;
  MeterOcrResult? _waterOcrResult;

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _periodController = TextEditingController(text: '${now.month.toString().padLeft(2, '0')}/${now.year}');
  }

  @override
  void dispose() {
    _electricController.dispose();
    _waterController.dispose();
    _periodController.dispose();
    super.dispose();
  }

  Future<void> _scanMeter(MeterType type, double oldReading) async {
    setState(() {
      if (type == MeterType.electric) {
        _isScanningElectric = true;
      } else {
        _isScanningWater = true;
      }
    });

    try {
      final result = await MeterOcrSimulator.simulateScan(
        meterType: type,
        currentReading: oldReading,
        simulatedDelayMs: 1200,
      );

      if (mounted) {
        setState(() {
          if (type == MeterType.electric) {
            _electricOcrResult = result;
            _electricImagePath = null;
            _electricController.text = result.detectedReading.toString();
            _isScanningElectric = false;
          } else {
            _waterOcrResult = result;
            _waterImagePath = null;
            _waterController.text = result.detectedReading.toString();
            _isScanningWater = false;
          }
        });


        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã nhận diện thành công: ${result.detectedReading} ${result.unit} (Độ tin cậy ${(result.confidence * 100).toStringAsFixed(1)}%)'),
            backgroundColor: AppStatusColors.paid,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isScanningElectric = false;
          _isScanningWater = false;
        });
      }
    }
  }

  Future<void> _submit(double oldElec, double oldWater) async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final elecVal = double.tryParse(_electricController.text.trim()) ?? 0.0;
    final waterVal = double.tryParse(_waterController.text.trim()) ?? 0.0;

    if (elecVal < oldElec) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Chỉ số điện mới ($elecVal) không được nhỏ hơn chỉ số cũ ($oldElec kWh).'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    if (waterVal < oldWater) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Chỉ số nước mới ($waterVal) không được nhỏ hơn chỉ số cũ ($oldWater m³).'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    final period = _periodController.text.trim();
    final existingReadings = ref.read(residentMeterReadingsProvider).valueOrNull ?? [];
    final alreadySubmitted = existingReadings.any((r) => r.period == period && !r.isRejected);
    if (alreadySubmitted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kỳ $period đã được gửi khai báo trước đó. Vui lòng chờ Ban Quản Lý xử lý.'),
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

    setState(() => _isSubmitting = true);

    try {
      await ref.read(meterReadingRepositoryProvider).submitReading(
            apartmentId: aptId,
            userId: user.id,
            period: _periodController.text.trim(),
            electricReading: elecVal,
            waterReading: waterVal,
            electricImageUrl: _electricImagePath,
            waterImageUrl: _waterImagePath,
          );

      ref.invalidate(residentMeterReadingsProvider);

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _electricController.clear();
          _waterController.clear();
          _electricOcrResult = null;
          _waterOcrResult = null;
          _electricImagePath = null;
          _waterImagePath = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã gửi chỉ số điện nước thành công! Ban Quản Lý sẽ sớm kiểm tra và xác nhận.'),
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
      appBar: AppBar(
        title: const Text('Khai Báo Chỉ Số Điện Nước'),
      ),
      body: aptReadingsAsync.when(
        data: (aptData) {
          if (aptData == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.home_work_outlined, size: 64, color: AppTheme.textSecondary),
                    const SizedBox(height: 16),
                    const Text(
                      'Bạn chưa liên kết với căn hộ nào',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Vui lòng gửi yêu cầu liên kết căn hộ để có thể khai báo chỉ số điện nước.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pushNamed('/link-request'),
                      icon: const Icon(Icons.link),
                      label: const Text('Gửi yêu cầu liên kết'),
                    ),
                  ],
                ),
              ),
            );
          }

          final aptCode = aptData['code'] as String? ?? '';
          final oldElec = (aptData['electric_reading'] as num?)?.toDouble() ?? 0.0;
          final oldWater = (aptData['water_reading'] as num?)?.toDouble() ?? 0.0;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(currentApartmentReadingsProvider);
              ref.invalidate(residentMeterReadingsProvider);
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cảnh báo nếu đã quá hạn nộp chỉ số (hạn chót ngày 25 hàng tháng)
                    if (DateTime.now().day > 25) ...[
                      Container(
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
                            Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 22),
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
                                    style: TextStyle(fontSize: 12, color: Colors.black87),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Banner đối chiếu chỉ số cũ
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.history_toggle_off, color: AppTheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Chỉ số kỳ trước • Căn hộ $aptCode',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                                    border: Border.all(color: Colors.amber.shade200),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.bolt, color: Colors.amber.shade800, size: 20),
                                          const SizedBox(width: 4),
                                          const Text('Điện cũ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '$oldElec kWh',
                                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
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
                                    border: Border.all(color: Colors.blue.shade200),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.water_drop, color: Colors.blue.shade800, size: 20),
                                          const SizedBox(width: 4),
                                          const Text('Nước cũ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '$oldWater m³',
                                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
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

                    // Khối khai báo công tơ điện
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.bolt, color: Colors.amber),
                                  SizedBox(width: 6),
                                  Text('Công tơ Điện (kWh)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                                icon: const Icon(Icons.document_scanner_outlined, size: 16),
                                label: const Text('Quét ảnh Smart OCR'),
                                onPressed: _isScanningElectric ? null : () => _scanMeter(MeterType.electric, oldElec),
                              ),
                            ],
                          ),
                          if (_isScanningElectric) ...[
                            const SizedBox(height: 12),
                            const LinearProgressIndicator(),
                            const SizedBox(height: 6),
                            const Center(
                              child: Text(
                                'AI đang quét và trích xuất chỉ số công tơ điện...',
                                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                            ),
                          ],
                          if (_electricOcrResult != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppStatusColors.paid.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle_outline, size: 14, color: AppStatusColors.paid),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Đã nhận diện qua ảnh • Độ tin cậy ${(_electricOcrResult!.confidence * 100).toStringAsFixed(1)}%',
                                    style: const TextStyle(fontSize: 12, color: AppStatusColors.paid, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _electricController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Khối khai báo công tơ nước
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.water_drop, color: Colors.blue),
                                  SizedBox(width: 6),
                                  Text('Công tơ Nước (m³)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                                icon: const Icon(Icons.document_scanner_outlined, size: 16),
                                label: const Text('Quét ảnh Smart OCR'),
                                onPressed: _isScanningWater ? null : () => _scanMeter(MeterType.water, oldWater),
                              ),
                            ],
                          ),
                          if (_isScanningWater) ...[
                            const SizedBox(height: 12),
                            const LinearProgressIndicator(),
                            const SizedBox(height: 6),
                            const Center(
                              child: Text(
                                'AI đang quét và trích xuất chỉ số công tơ nước...',
                                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                            ),
                          ],
                          if (_waterOcrResult != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppStatusColors.paid.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle_outline, size: 14, color: AppStatusColors.paid),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Đã nhận diện qua ảnh • Độ tin cậy ${(_waterOcrResult!.confidence * 100).toStringAsFixed(1)}%',
                                    style: const TextStyle(fontSize: 12, color: AppStatusColors.paid, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _waterController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Kỳ khai báo
                    TextFormField(
                      controller: _periodController,
                      decoration: const InputDecoration(
                        labelText: 'Kỳ khai báo (MM/yyyy) *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_month_outlined),
                      ),
                      validator: validateInvoicePeriod,
                    ),
                    const SizedBox(height: 20),

                    // Nút gửi
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: _isSubmitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send_outlined),
                        label: Text(
                          _isSubmitting ? 'Đang gửi...' : 'Gửi chỉ số cho Ban Quản Lý',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        onPressed: _isSubmitting ? null : () => _submit(oldElec, oldWater),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Danh sách lịch sử các lần gửi
                    const Text(
                      'Lịch Sử Khai Báo Chỉ Số',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    historyAsync.when(
                      data: (history) {
                        if (history.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Text('Chưa có lịch sử khai báo chỉ số nào.', style: TextStyle(color: AppTheme.textSecondary)),
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
                            if (item.isApproved) statusColor = AppStatusColors.paid;
                            if (item.isRejected) statusColor = AppTheme.error;

                            return AppCard(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Kỳ: ${item.period}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          item.statusDisplayName,
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text('Điện: ${item.electricReading} kWh', style: const TextStyle(fontWeight: FontWeight.w500)),
                                      ),
                                      Expanded(
                                        child: Text('Nước: ${item.waterReading} m³', style: const TextStyle(fontWeight: FontWeight.w500)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Gửi lúc: ${_dateFormat.format(item.createdAt)}',
                                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                  ),
                                  if (item.isRejected && item.rejectReason != null) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.error.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.info_outline, size: 16, color: AppTheme.error),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              'Lý do từ chối: ${item.rejectReason}',
                                              style: const TextStyle(fontSize: 13, color: AppTheme.error),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => AppErrorCard(error: e),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: AppErrorCard(error: e)),
      ),
    );
  }
}
