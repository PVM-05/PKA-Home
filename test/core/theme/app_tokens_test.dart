import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/core/theme/app_radius.dart';
import 'package:vivona/core/theme/app_spacing.dart';

void main() {
  group('Design System Tokens Tests', () {
    test('AppSpacing: Định nghĩa đầy đủ thang kích thước chuẩn 4-8-12-16-24-32', () {
      expect(AppSpacing.xxs, equals(2.0));
      expect(AppSpacing.xs, equals(4.0));
      expect(AppSpacing.sm, equals(8.0));
      expect(AppSpacing.md, equals(12.0));
      expect(AppSpacing.lg, equals(16.0));
      expect(AppSpacing.xl, equals(20.0));
      expect(AppSpacing.xxl, equals(24.0));
      expect(AppSpacing.xxxl, equals(32.0));
      expect(AppSpacing.huge, equals(48.0));
    });

    test('AppSpacing: Các tiện ích EdgeInsets helpers có giá trị chính xác', () {
      expect(AppSpacing.p4, equals(const EdgeInsets.all(4.0)));
      expect(AppSpacing.p8, equals(const EdgeInsets.all(8.0)));
      expect(AppSpacing.p12, equals(const EdgeInsets.all(12.0)));
      expect(AppSpacing.p16, equals(const EdgeInsets.all(16.0)));
      expect(AppSpacing.p20, equals(const EdgeInsets.all(20.0)));
      expect(AppSpacing.p24, equals(const EdgeInsets.all(24.0)));
      expect(AppSpacing.p32, equals(const EdgeInsets.all(32.0)));

      expect(AppSpacing.px8, equals(const EdgeInsets.symmetric(horizontal: 8.0)));
      expect(AppSpacing.px16, equals(const EdgeInsets.symmetric(horizontal: 16.0)));
      expect(AppSpacing.px24, equals(const EdgeInsets.symmetric(horizontal: 24.0)));

      expect(AppSpacing.py4, equals(const EdgeInsets.symmetric(vertical: 4.0)));
      expect(AppSpacing.py8, equals(const EdgeInsets.symmetric(vertical: 8.0)));
      expect(AppSpacing.py12, equals(const EdgeInsets.symmetric(vertical: 12.0)));
      expect(AppSpacing.py16, equals(const EdgeInsets.symmetric(vertical: 16.0)));
    });

    test('AppSpacing: Các tiện ích SizedBox spacers có chiều cao/rộng chính xác', () {
      expect(AppSpacing.h4.height, equals(4.0));
      expect(AppSpacing.h8.height, equals(8.0));
      expect(AppSpacing.h12.height, equals(12.0));
      expect(AppSpacing.h16.height, equals(16.0));
      expect(AppSpacing.h20.height, equals(20.0));
      expect(AppSpacing.h24.height, equals(24.0));
      expect(AppSpacing.h32.height, equals(32.0));

      expect(AppSpacing.w4.width, equals(4.0));
      expect(AppSpacing.w8.width, equals(8.0));
      expect(AppSpacing.w12.width, equals(12.0));
      expect(AppSpacing.w16.width, equals(16.0));
      expect(AppSpacing.w20.width, equals(20.0));
      expect(AppSpacing.w24.width, equals(24.0));
      expect(AppSpacing.w32.width, equals(32.0));
    });

    test('AppRadius: Định nghĩa đầy đủ các mức bán kính góc bo', () {
      expect(AppRadius.xsValue, equals(4.0));
      expect(AppRadius.smValue, equals(8.0));
      expect(AppRadius.mdValue, equals(12.0));
      expect(AppRadius.lgValue, equals(16.0));
      expect(AppRadius.xlValue, equals(24.0));
      expect(AppRadius.xxlValue, equals(32.0));
      expect(AppRadius.fullValue, equals(999.0));

      expect(AppRadius.radSm, equals(const Radius.circular(8.0)));
      expect(AppRadius.radMd, equals(const Radius.circular(12.0)));
      expect(AppRadius.radLg, equals(const Radius.circular(16.0)));

      expect(AppRadius.rSm, equals(BorderRadius.circular(8.0)));
      expect(AppRadius.rMd, equals(BorderRadius.circular(12.0)));
      expect(AppRadius.rLg, equals(BorderRadius.circular(16.0)));
      expect(AppRadius.rXl, equals(BorderRadius.circular(24.0)));
      expect(AppRadius.rFull, equals(BorderRadius.circular(999.0)));
    });

    test('AppRadius: Các shapes RoundedRectangleBorder và bottomSheet chính xác', () {
      expect(AppRadius.shapeSm.borderRadius, equals(BorderRadius.circular(8.0)));
      expect(AppRadius.shapeMd.borderRadius, equals(BorderRadius.circular(12.0)));
      expect(AppRadius.shapeLg.borderRadius, equals(BorderRadius.circular(16.0)));

      expect(
        AppRadius.bottomSheet,
        equals(const BorderRadius.vertical(top: Radius.circular(24.0))),
      );
    });
  });
}
