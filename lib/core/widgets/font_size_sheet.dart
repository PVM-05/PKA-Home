import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/accessibility_provider.dart';
import '../theme/app_theme.dart';

/// Hiển thị bottom sheet tùy chỉnh cỡ chữ hiển thị toàn ứng dụng với chế độ xem trước trực tiếp.
void showFontSizeBottomSheet(BuildContext context, WidgetRef ref) {
  final currentScale = ref.read(fontSizeScaleProvider);
  FontSizeOption selectedOption = FontSizeOption.fromScale(currentScale);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (modalContext, setModalState) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Tùy Chỉnh Cỡ Chữ Hiển Thị',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primary),
              ),
              const SizedBox(height: 6),
              Text(
                'Điều chỉnh kích thước phông chữ toàn bộ ứng dụng giúp người lớn tuổi hoặc mắt yếu dễ đọc nội dung hơn.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
              ),
              const SizedBox(height: 16),

              // Xem trước hiển thị
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Xem trước hiển thị:',
                      style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    MediaQuery(
                      data: MediaQuery.of(modalContext).copyWith(
                        textScaler: TextScaler.linear(selectedOption.scale),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Thông báo Ban Quản Lý',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Kính gửi Quý Cư dân, kỳ thu phí dịch vụ tháng này đã được cập nhật trên ứng dụng.',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              ...FontSizeOption.values.map((opt) {
                final isSelected = selectedOption == opt;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary.withValues(alpha: 0.08) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppTheme.primary : Colors.grey.shade200,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    leading: Icon(
                      Icons.text_fields_outlined,
                      color: isSelected ? AppTheme.primary : Colors.grey.shade600,
                      size: opt == FontSizeOption.extraLarge ? 28 : (opt == FontSizeOption.large ? 24 : 20),
                    ),
                    title: Text(
                      opt.label,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? AppTheme.primary : Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      opt.description,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: AppTheme.primary)
                        : const Icon(Icons.radio_button_unchecked, color: Colors.grey),
                    onTap: () {
                      setModalState(() {
                        selectedOption = opt;
                      });
                    },
                  ),
                );
              }),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    await ref.read(fontSizeScaleProvider.notifier).setScale(selectedOption.scale);
                    if (modalContext.mounted) {
                      Navigator.pop(modalContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Đã đổi cỡ chữ thành "${selectedOption.label}"'),
                          backgroundColor: AppStatusColors.paid,
                        ),
                      );
                    }
                  },
                  child: const Text('Áp Dụng Cỡ Chữ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
