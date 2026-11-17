import 'package:flutter/material.dart';

/// Hệ thống Design Tokens cho khoảng cách (Spacing & Layout)
/// Tuân thủ thang tỷ lệ 4-8-12-16-20-24-32 của Vivona PropTech Design System.
class AppSpacing {
  const AppSpacing._();

  // Thang khoảng cách cơ bản (double)
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
  static const double huge = 48.0;

  // EdgeInsets Tiện ích Toàn diện (All sides)
  static const EdgeInsets p4 = EdgeInsets.all(xs);
  static const EdgeInsets p8 = EdgeInsets.all(sm);
  static const EdgeInsets p12 = EdgeInsets.all(md);
  static const EdgeInsets p16 = EdgeInsets.all(lg);
  static const EdgeInsets p20 = EdgeInsets.all(xl);
  static const EdgeInsets p24 = EdgeInsets.all(xxl);
  static const EdgeInsets p32 = EdgeInsets.all(xxxl);

  // EdgeInsets Theo Chiều Ngang (Horizontal)
  static const EdgeInsets px8 = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets px16 = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets px24 = EdgeInsets.symmetric(horizontal: xxl);

  // EdgeInsets Theo Chiều Dọc (Vertical)
  static const EdgeInsets py4 = EdgeInsets.symmetric(vertical: xs);
  static const EdgeInsets py8 = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets py12 = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets py16 = EdgeInsets.symmetric(vertical: lg);

  // SizedBox Khoảng đệm Chiều Cao (Vertical Spacers)
  static const SizedBox h4 = SizedBox(height: xs);
  static const SizedBox h6 = SizedBox(height: 6.0);
  static const SizedBox h8 = SizedBox(height: sm);
  static const SizedBox h12 = SizedBox(height: md);
  static const SizedBox h16 = SizedBox(height: lg);
  static const SizedBox h20 = SizedBox(height: xl);
  static const SizedBox h24 = SizedBox(height: xxl);
  static const SizedBox h32 = SizedBox(height: xxxl);
  static const SizedBox h40 = SizedBox(height: 40.0);

  // SizedBox Khoảng đệm Chiều Rộng (Horizontal Spacers)
  static const SizedBox w4 = SizedBox(width: xs);
  static const SizedBox w8 = SizedBox(width: sm);
  static const SizedBox w12 = SizedBox(width: md);
  static const SizedBox w16 = SizedBox(width: lg);
  static const SizedBox w20 = SizedBox(width: xl);
  static const SizedBox w24 = SizedBox(width: xxl);
  static const SizedBox w32 = SizedBox(width: xxxl);
}

