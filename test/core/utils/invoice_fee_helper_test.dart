import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/utils/invoice_fee_helper.dart';

void main() {
  group('InvoiceFeeHelper Tests', () {
    test('getFeeName chuẩn hóa tên tiếng Việt chính xác', () {
      expect(InvoiceFeeHelper.getFeeName('management'), 'Phí quản lý');
      expect(InvoiceFeeHelper.getFeeName('electricity'), 'Tiền điện');
      expect(InvoiceFeeHelper.getFeeName('water'), 'Tiền nước');
      expect(InvoiceFeeHelper.getFeeName('parking_motorbike'), 'Phí gửi xe máy');
      expect(InvoiceFeeHelper.getFeeName('parking_car'), 'Phí gửi ô tô');
      expect(InvoiceFeeHelper.getFeeName('internet'), 'Phí Internet');

      // Giữ nguyên khi đã là tiếng Việt
      expect(InvoiceFeeHelper.getFeeName('Phí quản lý'), 'Phí quản lý');
      expect(InvoiceFeeHelper.getFeeName('Tiền điện'), 'Tiền điện');
      expect(InvoiceFeeHelper.getFeeName('Tiền nước'), 'Tiền nước');
      expect(InvoiceFeeHelper.getFeeName('Phí gửi xe máy'), 'Phí gửi xe máy');
      expect(InvoiceFeeHelper.getFeeName('Phí vệ sinh môi trường'), 'Phí vệ sinh môi trường');

      // Giá trị null hoặc rỗng
      expect(InvoiceFeeHelper.getFeeName(null), 'Phí dịch vụ khác');
      expect(InvoiceFeeHelper.getFeeName(''), 'Phí dịch vụ khác');
      expect(InvoiceFeeHelper.getFeeName('   '), 'Phí dịch vụ khác');
    });

    test('getFeeUnit trả về đúng đơn vị đo lường', () {
      expect(InvoiceFeeHelper.getFeeUnit('management'), ' m²');
      expect(InvoiceFeeHelper.getFeeUnit('Phí quản lý'), ' m²');
      expect(InvoiceFeeHelper.getFeeUnit('electricity'), ' kWh');
      expect(InvoiceFeeHelper.getFeeUnit('Tiền điện'), ' kWh');
      expect(InvoiceFeeHelper.getFeeUnit('water'), ' m³');
      expect(InvoiceFeeHelper.getFeeUnit('Tiền nước'), ' m³');
      expect(InvoiceFeeHelper.getFeeUnit('parking_motorbike'), ' xe');
      expect(InvoiceFeeHelper.getFeeUnit('Phí gửi xe máy'), ' xe');
      expect(InvoiceFeeHelper.getFeeUnit('parking_car'), ' xe');
      expect(InvoiceFeeHelper.getFeeUnit('unknown_fee'), '');
      expect(InvoiceFeeHelper.getFeeUnit(null), '');
    });

    test('getFeeIcon và getFeeColor trả về icon và màu sắc phù hợp', () {
      expect(InvoiceFeeHelper.getFeeIcon('management'), Icons.domain_rounded);
      expect(InvoiceFeeHelper.getFeeIcon('electricity'), Icons.electric_bolt_rounded);
      expect(InvoiceFeeHelper.getFeeIcon('water'), Icons.water_drop_rounded);
      expect(InvoiceFeeHelper.getFeeIcon('parking_motorbike'), Icons.two_wheeler_rounded);
      expect(InvoiceFeeHelper.getFeeIcon('parking_car'), Icons.directions_car_rounded);
      expect(InvoiceFeeHelper.getFeeIcon(null), Icons.receipt_long_rounded);

      expect(InvoiceFeeHelper.getFeeColor('management'), isNotNull);
      expect(InvoiceFeeHelper.getFeeColor('electricity'), isNotNull);
      expect(InvoiceFeeHelper.getFeeColor('water'), isNotNull);
      expect(InvoiceFeeHelper.getFeeColor('parking_motorbike'), isNotNull);
      expect(InvoiceFeeHelper.getFeeColor(null), isNotNull);
    });
  });
}
