import 'package:flutter/material.dart';

/// Hệ thống Design Tokens cho bán kính bo góc (BorderRadius & Shapes)
/// Đảm bảo tính nhất quán và ngôn ngữ thị giác hiện đại của Vivona.
class AppRadius {
  const AppRadius._();

  // Giá trị số thực (double)
  static const double xsValue = 4.0;
  static const double smValue = 8.0;
  static const double mdValue = 12.0;
  static const double lgValue = 16.0;
  static const double xlValue = 24.0;
  static const double xxlValue = 32.0;
  static const double fullValue = 999.0;

  // Bán kính góc Radius
  static const Radius radXs = Radius.circular(xsValue);
  static const Radius radSm = Radius.circular(smValue);
  static const Radius radMd = Radius.circular(mdValue);
  static const Radius radLg = Radius.circular(lgValue);
  static const Radius radXl = Radius.circular(xlValue);
  static const Radius radXxl = Radius.circular(xxlValue);
  static const Radius radFull = Radius.circular(fullValue);

  // Khối BorderRadius hoàn chỉnh
  static final BorderRadius rXs = BorderRadius.circular(xsValue);
  static final BorderRadius rSm = BorderRadius.circular(smValue);
  static final BorderRadius rMd = BorderRadius.circular(mdValue);
  static final BorderRadius rLg = BorderRadius.circular(lgValue);
  static final BorderRadius rXl = BorderRadius.circular(xlValue);
  static final BorderRadius rXxl = BorderRadius.circular(xxlValue);
  static final BorderRadius rFull = BorderRadius.circular(fullValue);

  // Alias số trực quan theo dp phổ biến
  static final BorderRadius r4 = rXs;
  static final BorderRadius r8 = rSm;
  static final BorderRadius r12 = rMd;
  static final BorderRadius r16 = rLg;
  static final BorderRadius r20 = BorderRadius.circular(20.0);
  static final BorderRadius r24 = rXl;
  static final BorderRadius r32 = rXxl;

  // Bo góc chuyên dụng cho Modal BottomSheet (chỉ bo phía trên)
  static const BorderRadius bottomSheet = BorderRadius.vertical(top: radXl);

  // Shapes RoundedRectangleBorder cho Buttons, Cards, Dialogs
  static final RoundedRectangleBorder shapeXs = RoundedRectangleBorder(borderRadius: rXs);
  static final RoundedRectangleBorder shapeSm = RoundedRectangleBorder(borderRadius: rSm);
  static final RoundedRectangleBorder shapeMd = RoundedRectangleBorder(borderRadius: rMd);
  static final RoundedRectangleBorder shapeLg = RoundedRectangleBorder(borderRadius: rLg);
  static final RoundedRectangleBorder shapeXl = RoundedRectangleBorder(borderRadius: rXl);
  static final RoundedRectangleBorder shapeFull = RoundedRectangleBorder(borderRadius: rFull);

  // Shapes alias theo dp
  static final RoundedRectangleBorder shape12 = shapeMd;
  static final RoundedRectangleBorder shape16 = shapeLg;
}

