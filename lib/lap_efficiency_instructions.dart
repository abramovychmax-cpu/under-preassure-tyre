import 'package:flutter/material.dart';
import 'pressure_input_page.dart';
import 'ui/common_widgets.dart';

class LapEfficiencyInstructions extends StatefulWidget {
  const LapEfficiencyInstructions({super.key});

  @override
  State<LapEfficiencyInstructions> createState() => _LapEfficiencyInstructionsState();
}

class _LapEfficiencyInstructionsState extends State<LapEfficiencyInstructions> {
  void _goToPressure(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PressureInputPage(protocol: 'lap_efficiency'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'LAP EFFICIENCY RULES',
          style: TextStyle(color: Color(0xFF222222), fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF222222),
        elevation: 0,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! < -500) {
            _goToPressure(context);
          }
        },
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: AppCard(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        _instructionStep('1', 'Choose a closed loop with consistent surface and minimal traffic.'),
                        _instructionStep('2', 'Ride the same line each lap and the same direction.'),
                        _instructionStep('3', 'Hold steady power each lap (aim within ±5-10W). Avoid surges/coasting.'),
                        _instructionStep('4', 'Use a power you can hold a long time (mid Zone 2).'),
                        _instructionStep('5', 'Keep cadence, gearing, and body position identical each lap.'),
                        _instructionStep('6', 'For accurate vibration data, mount the phone on the bars. Pocket placement reduces vibration accuracy but does not affect efficiency.'),
                        _instructionStep('7', 'Record at least 3 laps at different pressures (one pressure per lap).'),
                        _instructionStep('8', 'If power is inconsistent, use Coast-Down instead.'),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.keyboard_arrow_left, color: accentGemini, size: 28),
                  SizedBox(height: 4),
                  Text(
                    'SWIPE LEFT TO CONTINUE',
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
              style: const TextStyle(fontSize: 16, height: 1.45, color: Color(0xFF222222)),
            ),
          ),
        ],
      ),
    );
  }
}