import 'package:flutter/material.dart';
import 'sensor_service.dart';
import 'pressure_input_page.dart';
import 'ui/app_menu_button.dart';
import 'ui/common_widgets.dart';

class SimInstructions extends StatefulWidget {
  const SimInstructions({super.key});

  @override
  State<SimInstructions> createState() => _SimInstructionsState();
}

class _SimInstructionsState extends State<SimInstructions> {
  void _goToPressure(BuildContext context) {
    SensorService().enableSimMode();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PressureInputPage(protocol: 'sim')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'SIMULATION MODE',
          style: TextStyle(color: Color(0xFF222222), fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16),
        ),
        centerTitle: true,
        backgroundColor: bgLight,
        foregroundColor: const Color(0xFF222222),
        elevation: 0,
        actions: const [AppMenuButton()],
      ),
      body: RightEdgeSwipeDetector(
        onSwipeForward: () => _goToPressure(context),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),

                    // Amber SIM badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6A817).withAlpha(30),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFE6A817), width: 1),
                      ),
                      child: const Text(
                        '● SIMULATED DATA — no sensors required',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFE6A817),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      'Fake GPS, speed, power and cadence are generated internally. Use this to test the full recording and analysis pipeline without a bike or sensors.',
                      style: TextStyle(fontSize: 16, color: Color(0xFF666666), height: 1.4),
                    ),
                    const SizedBox(height: 32),

                    _sectionHeader('Your 3-Run Script'),
                    _runRow('Run 1', '5.0 Bar', '23.8–24.5 km/h simulated'),
                    _runRow('Run 2', '3.2 Bar', '23.5–24.2 km/h simulated'),
                    _runRow('Run 3', '4.0 Bar', '26.0–26.8 km/h simulated'),
                    const SizedBox(height: 24),

                    _sectionHeader('How to run'),
                    _bulletPoint('Tap the chevron → below to continue to pressure input.'),
                    _bulletPoint('Enter the pressure shown above for each run.'),
                    _bulletPoint('Tap Start Run and wait 1 minute — the simulation runs automatically.'),
                    _bulletPoint('Tap Finish Run, then enter the next pressure.'),
                    _bulletPoint('After 3 runs, tap Analyse to see the optimal pressure result.'),
                    const SizedBox(height: 24),

                    _sectionHeader('What is being tested'),
                    _bulletPoint('Gate sweep-line detection on fake GPS coordinates.'),
                    _bulletPoint('FIT file lap messages with pressure metadata.'),
                    _bulletPoint('Quadratic regression returning an optimal ~4.1–4.2 Bar result.'),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            OnboardingNavBar(
              onBack: () => Navigator.pop(context),
              onForward: () => _goToPressure(context),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _runRow(String run, String pressure, String speed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: accentGemini.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              run,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1F9D8F)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pressure,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF222222)),
                ),
                Text(
                  speed,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
                ),
              ],
            ),
          ),
          const Text(
            '~1 min',
            style: TextStyle(fontSize: 13, color: Color(0xFF888888), fontStyle: FontStyle.italic),
          ),
        ],
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
