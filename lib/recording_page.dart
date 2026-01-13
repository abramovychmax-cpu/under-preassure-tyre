// we are importing the asynchronous tools, flutter material library, and our custom bluetooth service from the local files
import 'dart:async';
import 'package:flutter/material.dart';
import 'sensor_service.dart';

// we are defining the RecordingPage class which is a StatefulWidget used to display real-time sensor data during a test run
class RecordingPage extends StatefulWidget {
  final double frontPressure;
  final double rearPressure;

  const RecordingPage({
    super.key,
    required this.frontPressure,
    required this.rearPressure,
  });

  @override
  State<RecordingPage> createState() => _RecordingPageState();
}

// we are defining the _RecordingPageState class which handles the logic, sensor subscriptions, and UI building for the recording screen
class _RecordingPageState extends State<RecordingPage> {
  final SensorService _sensorService = SensorService();
  double currentSpeed = 0.0;
  double currentDistance = 0.0;
  int currentPower = 0;
  int currentCadence = 0;
  StreamSubscription? _speedSub;
  StreamSubscription? _distSub;


  @override
  void initState() {
    super.initState();
    
    // 1. Reset distance to 0 for the start of this specific protocol run
    _sensorService.resetDistance();

    // 2. Start the sensors
    _sensorService.loadSavedSensors();

    // 3. Listen for Distance updates
    _distSub = _sensorService.distanceStream.listen((dist) {
      if (mounted) {
        setState(() {
          currentDistance = dist;
        });
      }
    });

    // 4. Listen for Speed updates (Now safely inside the function)
    _speedSub = _sensorService.speedStream.listen((speed) {
      if (mounted) {
        setState(() => currentSpeed = speed);
      }
    });
  }

  @override
  void dispose() {
    _distSub?.cancel(); 
    _speedSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2), 
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Text(
              "RECORDING RUN", 
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.1),
            ),
            Text(
              "LAP METADATA: ${widget.frontPressure}/${widget.rearPressure} PSI",
              style: TextStyle(fontSize: 14, color: Colors.black.withOpacity(0.4), fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 30),
            
            // Grid of Data Cards
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _buildDataRow("SPEED", "${currentSpeed.toStringAsFixed(1)}", "km/h", "POWER", "$currentPower", "watts"),
                    _buildDataRow("CADENCE", "$currentCadence", "RPM", "vibrations", "0.00", "g"),
                    _buildDataRow("DISTANCE", "${currentDistance.toStringAsFixed(2)}", "km", "TIME LAPSED", "00:00:00", "_"),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),
            
        

            // 2. THE FINISH BUTTON (Important for your protocol!)
            TextButton(
              onPressed: () {
                // This tells the app: "The run is over, go back and save it"
                Navigator.pop(context, true);
              },
              child: const Text(
                "FINISH RUN",
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(height: 20),
          ], // End of Column children
        ),
      ),    
    );
  }


  // we are defining a helper method to create a row containing two data cards
  Widget _buildDataRow(String label1, String val1, String unit1, String label2, String val2, String unit2) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(child: _buildCard(label1, val1, unit1)),
            const SizedBox(width: 20),
            Expanded(child: _buildCard(label2, val2, unit2)),
          ],
        ),
      ),
    );
  }

  // we are defining a helper method to build the individual styled data cards with shadows and labels
  Widget _buildCard(String label, String value, String unit) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE0E0E0), 
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.5), fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          // FIX: Wrap the large text in FittedBox to prevent the 13px overflow
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D))),
          ),
          Text(unit, style: TextStyle(fontSize: 14, color: Colors.black.withOpacity(0.4))),
        ],
      ),
    );
  }
}