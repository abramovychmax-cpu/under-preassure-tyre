import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sensor_service.dart';
import 'wheel_metrics_page.dart';
import 'ui/app_menu_button.dart';
import 'ui/common_widgets.dart';

class WheelMetricsGuidePage extends StatefulWidget {
  const WheelMetricsGuidePage({super.key});

  @override
  State<WheelMetricsGuidePage> createState() => _WheelMetricsGuidePageState();
}

class _WheelMetricsGuidePageState extends State<WheelMetricsGuidePage> {
  @override
  void initState() {
    super.initState();
    _markSeen();
  }

  Future<void> _markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('wheel_metrics_guide_seen', true);
  }

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
      body: RightEdgeSwipeDetector(
        onSwipeForward: SensorService().isSessionActive ? null : () => _navigateToMetrics(context),
        child: AppMenuOverlay(
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
                  forwardHighlighted: true,
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
