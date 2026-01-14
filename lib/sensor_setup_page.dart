import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import 'sensor_service.dart';
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

  String liveCadence = "0 RPM";
  String livePower = "0 W";
  String liveSpeed = "0.0 km/h";

  bool gpsGranted = false;
  bool accelActive = false;

  StreamSubscription? _speedSub;
  StreamSubscription? _cadenceSub;
  StreamSubscription? _powerSub;
  StreamSubscription? _connectedNamesSub;

  @override
  void initState() {
    super.initState();
    _initInternalSensors();
    _initDataStreams();
    // listen for automatic discovery/connection name updates
    _connectedNamesSub = SensorService().connectedNamesStream.listen((map) {
      if (!mounted) return;
      setState(() {
        speedSensorName = map['speed'] ?? 'Not Connected';
        powerMeterName = map['power'] ?? 'Not Connected';
        cadenceSensorName = map['cadence'] ?? 'Not Connected';
      });
    });
  }

  @override
  void dispose() {
    _speedSub?.cancel();
    _cadenceSub?.cancel();
    _powerSub?.cancel();
    _connectedNamesSub?.cancel();
    super.dispose();
  }

  void _initDataStreams() {
    _speedSub = SensorService().speedStream.listen((speed) {
      if (mounted) setState(() => liveSpeed = "${speed.toStringAsFixed(1)} km/h");
    });
    _cadenceSub = SensorService().cadenceStream.listen((rpm) {
      if (mounted) setState(() => liveCadence = "$rpm RPM");
    });
    _powerSub = SensorService().powerStream.listen((watts) {
      if (mounted) setState(() => livePower = "$watts W");
    });
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

  void _startSensorScan(String targetSlot) {
    SensorService().startFilteredScan(targetSlot);
    _showDevicePicker(targetSlot);
  }

  void _showDevicePicker(String targetSlot) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121418),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          height: 500,
          child: Column(
            children: [
              Text("Select ${targetSlot.toUpperCase()} Sensor",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 8),
              const LinearProgressIndicator(backgroundColor: Color(0xFF1E2228), color: Color(0xFF47D1C1)),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<List<ScanResult>>(
                  stream: SensorService().scanResultsStream,
                  initialData: const [],
                  builder: (context, snapshot) {
                    final results = snapshot.data ?? [];

                    // CHANGE 1: Filtering the results based on the Slot
                    final filteredResults = results.where((data) {
                      final name = data.advertisementData.localName.toLowerCase();
                      final serviceUuids = data.advertisementData.serviceUuids.map((e) => e.toString().toLowerCase()).toList();

                      if (targetSlot == "cadence") {
                        // 1816 is Cycling Speed and Cadence Service
                        return serviceUuids.contains("1816") || name.contains("kickr") || name.contains("cadence");
                      }
                      if (targetSlot == "power") {
                        // 1818 is Cycling Power Service
                        return serviceUuids.contains("1818") || name.contains("kickr") || name.contains("power");
                      }
                      return true;
                    }).toList();

                    if (filteredResults.isEmpty) {
                      return const Center(child: Text("Searching for compatible sensors...", style: TextStyle(color: Colors.grey)));
                    }

                    return ListView.builder(
                      itemCount: filteredResults.length,
                      itemBuilder: (context, index) {
                        final data = filteredResults[index];
                        final name = data.advertisementData.localName.isEmpty ? "Unknown Device" : data.advertisementData.localName;

                        return ListTile(
                          leading: const Icon(Icons.bluetooth, color: Color(0xFF47D1C1)),
                          title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text(data.device.remoteId.str, style: const TextStyle(color: Colors.grey)),
                          onTap: () {
                            // CHANGE 2: Treating slots as independent connections
                            // We set the sensor for the specific slot even if the ID is already in use elsewhere
                            SensorService().setSavedSensor(targetSlot, data.device.remoteId.str);

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
    const Color cardDark = Color(0xFF1E2228);
    const Color geminiTeal = Color(0xFF47D1C1);
    const Color borderGrey = Color(0xFF2C3138);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: cardDark,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: isActive ? geminiTeal : borderGrey, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Icon(icon, color: isActive ? geminiTeal : Colors.grey, size: 30),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
        subtitle: Text(isActive ? subtitle : "Not Connected", style: TextStyle(color: isActive ? geminiTeal.withOpacity(0.9) : Colors.grey)),
        trailing: onConnect != null
            ? IconButton(icon: const Icon(Icons.add_link, color: geminiTeal, size: 30), onPressed: onConnect)
            : (isActive ? const Icon(Icons.check_circle, color: geminiTeal) : null),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color bgDark = Color(0xFF121418);
    const Color geminiTeal = Color(0xFF47D1C1);

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(backgroundColor: bgDark, elevation: 0, title: const Text("Sensor Setup")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            sensorWindow("GPS Status", gpsGranted ? "Locked" : "Waiting...", gpsGranted, Icons.gps_fixed, null),
            sensorWindow("Phone Vibration", accelActive ? "Ready" : "Shake phone", accelActive, Icons.sensors, null),
            const SizedBox(height: 24),
            sensorWindow("Speed Sensor", liveSpeed, speedSensorName != "Not Connected", Icons.speed, () => _startSensorScan("speed")),
            sensorWindow("Power Meter", livePower, powerMeterName != "Not Connected", Icons.bolt, () => _startSensorScan("power")),
            sensorWindow("Cadence", liveCadence, cadenceSensorName != "Not Connected", Icons.loop, () => _startSensorScan("cadence")),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: (speedSensorName != "Not Connected" && gpsGranted) ? () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProtocolSelectionPage())) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: geminiTeal,
                  foregroundColor: bgDark,
                  disabledBackgroundColor: Colors.grey.shade800,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text("SELECT TESTING PROTOCOL", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}