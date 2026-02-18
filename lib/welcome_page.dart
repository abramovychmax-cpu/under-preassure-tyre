import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'sensor_guide_page.dart';
import 'ui/common_widgets.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  void _navigateToSetup() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SensorGuidePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! < -500) {
            _navigateToSetup();
          }
        },
        child: const SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                SizedBox(height: 40),
                Spacer(flex: 2),
                Column(
                  children: [
                    CyclingWheelIcon(size: 160),
                    SizedBox(height: 48),
                    Text(
                      'PERFECT\nPRESSURE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF222222),
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        height: 1.1,
                      ),
                    ),
                    SizedBox(height: 24),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'This app will help you find the fastest tire pressure for you and your bike setup.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 17,
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Get ready to set up the app.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                    Text(
                      'SWIPE RIGHT TO CONTINUE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: accentGemini,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
                Spacer(flex: 3),
                SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CyclingWheelIcon extends StatelessWidget {
  final double size;

  const CyclingWheelIcon({super.key, this.size = 120});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _WheelPainter(),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final tirePaint = Paint()
      ..color = const Color(0xFF222222)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0;
    canvas.drawCircle(center, radius - 4, tirePaint);

    final rimPaint = Paint()
      ..color = const Color(0x4D47D1C1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawCircle(center, radius - 16, rimPaint);

    final hubPaint = Paint()
      ..color = accentGemini
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 8, hubPaint);

    final spokePaint = Paint()
      ..color = const Color(0x66666666)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (int i = 0; i < 16; i++) {
      final angle = (i * 360 / 16) * math.pi / 180;
      final spokeStart = Offset(
        center.dx + 8 * math.cos(angle),
        center.dy + 8 * math.sin(angle),
      );
      final spokeEnd = Offset(
        center.dx + (radius - 16) * math.cos(angle),
        center.dy + (radius - 16) * math.sin(angle),
      );
      canvas.drawLine(spokeStart, spokeEnd, spokePaint);
    }

    final valvePaint = Paint()
      ..color = const Color(0xFF222222)
      ..style = PaintingStyle.fill;
    final valveRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + radius - 4),
      width: 3,
      height: 12,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(valveRect, const Radius.circular(1.5)),
      valvePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
