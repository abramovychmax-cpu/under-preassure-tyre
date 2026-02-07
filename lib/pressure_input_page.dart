import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'recording_page.dart';
import 'ui/common_widgets.dart';

class PressureInputPage extends StatefulWidget {
  final String protocol; // 'constant_power', 'lap_efficiency', or 'coast_down'
  
  const PressureInputPage({
    super.key,
    this.protocol = 'coast_down',
  });

  @override
  State<PressureInputPage> createState() => _PressureInputPageState();
}

class _PressureInputPageState extends State<PressureInputPage> {
  // Controllers for pressure input
  final TextEditingController _frontController = TextEditingController(text: "60.0");
  final TextEditingController _rearController = TextEditingController(text: "60.0");

  int completedRuns = 0;
  String _pressureUnit = 'PSI';
  final List<Map<String, double>> _previousPressures = []; // Store previous run pressures

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pressureUnit = prefs.getString('pressure_unit') ?? 'PSI';
    });
  }

  @override
  void dispose() {
    _frontController.dispose();
    _rearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        backgroundColor: bgLight,
        elevation: 0,
        title: const Text(
          "PRESSURE INPUT", 
          style: TextStyle(color: Color(0xFF222222), fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16)
        ),
        centerTitle: true,
        foregroundColor: const Color(0xFF222222),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "RUN #${completedRuns + 1}", 
                  style: const TextStyle(color: accentGemini, fontWeight: FontWeight.w900, fontSize: 24)
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: accentGemini.withAlpha((0.1 * 255).round()),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accentGemini, width: 1.5),
                  ),
                  child: Text(
                    "$completedRuns/3 DONE", 
                    style: const TextStyle(color: accentGemini, fontSize: 12, fontWeight: FontWeight.bold)
                  ),
                ),
              ],
            ),
            
            // Show previous run pressures if any
            if (_previousPressures.isNotEmpty) ...[
              const SizedBox(height: 20),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Previous Runs',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF666666)),
                    ),
                    const SizedBox(height: 8),
                    ..._previousPressures.asMap().entries.map((entry) {
                      int idx = entry.key;
                      Map<String, double> pressure = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          'Run ${idx + 1}: Front ${pressure['front']!.toStringAsFixed(1)} $_pressureUnit  |  Rear ${pressure['rear']!.toStringAsFixed(1)} $_pressureUnit',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(child: _buildPressureField("FRONT $_pressureUnit", _frontController)),
                const SizedBox(width: 16),
                Expanded(child: _buildPressureField("REAR $_pressureUnit", _rearController)),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentGemini,
                  foregroundColor: bgLight,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RecordingPage(
                        frontPressure: double.tryParse(_frontController.text) ?? 0.0,
                        rearPressure: double.tryParse(_rearController.text) ?? 0.0,
                      ),
                    ),
                  );

                  if (result == true) {
                    setState(() {
                      // Store current run pressure
                      _previousPressures.add({
                        'front': double.tryParse(_frontController.text) ?? 0.0,
                        'rear': double.tryParse(_rearController.text) ?? 0.0,
                      });
                      completedRuns++;
                    });
                  }
                },
                child: const Text(
                  "START RUN", 
                  style: TextStyle(fontWeight: FontWeight.bold)
                ),
              ),
            ),
            if (completedRuns >= 3) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: accentGemini, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: () => print("Calculating..."),
                  child: const Text(
                    "FINISH AND CALCULATE", 
                    style: TextStyle(color: accentGemini, fontWeight: FontWeight.bold)
                  ),
                ),
              ),
            ],
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildPressureField(String label, TextEditingController controller) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.03 * 255).round()),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label, 
            style: const TextStyle(color: accentGemini, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Color(0xFF222222), fontSize: 32, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}