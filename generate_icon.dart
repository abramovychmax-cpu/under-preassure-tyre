import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Generates the Perfect Pressure app icon
/// Run with: dart run generate_icon.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('Generating Perfect Pressure app icons...');
  
  // Create assets/icon directory
  final iconDir = Directory('assets/icon');
  if (!await iconDir.exists()) {
    await iconDir.create(recursive: true);
  }
  
  // Generate main icon (1024x1024 for best quality)
  await _generateIcon('assets/icon/app_icon.png', 1024, false);
  
  // Generate foreground for adaptive icon (Android)
  await _generateIcon('assets/icon/app_icon_foreground.png', 1024, true);
  
  print('✓ Icon generation complete!');
  print('Run: flutter pub run flutter_launcher_icons');
}

Future<void> _generateIcon(String path, int size, bool transparentBackground) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final paint = Paint();
  
  // Background
  if (!transparentBackground) {
    paint.color = const Color(0xFFF2F2F2);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()), paint);
  }
  
  // Draw the cycling wheel
  _drawWheelIcon(canvas, Size(size.toDouble(), size.toDouble()));
  
  // Convert to image
  final picture = recorder.endRecording();
  final img = await picture.toImage(size, size);
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  final buffer = byteData!.buffer.asUint8List();
  
  // Save to file
  final file = File(path);
  await file.writeAsBytes(buffer);
  print('✓ Generated: $path');
}

void _drawWheelIcon(Canvas canvas, Size size) {
  final center = Offset(size.width / 2, size.height / 2);
  final radius = size.width / 2.6; // Leave padding
  
  // Tire (outer ring) - thicker, darker
  final tirePaint = Paint()
    ..color = const Color(0xFF222222)
    ..style = PaintingStyle.stroke
    ..strokeWidth = size.width * 0.04;
  
  canvas.drawCircle(center, radius - size.width * 0.02, tirePaint);
  
  // Rim (inner circle) - teal accent
  final rimPaint = Paint()
    ..color = const Color(0x6647D1C1) // 40% opacity
    ..style = PaintingStyle.stroke
    ..strokeWidth = size.width * 0.025;
  
  canvas.drawCircle(center, radius - size.width * 0.08, rimPaint);
  
  // Hub (center) - solid teal
  final hubPaint = Paint()
    ..color = const Color(0xFF47D1C1)
    ..style = PaintingStyle.fill;
  
  canvas.drawCircle(center, size.width * 0.05, hubPaint);
  
  // Spokes - 16 radial lines from hub to rim
  final spokePaint = Paint()
    ..color = const Color(0x80666666) // 50% opacity
    ..style = PaintingStyle.stroke
    ..strokeWidth = size.width * 0.008
    ..strokeCap = StrokeCap.round;
  
  for (int i = 0; i < 16; i++) {
    final angle = (i * 360 / 16) * math.pi / 180;
    final spokeStart = Offset(
      center.dx + size.width * 0.05 * math.cos(angle),
      center.dy + size.width * 0.05 * math.sin(angle),
    );
    final spokeEnd = Offset(
      center.dx + (radius - size.width * 0.08) * math.cos(angle),
      center.dy + (radius - size.width * 0.08) * math.sin(angle),
    );
    canvas.drawLine(spokeStart, spokeEnd, spokePaint);
  }
  
  // Valve stem (small detail at bottom for realism)
  final valvePaint = Paint()
    ..color = const Color(0xFF222222)
    ..style = PaintingStyle.fill;
  
  final valveRect = Rect.fromCenter(
    center: Offset(center.dx, center.dy + radius - size.width * 0.02),
    width: size.width * 0.015,
    height: size.width * 0.06,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(valveRect, Radius.circular(size.width * 0.0075)),
    valvePaint,
  );
  
  // Add subtle shadow for depth
  final shadowPaint = Paint()
    ..color = const Color(0x1A000000) // 10% opacity
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.01);
  
  canvas.drawCircle(
    Offset(center.dx + size.width * 0.01, center.dy + size.width * 0.01),
    radius - size.width * 0.02,
    shadowPaint,
  );
}
