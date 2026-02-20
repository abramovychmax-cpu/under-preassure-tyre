import 'package:flutter/material.dart';
import 'sensor_service.dart';
import 'pressure_input_page.dart';
import 'ui/app_menu_button.dart';
import 'ui/common_widgets.dart';

class ConstantPowerInstructions extends StatefulWidget {
  const ConstantPowerInstructions({super.key});

  @override
  State<ConstantPowerInstructions> createState() => _ConstantPowerInstructionsState();
}

class _ConstantPowerInstructionsState extends State<ConstantPowerInstructions> {
  void _goToPressure(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PressureInputPage(protocol: 'constant_power')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'CONSTANT POWER RULES',
          style: TextStyle(color: Color(0xFF222222), fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16),
        ),
        centerTitle: true,
        backgroundColor: bgLight,
        foregroundColor: const Color(0xFF222222),
        elevation: 0,
        actions: const [AppMenuButton()],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! < -200 && !SensorService().isSessionActive) {
            _goToPressure(context);
          }
        },
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
                      'Follow these rules for every constant-power run.',
                      style: TextStyle(fontSize: 16, color: Color(0xFF666666), height: 1.4),
                    ),
                    const SizedBox(height: 32),
                    _sectionHeader('Route'),
                    _bulletPoint('Use an out-and-back or circle route with straight lines, run it at least three times, each on different pressure.'),
                    _bulletPoint('Avoid drafting and traffic interruptions.'),
                    const SizedBox(height: 24),
                    _sectionHeader('Power'),
                    _bulletPoint('Hold steady power on straights.'),
                    _bulletPoint('Hold steady power each run (aim within ±15W). Avoid surges.'),
                    _bulletPoint('Only repeatable segments with similar power (±10%) are used in analysis.'),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            const Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.keyboard_arrow_left, color: accentGemini, size: 20),
                  SizedBox(width: 6),
                  Text(
                    'SWIPE TO CONTINUE',
                    style: TextStyle(color: accentGemini, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.1),
                  ),
                ],
              ),
            ),
            const SafeArea(top: false, child: SizedBox(height: 16)),
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
