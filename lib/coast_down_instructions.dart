import 'package:flutter/material.dart';
import 'sensor_service.dart';
import 'pressure_input_page.dart'; // We will create this next
import 'ui/app_menu_button.dart';
import 'ui/common_widgets.dart';

class CoastDownInstructions extends StatefulWidget {
  const CoastDownInstructions({super.key});

  @override
  State<CoastDownInstructions> createState() => _CoastDownInstructionsState();
}

class _CoastDownInstructionsState extends State<CoastDownInstructions> {
  void _goToPressure(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PressureInputPage(protocol: 'coast_down'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'COAST-DOWN RULES',
          style: TextStyle(color: Color(0xFF222222), fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16),
        ),
        centerTitle: true,
        backgroundColor: bgLight,
        foregroundColor: const Color(0xFF222222),
        elevation: 0,
        actions: const [AppMenuButton()],
      ),
      body: RightEdgeSwipeDetector(
        onSwipeForward: SensorService().isSessionActive ? null : () => _goToPressure(context),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    const Text(
                      'Select a descent of your choice and coast down at least three times, each time with a different tire pressure. No pedalling — gravity does the work.',
                      style: TextStyle(fontSize: 16, color: Color(0xFF666666), height: 1.5),
                    ),
                    const SizedBox(height: 32),
                    _sectionHeader('Route'),
                    _bulletPoint('Avoid the steepest hill; choose a slope with a safe top speed.'),
                    const SizedBox(height: 24),
                    _sectionHeader('Consistency'),
                    _bulletPoint('Start all runs from the same point.'),
                    const SizedBox(height: 24),
                    _sectionHeader('During the run'),
                    _bulletPoint('No pedaling or braking until the run is complete.'),
                    _bulletPoint('Braking = end of testing segment.'),
                    const SizedBox(height: 24),
                    _sectionHeader('Power'),
                    _bulletPoint('Power consistency is not required. Coast only.'),
                    const SizedBox(height: 24),
                    _sectionHeader('Phone'),
                    _bulletPoint('Mount your phone on the handlebar. Keeping it in a pocket changes the bike weight distribution and may affect results.'),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            OnboardingNavBar(
              onBack: () => Navigator.pop(context),
              onForward: SensorService().isSessionActive ? null : () => _goToPressure(context),
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
