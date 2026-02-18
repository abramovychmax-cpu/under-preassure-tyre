import 'package:flutter/material.dart';
import 'wheel_metrics_page.dart';
import 'ui/common_widgets.dart';

class WheelMetricsGuidePage extends StatelessWidget {
  const WheelMetricsGuidePage({super.key});

  void _navigateToMetrics(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const WheelMetricsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! < -500) {
            _navigateToMetrics(context);
          }
        },
        child: const SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                SizedBox(height: 60),
                Spacer(flex: 2),
                Column(
                  children: [
                    Icon(
                      Icons.settings,
                      size: 80,
                      color: accentGemini,
                    ),
                    SizedBox(height: 48),
                    Text(
                      'METRICS',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF222222),
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 32),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'We need your wheel specifications for accurate calculations.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 18,
                          fontWeight: FontWeight.w400,
                          height: 1.6,
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'This includes wheel size, tire width, and your preferred units for speed, distance, and pressure.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                Spacer(flex: 3),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.keyboard_arrow_left,
                      color: accentGemini,
                      size: 28,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'SWIPE LEFT TO CONTINUE',
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
                SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
