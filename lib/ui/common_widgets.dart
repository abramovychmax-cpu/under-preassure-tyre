import 'package:flutter/material.dart';

/// Color constants used throughout the app

// Light theme colors
const Color bgLight = Color(0xFFFAFAFA);

// Dark theme colors  
const Color bgDark = Color(0xFF121418);
const Color cardGrey = Color(0xFF1E2228);

// Accent colors
const Color accentGemini = Color(0xFF47D1C1);

// Border colors
const Color cardBorder = Color(0xFFDDDDDD);

/// Common card widget with consistent styling
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
