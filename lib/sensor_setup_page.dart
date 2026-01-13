import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import 'protocol_selection_page.dart';

class SensorSetupPage extends StatefulWidget {
  const SensorSetupPage({super.key});

  @override
  State<SensorSetupPage> createState() => _SensorSetupPageState();
}

class _SensorSetupPageState extends State<SensorSetupPage> {
  String speedSensorName = "Not Connected";
  String powerMeterName = "Not Connected";
  String cadenceSensorName = "Not Connected";
  
  bool gpsGranted = false;
  bool accelActive = false;
  List<ScanResult> scanResults = [];
  StreamSubscription? scanSubscription;

  @override
  void initState() {
    super.initState();
    _initInternalSensors();
  }

  Future<void> _initInternalSensors() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
      setState(() => gpsGranted = true);
    }
    accelerometerEvents.listen((event) {
      if (!accelActive && (event.x.abs() > 1.2)) {
        setState(() => accelActive = true);
      }
    });
  }

  // --- RECOVERY SCAN LOGIC ---
  void _startSensorScan(String targetSlot) async {
    // 1. Force a "Hardware Reset"
    await FlutterBluePlus.stopScan();
    await scanSubscription?.cancel();
    
    setState(() => scanResults.clear());
    _showDevicePicker(targetSlot);

    // 2. The "Samsung A20 Cooling Period"
    await Future.delayed(const Duration(milliseconds: 800));

    try {
      // 3. Scan for ALL relevant cycling services at once
      await FlutterBluePlus.startScan(
        withServices: [Guid("1816"), Guid("1818")], 
        timeout: const Duration(seconds: 20),
        androidUsesFineLocation: true,
        androidScanMode: AndroidScanMode.lowLatency,
      );

      scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
        if (mounted) {
          setState(() {
            // Keep named devices that match our cycling sensor profile
            scanResults = results.where((r) => r.advertisementData.localName.isNotEmpty).toList();
          });
        }
      });
    } catch (e) {
      debugPrint("Scan Error: $e");
    }
  }

  void _showDevicePicker(String targetSlot) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
    builder: (context) {
      return Container(
        padding: const EdgeInsets.all(24),
        height: 500,
        child: Column(
          children: [
            Text("Select $targetSlot Sensor", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
            const SizedBox(height: 16),
            Expanded(
              // STREAMBUILDER: This updates the UI automatically as results come in
              child: StreamBuilder<List<ScanResult>>(
                stream: FlutterBluePlus.onScanResults,
                initialData: const [],
                builder: (context, snapshot) {
                  final results = snapshot.data ?? [];
                  // Filter for named devices only
                  final filtered = results.where((r) => r.advertisementData.localName.isNotEmpty).toList();

                  if (filtered.isEmpty) {
                    return const Center(child: Text("Searching...\nSpin your wheels or cranks!", textAlign: TextAlign.center));
                  }

                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final data = filtered[index];
                      final name = data.advertisementData.localName;
                      return ListTile(
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(data.device.remoteId.toString()),
                        leading: const CircleAvatar(child: Icon(Icons.bluetooth)),
                        onTap: () async {
                          await FlutterBluePlus.stopScan();
                          setState(() {
                            if (targetSlot == "speed") speedSensorName = name;
                            if (targetSlot == "power") powerMeterName = name;
                            if (targetSlot == "cadence") cadenceSensorName = name;
                          });
                          Navigator.pop(context);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  ).then((_) => FlutterBluePlus.stopScan());
}

  Widget sensorWindow(String title, String subtitle, bool isActive, IconData icon, VoidCallback? onConnect) {
  // Define colors locally for the Dark Aesthetic
  const Color cardDark = Color(0xFF1E2228); 
  const Color geminiTeal = Color(0xFF47D1C1);
  const Color borderGrey = Color(0xFF2C3138);

  return Card(
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 12),
    // 1. Change card background to Deep Charcoal
    color: cardDark, 
    shape: RoundedRectangleBorder(
      // 2. Frame color: Teal if active, subtle Grey if not
      side: BorderSide(
        color: isActive ? geminiTeal : borderGrey, 
        width: 1.5,
      ),
      borderRadius: BorderRadius.circular(16),
    ),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      // 3. Icon color: Teal if active, muted Grey if not
      leading: Icon(icon, color: isActive ? geminiTeal : Colors.grey, size: 30),
      // 4. Title color: Pure White
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
      // 5. Subtitle color: Muted Grey
      subtitle: Text(subtitle, style: TextStyle(color: isActive ? geminiTeal.withOpacity(0.7) : Colors.grey)),
      trailing: onConnect != null 
        ? IconButton(
            icon: Icon(Icons.add_link, color: geminiTeal, size: 30), 
            onPressed: onConnect
          )
        : (isActive ? const Icon(Icons.check_circle, color: geminiTeal) : null),
    ),
  );
}

  @override
Widget build(BuildContext context) {
  // Define our Gemini Dark Palette
  const Color bgDark = Color(0xFF121418);
  const Color geminiTeal = Color(0xFF47D1C1);

  return Scaffold(
    backgroundColor: bgDark, // Changed from Colors.white
    appBar: AppBar(
      backgroundColor: bgDark, 
      elevation: 0, 
      title: const Text("Sensor Setup", style: TextStyle(color: Colors.white)), 
      centerTitle: true
    ),
    body: Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          sensorWindow("GPS Status", gpsGranted ? "Locked" : "Waiting for GPS...", gpsGranted, Icons.gps_fixed, null),
          sensorWindow("Phone Vibration", accelActive ? "Ready" : "Shake phone to test", accelActive, Icons.sensors, null),
          
          // REMOVED THE DIVIDER - Using space instead for "Symmetrical Guttering"
          const SizedBox(height: 24), 
          
          sensorWindow("Speed Sensor", speedSensorName, speedSensorName != "Not Connected", Icons.speed, () => _startSensorScan("speed")),
          sensorWindow("Power Meter", powerMeterName, powerMeterName != "Not Connected", Icons.bolt, () => _startSensorScan("power")),
          sensorWindow("Cadence", cadenceSensorName, cadenceSensorName != "Not Connected", Icons.loop, () => _startSensorScan("cadence")),
          
          const Spacer(),
          
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: (speedSensorName != "Not Connected" && gpsGranted) 
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ProtocolSelectionPage()),
                    );
                  } 
                : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: geminiTeal, // The "Action" color from design
                foregroundColor: bgDark,    // Dark text on bright button
                disabledBackgroundColor: Colors.grey.shade800,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), // Rounded iOS style
              ),
              child: const Text("SELECT TESTING PROTOCOL", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    ),
  );
}
}