import 'package:flutter/material.dart';
import 'coast_down_instructions.dart';

class ProtocolSelectionPage extends StatelessWidget {
  const ProtocolSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Select Protocol"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
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
                  () => print("Constant Power selected"),
                ),
                _protocolCard(
                  cardHeight,
                  "Lap Efficiency (Chung)",
                  "Action: Closed GPS loop.\nRequirement: At least 3 laps per pressure.\nData: Avg Power vs. Avg Speed.",
                  Icons.loop,
                  Colors.purple,
                  () => print("Lap Efficiency selected"),
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
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Colors.grey.shade300, width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: color.withOpacity(0.1),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topLeft,
                    child: Text(
                      desc,
                      style: const TextStyle(height: 1.4, color: Colors.black87, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} // <--- This brace closes the ProtocolSelectionPage class.