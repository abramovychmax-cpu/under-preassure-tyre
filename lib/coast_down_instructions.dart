import 'package:flutter/material.dart';
import 'pressure_input_page.dart'; // We will create this next
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'COAST-DOWN RULES',
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      _instructionStep('1', 'Avoid the steepest hill; choose a slope with a safe top speed.'),
                      _instructionStep('2', 'Start all runs from the same point.'),
                      _instructionStep('3', 'No pedaling or braking until the run is complete.'),
                      _instructionStep('4', 'Braking = end of testing segment.'),
                      _instructionStep('5', 'Power consistency is not required. Coast only.'),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Column(
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
              const SizedBox(height: 20),
            ],
          ),
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