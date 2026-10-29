import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
  ConsumerState<DocumentLookupScreen> createState() => _DocumentLookupScreenState();
}

class _DocumentLookupScreenState extends ConsumerState<DocumentLookupScreen> {
  late final TextEditingController _codeController;
  bool _isLoading = false;
  DocumentLookupResultModel? _result;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.initialLookupCode ?? '');
    _codeController.addListener(() {
      setState(() {});
    });

    if (widget.initialLookupCode != null && widget.initialLookupCode!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onSearch();
      });
    }
  }

  @override
  void dispose() {
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
            'Lỗi trong quá trình tra cứu: $e',
            lookupCode: code,
          );
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tra Cứu Hóa Đơn & Biên Lai'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thẻ nhập mã tra cứu
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withAlpha(120),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Đối Soát Chứng Từ Điện Tử',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Nhập mã tra cứu in trên hóa đơn điện tử hoặc biên lai để kiểm tra tính hợp lệ và thông tin lưu trữ chính thức.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
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
                                onPressed: () {
                                  _codeController.clear();
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onSubmitted: (_) => _onSearch(),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _onSearch,
                        icon: const Icon(Icons.search),
                        label: const Text(
                          'Tra cứu ngay',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Hiển thị trạng thái đang tải
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40.0),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),

            // Hiển thị kết quả tra cứu
            if (!_isLoading && _hasSearched && _result != null)
              _buildResultCard(context, _result!),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(BuildContext context, DocumentLookupResultModel result) {
    if (result.isValid) {
      return _buildValidCard(context, result);
    } else {
      return _buildInvalidCard(context, result);
    }
  }

  Widget _buildValidCard(BuildContext context, DocumentLookupResultModel result) {
    const successColor = Color(0xFF15803D); // Green 700
    const successBg = Color(0xFFF0FDF4); // Green 50

    final dateFormat = DateFormat('dd/MM/yyyy');
    final dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Card(
      elevation: 0,
      color: successBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: successColor, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: successColor,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CHỨNG TỪ HỢP LỆ & XÁC THỰC',
                        style: TextStyle(
                          color: successColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        result.message ??
                            'Chứng từ đã được phát hành và lưu trữ hợp lệ trên hệ thống.',
                        style: const TextStyle(
                          color: Color(0xFF166534),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Divider(color: Color(0xFFBBF7D0)),
            ),
            _buildDetailRow('Mã tra cứu:', result.lookupCode ?? '---', isHighlight: true),
            _buildDetailRow('Loại chứng từ:', result.documentType ?? 'Hóa đơn dịch vụ'),
            _buildDetailRow('Mã căn hộ:', result.apartmentCode ?? '---'),
            _buildDetailRow('Kỳ thanh toán:', result.period ?? '---'),
            _buildDetailRow('Tổng số tiền:', result.formattedAmount ?? '---', isHighlight: true),
            _buildDetailRow('Trạng thái:', result.statusText ?? '---'),
            if (result.buildingName != null && result.buildingName!.isNotEmpty)
              _buildDetailRow('Tòa nhà / Dự án:', result.buildingName!),
            if (result.issuedDate != null)
              _buildDetailRow('Hạn nộp / Ngày lập:', dateFormat.format(result.issuedDate!)),
            if (result.paidDate != null)
              _buildDetailRow('Thời gian thanh toán:', dateTimeFormat.format(result.paidDate!)),
            if (result.paymentMethod != null && result.paymentMethod!.isNotEmpty)
              _buildDetailRow('Hình thức thanh toán:', result.paymentMethod!),
            if (result.issuer != null && result.issuer!.isNotEmpty)
              _buildDetailRow('Đơn vị phát hành:', result.issuer!),
          ],
        ),
      ),
    );
  }

  Widget _buildInvalidCard(BuildContext context, DocumentLookupResultModel result) {
    const errorColor = Color(0xFFB91C1C); // Red 700
    const errorBg = Color(0xFFFEF2F2); // Red 50

    return Card(
      elevation: 0,
      color: errorBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: errorColor, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.error_outline,
              color: errorColor,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CHỨNG TỪ KHÔNG HỢP LỆ',
                    style: TextStyle(
                      color: errorColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    result.message ??
                        'Không tìm thấy chứng từ với mã tra cứu tương ứng hoặc chứng từ đã bị hủy.',
                    style: const TextStyle(
                      color: Color(0xFF991B1B),
                      fontSize: 14,
                    ),
                  ),
                  if (result.lookupCode != null && result.lookupCode!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Mã tra cứu: ${result.lookupCode}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7F1D1D),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF374151),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isHighlight ? const Color(0xFF0F172A) : const Color(0xFF1F2937),
                fontSize: 13,
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
