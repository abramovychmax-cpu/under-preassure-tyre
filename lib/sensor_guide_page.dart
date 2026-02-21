import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sensor_setup_page.dart';
import 'ui/app_menu_button.dart';
import 'ui/common_widgets.dart';

class SensorGuidePage extends StatefulWidget {
  const SensorGuidePage({super.key});

  @override
  State<SensorGuidePage> createState() => _SensorGuidePageState();
}

class _SensorGuidePageState extends State<SensorGuidePage> {
  bool _firstVisit = false;

  @override
  void initState() {
    super.initState();
    _checkFirstVisit();
  }

  Future<void> _checkFirstVisit() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('sensor_guide_seen') ?? false;
    if (!seen) {
      await prefs.setBool('sensor_guide_seen', true);
      if (mounted) setState(() => _firstVisit = true);
    }
  }

  void _navigateToSetup(BuildContext context) {
    setState(() => _firstVisit = false);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SensorSetupPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      body: RightEdgeSwipeDetector(
        onSwipeForward: () => _navigateToSetup(context),
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
                        Icons.sensors,
                        size: 80,
                        color: accentGemini,
                      ),
                    ),
                    SizedBox(height: 48),
                    Text(
                      'SENSOR SETUP',
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
                        'Please prepare to connect all needed sensors to run tests.',
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
                        'Activate your Bluetooth sensors and keep them nearby.',
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
                  onForward: () => _navigateToSetup(context),
                  forwardHighlighted: _firstVisit,
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
