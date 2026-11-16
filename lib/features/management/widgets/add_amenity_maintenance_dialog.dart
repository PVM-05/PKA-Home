import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pka_home/core/theme/app_theme.dart';
import 'package:pka_home/core/utils/error_formatter.dart';
import 'package:pka_home/data/providers/amenity_booking_provider.dart';
import 'package:pka_home/data/providers/auth_provider.dart';

void showAddAmenityMaintenanceDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String amenityId,
  required DateTime selectedDate,
}) {
  DateTime start = DateTime(
    selectedDate.year,
    selectedDate.month,
    selectedDate.day,
    8,
    0,
  );
  DateTime end = DateTime(
    selectedDate.year,
    selectedDate.month,
    selectedDate.day,
    12,
    0,
  );
  final reasonController = TextEditingController(
    text: 'Vệ sinh và bảo trì định kỳ',
  );
  final dateFormat = DateFormat('dd/MM/yyyy');
  final timeFormat = DateFormat('HH:mm');

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Thêm Lịch Bảo Trì'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ngày: ${dateFormat.format(selectedDate)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Bắt đầu: '),
                  TextButton(
                    onPressed: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: start.hour,
                          minute: start.minute,
                        ),
                      );
                      if (t != null) {
                        setDialogState(() {
                          start = DateTime(
                            start.year,
                            start.month,
                            start.day,
                            t.hour,
                            t.minute,
                          );
                        });
                      }
                    },
                    child: Text(timeFormat.format(start)),
                  ),
                ],
              ),
              Row(
                children: [
                  const Text('Kết thúc: '),
                  TextButton(
                    onPressed: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: end.hour,
                          minute: end.minute,
                        ),
                      );
                      if (t != null) {
                        setDialogState(() {
                          end = DateTime(
                            end.year,
                            end.month,
                            end.day,
                            t.hour,
                            t.minute,
                          );
                        });
                      }
                    },
                    child: Text(timeFormat.format(end)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Lý do tạm ngưng phục vụ',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (end.isBefore(start) || end.isAtSameMomentAs(start)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Giờ kết thúc phải sau giờ bắt đầu.'),
                  ),
                );
                return;
              }
              Navigator.pop(ctx);
              final user = ref.read(authProvider).valueOrNull;
              try {
                await ref
                    .read(amenityBookingRepositoryProvider)
                    .createMaintenanceWindow(
                      amenityId: amenityId,
                      startTime: start,
                      endTime: end,
                      reason: reasonController.text.trim(),
                      createdBy: user?.id,
                    );
                ref.invalidate(
                  amenityMaintenanceForDateProvider(
                    AmenityDateQuery(
                      amenityId: amenityId,
                      date: selectedDate,
                    ),
                  ),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã tạo lịch bảo trì thành công!'),
                      backgroundColor: AppStatusColors.paid,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(formatErrorMessage(e)),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Lưu lịch'),
          ),
        ],
      ),
    ),
  );
}
