import 'package:flutter/material.dart';

class InvoiceSummary extends StatelessWidget {
  final double totalAmount;
  final int unpaidCount;

  const InvoiceSummary({
    super.key,
    required this.totalAmount,
    required this.unpaidCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tổng tiền cần đóng',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${totalAmount.toStringAsFixed(0)} VNĐ',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$unpaidCount hóa đơn chưa thanh toán',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: () {
              // Điều hướng đến trang thanh toán
            },
            child: const Text('Thanh toán ngay'),
          ),
        ],
      ),
    );
  }
}
