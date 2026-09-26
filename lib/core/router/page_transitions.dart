import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Custom page transitions cho GoRouter.
/// Cung cấp các transition mượt mà cho các kiểu chuyển trang khác nhau.
class AppPageTransitions {
  AppPageTransitions._();

  static const Duration _defaultDuration = Duration(milliseconds: 300);
  static const Duration _fastDuration = Duration(milliseconds: 200);

  /// Slide từ bên phải vào — dùng cho navigation push thông thường.
  static CustomTransitionPage<void> slideFromRight({
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: _defaultDuration,
      reverseTransitionDuration: _defaultDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeOutCubic));
        final fadeTween = Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn));
        return SlideTransition(
          position: animation.drive(tween),
          child: FadeTransition(
            opacity: animation.drive(fadeTween),
            child: child,
          ),
        );
      },
    );
  }

  /// Slide lên từ dưới — dùng cho modal-style (tạo mới, form).
  static CustomTransitionPage<void> slideUp({
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: _defaultDuration,
      reverseTransitionDuration: _defaultDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween(begin: const Offset(0.0, 0.3), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeOutCubic));
        final fadeTween = Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut));
        return SlideTransition(
          position: animation.drive(tween),
          child: FadeTransition(
            opacity: animation.drive(fadeTween),
            child: child,
          ),
        );
      },
    );
  }

  /// Fade transition — dùng cho root pages, tab switch.
  static CustomTransitionPage<void> fade({
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: _fastDuration,
      reverseTransitionDuration: _fastDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
          child: child,
        );
      },
    );
  }

  /// Scale + Fade — dùng cho dialog-like transitions.
  static CustomTransitionPage<void> scaleFade({
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: _defaultDuration,
      reverseTransitionDuration: _defaultDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final scaleTween = Tween(begin: 0.92, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutCubic));
        final fadeTween = Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut));
        return ScaleTransition(
          scale: animation.drive(scaleTween),
          child: FadeTransition(
            opacity: animation.drive(fadeTween),
            child: child,
          ),
        );
      },
    );
  }
}
