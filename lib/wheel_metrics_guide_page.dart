import 'package:flutter/material.dart';
import 'sensor_service.dart';
import 'wheel_metrics_page.dart';
import 'ui/app_menu_button.dart';
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
      body: AppMenuOverlay(
        child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! < -200 && !SensorService().isSessionActive) {
            _navigateToMetrics(context);
          }
        },
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const SizedBox(height: 60),
                const Spacer(flex: 2),
                const Column(
                  children: [
                    Hero(
                      tag: 'onboarding_icon',
                      child: Icon(
                        Icons.settings,
                        size: 80,
                        color: accentGemini,
                      ),
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
                        'We need some more information for accurate calculations.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 16,
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
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(flex: 3),
                OnboardingNavBar(
                  onBack: () => Navigator.pop(context),
                  onForward: () => _navigateToMetrics(context),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}
