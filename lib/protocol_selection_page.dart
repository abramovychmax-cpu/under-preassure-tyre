import 'package:flutter/material.dart';
import 'coast_down_instructions.dart';
import 'constant_power_instructions.dart';
import 'lap_efficiency_instructions.dart';
import 'ui/common_widgets.dart';

class ProtocolSelectionPage extends StatelessWidget {
  const ProtocolSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        title: const Text(
          'SELECT PROTOCOL',
          style: TextStyle(color: Color(0xFF222222), fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: bgLight,
        foregroundColor: const Color(0xFF222222),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          double totalAvailableHeight = constraints.maxHeight - 64;
          double cardHeight = totalAvailableHeight / 3;

          return Center(
            child: ListView(
              shrinkWrap: true, 
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _protocolCard(
                  cardHeight,
                  "Coast-Down (Gravity)",
                  "Action: Coast hill; no pedaling.\nRequirement: At least 3 runs.\nNote: No Power Meter required.",
                  Icons.terrain,
                  Colors.green,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CoastDownInstructions()),
                    );
                  },
                ),
                _protocolCard(
                  cardHeight,
                  "Constant Power / Speed",
                  "Action: Flat road; steady effort.\nRequirement: At least 3 runs.\nData: Speed vs. Wattage efficiency.",
                  Icons.bolt,
                  Colors.blue,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ConstantPowerInstructions()),
                    );
                  },
                ),
                _protocolCard(
                  cardHeight,
                  "Lap Efficiency (Chung)",
                  "Action: Closed GPS loop.\nRequirement: At least 3 laps per pressure.\nData: Avg Power vs. Avg Speed.",
                  Icons.loop,
                  Colors.purple,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LapEfficiencyInstructions()),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _protocolCard(double height, String title, String desc, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      height: height - 16,
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AppCard(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withOpacity(0.08),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF222222)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(desc, style: const TextStyle(height: 1.4, color: Color(0xFF888888), fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }
} // <--- This brace closes the ProtocolSelectionPage class.