import 'package:flutter/material.dart';
import 'pressure_input_page.dart';
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
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! < -200) {
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
                    _instructionStep('1', 'Use an out-and-back or circle route with straight lines.'),
                    _instructionStep('2', 'Hold steady power on straights.'),
                    _instructionStep('3', 'Hold steady power each run (aim within ±15W). Avoid surges.'),
                    _instructionStep('4', 'Avoid drafting and traffic interruptions.'),
                    _instructionStep('5', 'Only repeatable segments with similar power (±10%) are used in analysis.'),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.keyboard_arrow_left, color: accentGemini, size: 28),
                  SizedBox(height: 4),
                  Text(
                    'SWIPE TO CONTINUE',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: accentGemini, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _instructionStep(String leading, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: accentGemini,
            child: Text(leading, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, height: 1.45, color: Color(0xFF222222)),
            ),
          ),
        ],
      ),
    );
  }
}
