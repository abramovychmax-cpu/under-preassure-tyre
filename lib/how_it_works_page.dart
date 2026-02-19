import 'package:flutter/material.dart';
import 'sensor_guide_page.dart';
import 'ui/common_widgets.dart';

class HowItWorksPage extends StatelessWidget {
  const HowItWorksPage({super.key});

  void _navigateNext(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SensorGuidePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! < -200) {
            _navigateNext(context);
          }
        },
        child: const SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 40),
                Spacer(flex: 1),

                // Icon
                Icon(
                  Icons.route_rounded,
                  size: 72,
                  color: accentGemini,
                ),
                SizedBox(height: 40),

                // Headline
                Text(
                  'HOW IT WORKS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF222222),
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(height: 32),

                // Steps
                _StepRow(
                  number: '1',
                  title: 'Choose a protocol',
                  body: 'Coast-Down, Constant Power, or Lap Efficiency — pick the one that suits your terrain.',
                ),
                SizedBox(height: 20),
                _StepRow(
                  number: '2',
                  title: 'Perform 3+ runs',
                  body: 'Each run uses a different tire pressure. Minimum three runs are required to calculate an optimum.',
                ),
                SizedBox(height: 20),
                _StepRow(
                  number: '3',
                  title: 'Get your perfect pressure',
                  body: 'The app fits a curve to your results and finds the pressure where rolling resistance is lowest.',
                ),

                Spacer(flex: 2),

                // Setup notice
                _SetupNotice(),

                SizedBox(height: 28),

                // Swipe indicator
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.keyboard_arrow_left, color: accentGemini, size: 28),
                      SizedBox(height: 4),
                      Text(
                        'SWIPE TO CONTINUE',
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
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String number;
  final String title;
  final String body;

  const _StepRow({
    required this.number,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Numbered circle
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: accentGemini,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF222222),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: const TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SetupNotice extends StatelessWidget {
  const _SetupNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: accentGemini.withAlpha((0.08 * 255).round()),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentGemini, width: 1.2),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.settings_outlined, color: accentGemini, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Before your first run we\'ll set up your bike, wheel size, and sensors. This only takes a minute.',
              style: TextStyle(
                color: Color(0xFF444444),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
