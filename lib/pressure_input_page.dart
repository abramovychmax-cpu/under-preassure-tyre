import 'package:flutter/material.dart';
import 'recording_page.dart'; // <--- IF THIS IS MISSING, YOU GET THE UNDEFINED_METHOD ERROR

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
  // Controllers for PSI input
  final TextEditingController _frontController = TextEditingController(text: "60.0");
  final TextEditingController _rearController = TextEditingController(text: "60.0");

  int completedRuns = 0;

  // Gemini Dark Palette
  static const Color bgDark = Color(0xFF121418);
  static const Color cardGrey = Color(0xFF1E2228);
  static const Color geminiTeal = Color(0xFF47D1C1);

  @override
  void dispose() {
    _frontController.dispose();
    _rearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: bgDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("PRESSURE INPUT", 
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("RUN #${completedRuns + 1}", 
                  style: const TextStyle(color: geminiTeal, fontWeight: FontWeight.w800, fontSize: 22)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: geminiTeal.withAlpha((0.1 * 255).round()),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text("$completedRuns/3 DONE", 
                    style: const TextStyle(color: geminiTeal, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 40),
            Row(
              children: [
                Expanded(child: _buildPressureField("FRONT PSI", _frontController)),
                const SizedBox(width: 16),
                Expanded(child: _buildPressureField("REAR PSI", _rearController)),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: geminiTeal,
                  foregroundColor: bgDark,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () async {
                  // This is line 86/87 where your error was
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
                    setState(() => completedRuns++);
                  }
                },
                child: const Text("START RUN", 
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
              ),
            ),
            if (completedRuns >= 3) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: geminiTeal, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => print("Calculating..."),
                  child: const Text("FINISH AND CALCULATE", 
                    style: TextStyle(color: geminiTeal, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPressureField(String label, TextEditingController controller) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardGrey,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: geminiTeal, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
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