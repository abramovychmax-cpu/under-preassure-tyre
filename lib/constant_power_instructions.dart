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
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! > 500) {
            _goToPressure(context);
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
                        _instructionStep('1', 'Use an out-and-back (A-B-A) route so you can pump only at A.'),
                        _instructionStep('2', 'Pick a straight segment and use the same start/end markers each run.'),
                        _instructionStep('3', 'Hold steady power each run (aim within ±5-10W). Avoid surges.'),
                        _instructionStep('4', 'Use a power you can hold a long time (mid Zone 2).'),
                        _instructionStep('5', 'Keep cadence, gearing, and body position identical each run.'),
                        _instructionStep('6', 'Avoid drafting and traffic interruptions.'),
                        _instructionStep('7', 'Only repeatable segments with similar power (±10%) are used in analysis.'),
                        _instructionStep('8', 'For accurate vibration data, mount the phone on the bars. Pocket placement reduces vibration accuracy but does not affect efficiency.'),
                        _instructionStep('9', 'Record at least 3 runs at different pressures.'),
                        _instructionStep('10', 'If you cannot keep power steady (gravel/traffic), use Coast-Down.'),
                        _instructionStep('11', 'Start Run 1 at HIGHEST recommended pressure (sidewall/rim max).'),
                        _instructionStep('12', 'Start Run 2 at MINIMUM recommended pressure (sidewall min).'),
                        _instructionStep('13', 'Start Run 3 at the MIDDLE point between Max and Min.'),
                        const SizedBox(height: 18),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.keyboard_arrow_right,
                      color: accentGemini,
                      size: 32,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'SWIPE RIGHT TO CONTINUE',
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
