import 'package:flutter/material.dart';
import 'pressure_input_page.dart'; // We will create this next
import 'ui/common_widgets.dart';

class CoastDownInstructions extends StatefulWidget {
  const CoastDownInstructions({super.key});

  @override
  State<CoastDownInstructions> createState() => _CoastDownInstructionsState();
}

class _CoastDownInstructionsState extends State<CoastDownInstructions> {
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
          'COAST-DOWN RULES',
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
                builder: (context) => const PressureInputPage(protocol: 'coast_down'),
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
                        _instructionStep("1", "Find a hill without traffic and a safe run-out."),
                        _instructionStep("2", "Avoid the steepest hill; choose a slope with a safe top speed."),
                        _instructionStep("3", "Pick a Top Anchor (starting line). Use this exact spot for every run."),
                        _instructionStep("4", "No pedaling or braking until the run is complete."),
                        _instructionStep("4a", "Choose a descent that naturally rolls out — no brakes needed to stop."),
                        _instructionStep("5", "Power consistency is not required. Coast only."),
                        _instructionStep("6", "Keep your body position exactly the same every time."),
                        _instructionStep("7", "For accurate vibration data, mount the phone on the bars. Pocket placement reduces vibration accuracy but does not affect efficiency."),
                        _instructionStep("8", "Start Run 1 at HIGHEST recommended pressure (sidewall/rim max)."),
                        _instructionStep("9", "Start Run 2 at MINIMUM recommended pressure (sidewall min)."),
                        _instructionStep("10", "Start Run 3 at the MIDDLE point between Max and Min."),
                        _instructionStep("11", "At least 3 runs required. More runs = better accuracy."),
                        _instructionStep("12", "BE CAREFUL. Safety is the priority. Abort if unstable."),
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
                                builder: (context) => const PressureInputPage(protocol: 'coast_down'),
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