import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_skeleton_shimmer.dart';
import '../../../data/models/document_lookup_result_model.dart';
import '../../../data/providers/document_providers.dart';

/// Màn hình tra cứu tính xác thực của Hóa đơn & Biên lai điện tử (Milestone C4)
class DocumentLookupScreen extends ConsumerStatefulWidget {
  final String? initialLookupCode;

  const DocumentLookupScreen({
    super.key,
    this.initialLookupCode,
  });

  @override
  ConsumerState<DocumentLookupScreen> createState() =>
      _DocumentLookupScreenState();
}

class _DocumentLookupScreenState extends ConsumerState<DocumentLookupScreen> {
  late final TextEditingController _codeController;
  bool _isLoading = false;
  DocumentLookupResultModel? _result;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(
      text: widget.initialLookupCode ?? '',
    );
    _codeController.addListener(_onCodeChanged);

    if (widget.initialLookupCode != null &&
        widget.initialLookupCode!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onSearch();
      });
    }
  }

  void _onCodeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _codeController.removeListener(_onCodeChanged);
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _onSearch() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _hasSearched = true;
        _isLoading = false;
        _result = DocumentLookupResultModel.invalid(
          'Mã tra cứu không được để trống',
          lookupCode: '',
        );
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final repo = ref.read(documentRepositoryProvider);
      final res = await repo.verifyLookupCode(code);
      if (mounted) {
        setState(() {
          _result = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _result = DocumentLookupResultModel.invalid(
            formatErrorMessage(e),
            lookupCode: code,
          );
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tra Cứu Hóa Đơn & Biên Lai'),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SingleChildScrollView(
            padding: AppSpacing.p16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Thẻ nhập mã tra cứu
                AppCard(
                  padding: AppSpacing.p16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            color: colorScheme.primary,
                            size: 24,
                          ),
                          AppSpacing.w8,
                          Expanded(
                            child: Text(
                              'Đối Soát Chứng Từ Điện Tử',
                              style: context.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      AppSpacing.h8,
                      Text(
                        'Nhập mã tra cứu in trên hóa đơn điện tử hoặc biên lai để kiểm tra tính hợp lệ và thông tin lưu trữ chính thức.',
                        style: context.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      AppSpacing.h16,
                      TextField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: 'Mã tra cứu chứng từ',
                          hintText: 'VD: INV-202610-A1B2C',
                          prefixIcon: const Icon(Icons.qr_code_scanner),
                          suffixIcon: _codeController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  tooltip: 'Xóa mã tra cứu',
                                  onPressed: () {
                                    _codeController.clear();
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: AppRadius.r12,
                          ),
                        ),
                        onSubmitted: (_) => _onSearch(),
                      ),
                      AppSpacing.h16,
                      SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _onSearch,
                          icon: const Icon(Icons.search),
                          label: const Text('Tra cứu ngay'),
                        ),
                      ),
                    ],
                  ),
                ),

                AppSpacing.h20,

                // Hiển thị trạng thái đang tải
                if (_isLoading)
                  AppSkeletonShimmer.cardList(count: 1, itemHeight: 180),

                // Hiển thị kết quả tra cứu
                if (!_isLoading && _hasSearched && _result != null)
                  _buildResultCard(context, _result!),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard(
    BuildContext context,
    DocumentLookupResultModel result,
  ) {
    if (result.isValid) {
      return _buildValidCard(context, result);
    }
    return _buildInvalidCard(context, result);
  }

  Widget _buildValidCard(
    BuildContext context,
    DocumentLookupResultModel result,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final successColor = AppStatusColors.getPaid(context);
    final successBg = successColor.withValues(alpha: 0.08);
    final borderColor = successColor.withValues(alpha: 0.45);
    final dividerColor = successColor.withValues(alpha: 0.25);

    final dateFormat = DateFormat('dd/MM/yyyy');
    final dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Container(
      padding: AppSpacing.p16,
      decoration: BoxDecoration(
        color: successBg,
        borderRadius: AppRadius.r16,
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check_circle,
                color: successColor,
                size: 32,
              ),
              AppSpacing.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CHỨNG TỪ HỢP LỆ & XÁC THỰC',
                      style: context.titleMedium?.copyWith(
                        color: successColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    AppSpacing.h4,
                    Text(
                      result.message ??
                          'Chứng từ đã được phát hành và lưu trữ hợp lệ trên hệ thống.',
                      style: context.bodySmall?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Divider(color: dividerColor),
          ),
          _buildDetailRow(
            context,
            'Mã tra cứu:',
            result.lookupCode ?? '---',
            isHighlight: true,
          ),
          _buildDetailRow(
            context,
            'Loại chứng từ:',
            result.documentType ?? 'Hóa đơn dịch vụ',
          ),
          _buildDetailRow(
            context,
            'Mã căn hộ:',
            result.apartmentCode ?? '---',
          ),
          _buildDetailRow(
            context,
            'Kỳ thanh toán:',
            result.period ?? '---',
          ),
          _buildDetailRow(
            context,
            'Tổng số tiền:',
            result.formattedAmount ?? '---',
            isHighlight: true,
          ),
          _buildDetailRow(
            context,
            'Trạng thái:',
            result.statusText ?? '---',
          ),
          if (result.buildingName != null && result.buildingName!.isNotEmpty)
            _buildDetailRow(context, 'Tòa nhà / Dự án:', result.buildingName!),
          if (result.issuedDate != null)
            _buildDetailRow(
              context,
              'Hạn nộp / Ngày lập:',
              dateFormat.format(result.issuedDate!),
            ),
          if (result.paidDate != null)
            _buildDetailRow(
              context,
              'Thời gian thanh toán:',
              dateTimeFormat.format(result.paidDate!),
            ),
          if (result.paymentMethod != null && result.paymentMethod!.isNotEmpty)
            _buildDetailRow(
              context,
              'Hình thức thanh toán:',
              result.paymentMethod!,
            ),
          if (result.issuer != null && result.issuer!.isNotEmpty)
            _buildDetailRow(context, 'Đơn vị phát hành:', result.issuer!),
        ],
      ),
    );
  }

  Widget _buildInvalidCard(
    BuildContext context,
    DocumentLookupResultModel result,
  ) {
    final errorColor = AppStatusColors.getUnpaid(context);
    final errorBg = errorColor.withValues(alpha: 0.08);
    final borderColor = errorColor.withValues(alpha: 0.45);

    return Container(
      padding: AppSpacing.p16,
      decoration: BoxDecoration(
        color: errorBg,
        borderRadius: AppRadius.r16,
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline,
            color: errorColor,
            size: 32,
          ),
          AppSpacing.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CHỨNG TỪ KHÔNG HỢP LỆ',
                  style: context.titleMedium?.copyWith(
                    color: errorColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                AppSpacing.h6,
                Text(
                  result.message ??
                      'Không tìm thấy chứng từ với mã tra cứu tương ứng hoặc chứng từ đã bị hủy.',
                  style: context.bodyMedium?.copyWith(
                    color: errorColor,
                  ),
                ),
                if (result.lookupCode != null &&
                    result.lookupCode!.isNotEmpty) ...[
                  AppSpacing.h8,
                  Text(
                    'Mã tra cứu: ${result.lookupCode}',
                    style: context.labelSmall?.tabularFigures().copyWith(
                      color: errorColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final valueColor = isHighlight
        ? colorScheme.primary
        : colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: context.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          AppSpacing.w8,
          Expanded(
            child: Text(
              value,
              style: context.bodySmall?.tabularFigures().copyWith(
                color: valueColor,
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
