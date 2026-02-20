import 'package:flutter/material.dart';
import 'sensor_service.dart';
import 'sensor_guide_page.dart';
import 'ui/app_menu_button.dart';
import 'ui/common_widgets.dart';

class HowItWorksPage extends StatelessWidget {
  const HowItWorksPage({super.key});

  void _navigateNext(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SensorGuidePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'HOW IT WORKS',
          style: TextStyle(color: Color(0xFF222222), fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16),
        ),
        centerTitle: true,
        backgroundColor: bgLight,
        foregroundColor: const Color(0xFF222222),
        elevation: 0,
        actions: const [AppMenuButton()],
      ),
      body: RightEdgeSwipeDetector(
        onSwipeForward: () => _navigateNext(context),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Hero(
                      tag: 'onboarding_icon',
                      child: Icon(Icons.lightbulb_outline, size: 56, color: accentGemini),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'To find your fastest pressure, perform at least three runs with selected protocol at different pressures and let the app calculate the optimum.',
                      style: TextStyle(fontSize: 16, color: Color(0xFF666666), height: 1.5),
                    ),
                    const SizedBox(height: 32),
                    _sectionHeader('Step 1 — Choose a protocol'),
                    const SizedBox(height: 24),
                    _sectionHeader('Step 2 — Perform 3+ runs'),
                    const SizedBox(height: 24),
                    _sectionHeader('Step 3 — Get your optimal pressure'),
                    const SizedBox(height: 24),
                    _sectionHeader('Before you start'),
                    _bulletPoint('Pair your speed and power sensors.'),
                    _bulletPoint('Set up your metrics.'),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            OnboardingNavBar(
              onBack: () => Navigator.pop(context),
              onForward: () => _navigateNext(context),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: Color(0xFF222222),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  static Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6.0, right: 10.0),
            child: Icon(Icons.fiber_manual_record, size: 8, color: accentGemini),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF333333)),
            ),
          ),
        ],
      ),
    );
  }
}


