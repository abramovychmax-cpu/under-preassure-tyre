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
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: isActive ? Colors.blue.withOpacity(0.05) : Colors.white,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: isActive ? Colors.blue : Colors.grey.shade300, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Icon(icon, color: isActive ? Colors.blue : Colors.grey, size: 30),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(subtitle),
        trailing: onConnect != null 
          ? IconButton(icon: const Icon(Icons.add_link, color: Colors.blue, size: 30), onPressed: onConnect)
          : (isActive ? const Icon(Icons.check_circle, color: Colors.green) : null),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Sensor Setup"), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            sensorWindow("GPS Status", gpsGranted ? "Locked" : "Waiting for GPS...", gpsGranted, Icons.gps_fixed, null),
            sensorWindow("Phone Vibration", accelActive ? "Ready" : "Shake phone to test", accelActive, Icons.sensors, null),
            const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
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
      backgroundColor: const Color.fromARGB(255, 253, 236, 2),
      foregroundColor: const Color.fromARGB(255, 20, 46, 197),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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