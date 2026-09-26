import 'package:flutter/material.dart';

/// Widget Avatar hiển thị ảnh đại diện hoặc chữ cái đầu (Initials) với dải màu gradient hiện đại.
class AppAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double size;
  final double? fontSize;
  final Widget? badge;
  final VoidCallback? onTap;

  const AppAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 40,
    this.fontSize,
    this.badge,
    this.onTap,
  });

  /// Sinh initials từ tên (tối đa 2 chữ cái)
  static String getInitials(String fullName) {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  /// Bảng màu gradient hiện đại, hài hòa
  static const List<List<Color>> _gradientPalettes = [
    [Color(0xFF2563EB), Color(0xFF3B82F6)], // Blue
    [Color(0xFF0D9488), Color(0xFF14B8A6)], // Teal
    [Color(0xFF7C3AED), Color(0xFF8B5CF6)], // Purple
    [Color(0xFFEA580C), Color(0xFFF97316)], // Orange
    [Color(0xFF059669), Color(0xFF10B981)], // Emerald
    [Color(0xFFDB2777), Color(0xFFEC4899)], // Pink
    [Color(0xFF4F46E5), Color(0xFF6366F1)], // Indigo
  ];

  List<Color> _getGradientForName(String str) {
    int hash = 0;
    for (int i = 0; i < str.length; i++) {
      hash = str.codeUnitAt(i) + ((hash << 5) - hash);
    }
    final index = hash.abs() % _gradientPalettes.length;
    return _gradientPalettes[index];
  }

  @override
  Widget build(BuildContext context) {
    final initials = getInitials(name);
    final gradient = _getGradientForName(name);
    final computedFontSize = fontSize ?? (size * 0.38);

    Widget avatarWidget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? ClipOval(
              child: Image.network(
                imageUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Text(
                    initials,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: computedFontSize,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            )
          : Center(
              child: Text(
                initials,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: computedFontSize,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
    );

    if (badge != null) {
      avatarWidget = Stack(
        clipBehavior: Clip.none,
        children: [
          avatarWidget,
          Positioned(
            right: -2,
            bottom: -2,
            child: badge!,
          ),
        ],
      );
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatarWidget,
      );
    }

    return avatarWidget;
  }
}
