import 'package:flutter/material.dart';
import 'pressure_input_page.dart';
import 'ui/common_widgets.dart';

class LapEfficiencyInstructions extends StatefulWidget {
  const LapEfficiencyInstructions({super.key});

  @override
  State<LapEfficiencyInstructions> createState() => _LapEfficiencyInstructionsState();
}

class _LapEfficiencyInstructionsState extends State<LapEfficiencyInstructions> {
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
        automaticallyImplyLeading: false,
        title: const Text(
          'LAP EFFICIENCY RULES',
          style: TextStyle(color: Color(0xFF222222), fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16),
        ),
        centerTitle: true,
        backgroundColor: bgLight,
        foregroundColor: const Color(0xFF222222),
        elevation: 0,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! < -500) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PressureInputPage(protocol: 'lap_efficiency'),
              ),
            );
          }
        },
        child: Padding(
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
                        _instructionStep("1", "Choose a closed loop with consistent surface and minimal traffic."),
                        _instructionStep("2", "Ride the same line each lap and the same direction."),
                        _instructionStep("3", "Hold steady power each lap (aim within ±5-10W). Avoid surges/coasting."),
                        _instructionStep("4", "Use a power you can hold a long time (mid Zone 2)."),
                        _instructionStep("5", "Keep cadence, gearing, and body position identical each lap."),
                        _instructionStep("6", "For accurate vibration data, mount the phone on the bars. Pocket placement reduces vibration accuracy but does not affect efficiency."),
                        _instructionStep("7", "Record at least 3 laps at different pressures (one pressure per lap)."),
                        _instructionStep("8", "If power is inconsistent, use Coast-Down instead."),
                        const SizedBox(height: 18),
                        const SizedBox(height: 12),
                        const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.keyboard_arrow_up,
                                color: accentGemini,
                                size: 28,
                              ),
                              SizedBox(height: 4),
                              Text(
                                'SWIPE UP OR TAP CONTINUE',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: accentGemini,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentGemini,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PressureInputPage(protocol: 'lap_efficiency'),
                              ),
                            );
                          },
                          child: const Text('CONTINUE'),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
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
