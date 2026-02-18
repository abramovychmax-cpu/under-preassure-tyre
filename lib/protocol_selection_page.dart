import 'package:flutter/material.dart';
import 'coast_down_instructions.dart';
import 'constant_power_instructions.dart';
import 'lap_efficiency_instructions.dart';
import 'safety_guide_page.dart';
import 'ui/common_widgets.dart';

class ProtocolSelectionPage extends StatelessWidget {
  const ProtocolSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        automaticallyImplyLeading: false,
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
          final totalAvailableHeight = constraints.maxHeight - 64;
          final cardHeight = (totalAvailableHeight - 80) / 3; // Reduced from totalAvailableHeight / 3

          return ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _protocolCard(
                cardHeight,
                'Coast-Down (Gravity)',
                'Action: Coast hill; no pedaling.\nRequirement: At least 3 runs.\nNote: No Power Meter required.',
                Icons.terrain,
                Colors.green,
                'No Power Meter',
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CoastDownInstructions()),
                  );
                },
              ),
              _protocolCard(
                cardHeight,
                'Constant Power / Speed',
                'Action: Flat road; steady effort.\nRequirement: At least 3 runs.\nData: Speed vs. Wattage efficiency.',
                Icons.bolt,
                Colors.blue,
                'Power Meter required',
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ConstantPowerInstructions()),
                  );
                },
              ),
              _protocolCard(
                cardHeight,
                'Lap Efficiency (Chung)',
                'Action: Closed GPS loop.\nRequirement: At least 3 laps per pressure.\nData: Avg Power vs. Avg Speed.',
                Icons.loop,
                Colors.purple,
                'Power Meter required',
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LapEfficiencyInstructions()),
                  );
                },
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentGemini,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SafetyGuidePage()),
                  );
                },
                child: const Text('VIEW SAFETY GUIDE'),
              ),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }

  Widget _protocolCard(double height, String title, String desc, IconData icon, MaterialColor color, String pillLabel, VoidCallback onTap) {
    final List<Widget> descWidgets = desc.split('\n').map((line) {
      final splitIdx = line.indexOf(':');
      if (splitIdx > 0) {
        final key = line.substring(0, splitIdx + 1);
        final val = line.substring(splitIdx + 1);
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text.rich(
            TextSpan(
              style: const TextStyle(height: 1.4, color: Color(0xFF666666), fontSize: 14),
              children: [
                TextSpan(text: key, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF222222))),
                TextSpan(text: val),
              ],
            ),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(line, style: const TextStyle(height: 1.4, color: Color(0xFF666666), fontSize: 14)),
      );
    }).toList();

    return Container(
      height: height - 16,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.10),
            Colors.white,
          ],
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.12),
                    radius: 20,
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.left,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF222222)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  pillLabel,
                  style: TextStyle(
                    color: color.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...descWidgets,
            ],
          ),
        ),
      ),
    );
  }
}