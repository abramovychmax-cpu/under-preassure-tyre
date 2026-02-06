import 'package:flutter/material.dart';

// Common colors and reusable card widgets - Light theme throughout
const Color bgLight = Color(0xFFF2F2F2);
const Color bgDark = Color(0xFFF2F2F2); // Now same as light for light theme
const Color cardGrey = Color(0xFFE0E0E0);
const Color cardBorder = Color(0xFFD8D8D8);
const Color cardDark = Color(0xFFF2F2F2); // Changed from dark (#1E2228) to light
const Color accentGemini = Color(0xFF47D1C1);

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? height;
  final Color? color;

  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.height, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: color ?? cardGrey,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0,4))],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

Widget appHeader(String title, {String? subtitle}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 24),
      Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF222222))),
      if (subtitle != null) ...[
        const SizedBox(height: 6),
        Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.black.withOpacity(0.45), fontWeight: FontWeight.w500)),
      ],
      const SizedBox(height: 12),
    ],
  );
}
