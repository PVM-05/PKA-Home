import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/sepay_webhook_payload_model.dart';
import 'package:pka_home/data/models/building_payment_config_model.dart';

void main() {
  group('SePay Models Tests', () {
    test('SepayWebhookPayloadModel parse JSON chuẩn xác và trích xuất payment_code', () {
      final json = {
        'id': 92704,
        'gateway': 'MBBank',
        'transactionDate': '2026-11-08 18:05:00',
        'accountNumber': '0388888888',
        'code': null,
        'content': 'INV2611A0110 thanh toan tien nuoc thang 11',
        'transferType': 'in',
        'transferAmount': 1500000.0,
        'accumulated': 15000000.0,
        'subAccount': null,
        'referenceCode': 'MBVCB.123456789',
        'description': 'Giao dich thanh toan SePay',
      };

      final model = SepayWebhookPayloadModel.fromJson(json);

      expect(model.id, '92704');
      expect(model.gateway, 'MBBank');
      expect(model.accountNumber, '0388888888');
      expect(model.transferType, 'in');
      expect(model.isIncomingTransfer, isTrue);
      expect(model.transferAmount, 1500000.0);
      expect(model.referenceCode, 'MBVCB.123456789');
      expect(model.extractedPaymentCode, 'INV2611A0110');
      expect(model.effectiveIdempotencyKey, '92704');

      final serialized = model.toJson();
      expect(serialized['id'], 92704);
      expect(serialized['transferType'], 'in');
      expect(serialized['transferAmount'], 1500000.0);
    });

    test('SepayWebhookPayloadModel nhận diện đúng giao dịch chi ra out', () {
      final json = {
        'id': '92705',
        'gateway': 'Vietcombank',
        'transferType': 'out',
        'transferAmount': 500000.0,
        'content': 'Rut tien mat ATM',
      };

      final model = SepayWebhookPayloadModel.fromJson(json);
      expect(model.isIncomingTransfer, isFalse);
      expect(model.extractedPaymentCode, isNull);
    });

    test('BuildingPaymentConfigModel serialization và getter VietQR URL', () {
      final json = {
        'id': 'cfg-01',
        'building_id': 'bld-01',
        'sepay_api_key': 'SEPAY_SEC_KEY_123',
        'bank_name': 'MBBank',
        'bank_account_number': '0388888888',
        'bank_account_name': 'BAN QUAN LY PKA HOME',
        'bank_bin': '970422',
        'qr_template': 'compact',
        'is_active': true,
      };

      final model = BuildingPaymentConfigModel.fromJson(json);

      expect(model.id, 'cfg-01');
      expect(model.buildingId, 'bld-01');
      expect(model.bankName, 'MBBank');
      expect(model.bankAccountNumber, '0388888888');
      expect(model.bankAccountName, 'BAN QUAN LY PKA HOME');
      expect(model.bankBin, '970422');
      expect(model.isActive, isTrue);

      final qrUrl = model.generateSepayQrUrl(amount: 1500000, memo: 'INV2611A0110');
      expect(qrUrl, contains('https://qr.sepay.vn/img'));
      expect(qrUrl, contains('acc=0388888888'));
      expect(qrUrl, contains('bank=MBBank'));
      expect(qrUrl, contains('amount=1500000'));
      expect(qrUrl, contains('des=INV2611A0110'));

      final serialized = model.toJson();
      expect(serialized['bank_name'], 'MBBank');
      expect(serialized['bank_account_number'], '0388888888');
    });
  });
}
