import 'package:flutter/material.dart';
import 'pressure_input_page.dart'; // We will create this next

class CoastDownInstructions extends StatelessWidget {
  const CoastDownInstructions({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Coast-Down Rules"),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20.0),
              children: [
                _instructionStep("1", "Find a hill without traffic and a safe run-out."),
                _instructionStep("2", "Pick a Top Anchor (starting line). Use this exact spot for every run."),
                _instructionStep("3", "No pedaling or braking until the run is complete."),
                _instructionStep("4", "Keep your body position exactly the same every time."),
                _instructionStep("5", "Start Run 1 at HIGHEST recommended pressure (sidewall/rim max)."),
                _instructionStep("6", "Start Run 2 at MINIMUM recommended pressure (sidewall min)."),
                _instructionStep("7", "Start Run 3 at the MIDDLE point between Max and Min."),
                _instructionStep("8", "At least 3 runs required. More runs = better accuracy."),
                _instructionStep("9", "BE CAREFUL. Safety is the priority. Abort if unstable."),
                const SizedBox(height: 20),
                
              ],
            ),
          ),
          // Persistent button at the bottom
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PressureInputPage()),
                  );
                },
                child: const Text(
                  "UNDERSTOOD - SETUP RUN",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _instructionStep(String leading, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: Colors.black,
            child: Text(leading, style: const TextStyle(color: Colors.white, fontSize: 14)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16, height: 1.4, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}