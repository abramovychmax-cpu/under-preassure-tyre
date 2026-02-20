import 'package:flutter/material.dart';
import 'coast_down_instructions.dart';
import 'constant_power_instructions.dart';
import 'lap_efficiency_instructions.dart';
import 'ui/app_menu_button.dart';
import 'sensor_service.dart';
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
        actions: const [AppMenuButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        children: [
              _protocolCard(
                'Coast-Down (Gravity)',
                'Action: Coast hill; no pedaling.\nRequirement: At least 3 runs.\nNote: No Power Meter required.',
                Icons.terrain,
                'No Power Meter',
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CoastDownInstructions()),
                  );
                },
              ),
              _protocolCard(
                'Constant Power / Speed',
                'Action: Flat road; steady effort.\nRequirement: At least 3 runs.\nData: Speed vs. Wattage efficiency.',
                Icons.bolt,
                'Power Meter required',
                () {
                  if (!SensorService().isPowerConnected) {
                    _showPowerMeterAlert(context);
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ConstantPowerInstructions()),
                  );
                },
              ),
              _protocolCard(
                'Lap Efficiency (Chung)',
                'Action: Closed GPS loop.\nRequirement: At least 3 laps per pressure.\nData: Avg Power vs. Avg Speed.',
                Icons.loop,
                'Power Meter required',
                () {
                  if (!SensorService().isPowerConnected) {
                    _showPowerMeterAlert(context);
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LapEfficiencyInstructions()),
                  );
                },
              ),
              const SizedBox(height: 12),
        ],
      ),
    );
  }

  void _showPowerMeterAlert(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Power Meter Required',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This protocol requires a connected power meter.\n\nPlease go back to Sensor Setup and pair your power meter, or choose the Coast-Down protocol which works without one.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: Color(0xFF47D1C1))),
          ),
        ],
      ),
    );
  }

  Widget _protocolCard(String title, String desc, IconData icon, String pillLabel, VoidCallback onTap) {
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
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder, width: 1),
        boxShadow: const [
          BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: accentGemini.withAlpha(31),
                    radius: 20,
                    child: Icon(icon, color: accentGemini, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.left,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF222222)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: accentGemini.withAlpha(31),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  pillLabel,
                  style: const TextStyle(
                    color: Color(0xFF1F9D8F),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ...descWidgets,
            ],
          ),
        ),
      ),
    );
  }
}
