import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pka_home/core/utils/error_formatter.dart';
import 'package:pka_home/core/utils/network_error_handler.dart';

void main() {
  group('Foreign Key Guard (23503) Tests', () {
    test('Bắt mã 23503 trả về thông báo liên kết dữ liệu thân thiện qua formatErrorMessage', () {
      final fkError = PostgrestException(
        message: 'update or delete on table "apartments" violates foreign key constraint "residents_apartments_apartment_id_fkey"',
        code: '23503',
      );

      final msg = formatErrorMessage(fkError);
      expect(msg, contains('Dữ liệu đang được liên kết'));
    });

    test('Bắt mã 23503 trả về thông báo liên kết dữ liệu qua NetworkErrorHandler', () {
      final fkError = PostgrestException(
        message: 'update or delete on table "invoices" violates foreign key constraint "payment_transactions_invoice_id_fkey"',
        code: '23503',
      );

      final msg = NetworkErrorHandler.getMessage(fkError);
      expect(msg, contains('Không thể xóa dữ liệu này vì đang được liên kết'));
    });
  });
}
