import 'package:flutter/material.dart';
import 'pressure_input_page.dart';
import 'ui/common_widgets.dart';

class ConstantPowerInstructions extends StatefulWidget {
  const ConstantPowerInstructions({super.key});

  @override
  State<ConstantPowerInstructions> createState() => _ConstantPowerInstructionsState();
}

class _ConstantPowerInstructionsState extends State<ConstantPowerInstructions> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        title: const Text(
          'CONSTANT POWER RULES',
          style: TextStyle(color: Color(0xFF222222), fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16),
        ),
        centerTitle: true,
        backgroundColor: bgLight,
        foregroundColor: const Color(0xFF222222),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Expanded(
              child: AppCard(
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12.0),
                    children: [
                      const SizedBox(height: 6),
                      _instructionStep("1", "Use an out-and-back (A-B-A) route so you can pump only at A."),
                      _instructionStep("2", "Pick a straight segment and use the same start/end markers each run."),
                      _instructionStep("3", "Hold steady power each run (aim within ±5-10W). Avoid surges."),
                      _instructionStep("4", "Use a power you can hold a long time (mid Zone 2)."),
                      _instructionStep("5", "Keep cadence, gearing, and body position identical each run."),
                      _instructionStep("6", "Avoid drafting and traffic interruptions."),
                      _instructionStep("7", "Only repeatable segments with similar power (±10%) are used in analysis."),
                      _instructionStep("8", "For accurate vibration data, mount the phone on the bars. Pocket placement reduces vibration accuracy but does not affect efficiency."),
                      _instructionStep("9", "Record at least 3 runs at different pressures."),
                      _instructionStep("10", "If you cannot keep power steady (gravel/traffic), use Coast-Down."),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),
            // Persistent button at the bottom
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentGemini,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PressureInputPage(protocol: 'constant_power')),
                  );
                },
                child: const Text(
                  "UNDERSTOOD - SETUP RUN",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
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
