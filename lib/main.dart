import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: SensorScanner(),
  ));
}

class SensorScanner extends StatefulWidget {
  const SensorScanner({super.key});

  @override
  State<SensorScanner> createState() => _SensorScannerState();
}

class _SensorScannerState extends State<SensorScanner> {
  List<ScanResult> scanResults = [];
  bool isScanning = false;
  
  // Speed Calculation Variables
  double currentSpeed = 0.0;
  int? lastWheelRevs;
  int? lastWheelTime;
  String connectionStatus = "Not Connected";

  // 700c tire circumference is roughly 2.1 meters
  final double wheelCircumference = 2.1; 

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      setState(() => connectionStatus = "Connecting...");
      await device.connect();
      setState(() => connectionStatus = "Connected to ${device.platformName}");

      List<BluetoothService> services = await device.discoverServices();

      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase().contains("1816")) {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase().contains("2a5b")) {
              
              await characteristic.setNotifyValue(true);

              characteristic.lastValueStream.listen((value) {
                if (value.isNotEmpty && value.length >= 7) {
                  // 1. Parse Cumulative Wheel Revolutions (Bytes 1-4)
                  int currentRevs = (value[1]) | (value[2] << 8) | (value[3] << 16) | (value[4] << 24);
                  
                  // 2. Parse Last Wheel Event Time (Bytes 5-6)
                  // This is in 1/1024 second units
                  int currentTime = (value[5]) | (value[6] << 8);

                  if (lastWheelRevs != null && lastWheelTime != null) {
                    // Calculate differences
                    int revDiff = currentRevs - lastWheelRevs!;
                    int timeDiff = currentTime - lastWheelTime!;

                    // Handle the timer wrapping around (it resets at 65535)
                    if (timeDiff < 0) timeDiff += 65536;

                    if (timeDiff > 0 && revDiff > 0) {
                      // Speed in m/s = (Revolutions * Circumference) / (Time / 1024)
                      double speedMPS = (revDiff * wheelCircumference) / (timeDiff / 1024.0);
                      
                      // Convert m/s to km/h (Multiply by 3.6)
                      setState(() {
                        currentSpeed = speedMPS * 3.6;
                      });
                    }
                  }

                  lastWheelRevs = currentRevs;
                  lastWheelTime = currentTime;
                  
                  print("Speed: ${currentSpeed.toStringAsFixed(1)} km/h");
                }
              });
            }
          }
        }
      }
    } catch (e) {
      print("Connection Error: $e");
      setState(() => connectionStatus = "Connection Failed");
    }
  }

  Future<void> startScan() async {
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) return;
    bool isLocationOn = await Permission.locationWhenInUse.serviceStatus.isEnabled;
    if (!isLocationOn) { await openAppSettings(); return; }
    await [Permission.location, Permission.bluetoothScan, Permission.bluetoothConnect].request();

    setState(() { isScanning = true; scanResults = []; });
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
      FlutterBluePlus.scanResults.listen((results) {
        if (mounted) setState(() => scanResults = results);
      });
      await Future.delayed(const Duration(seconds: 15));
      if (mounted) setState(() => isScanning = false);
    } catch (e) { if (mounted) setState(() => isScanning = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tire Lab: Speedometer"),
        backgroundColor: const Color.fromARGB(255, 194, 34, 167),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(30),
            color: Colors.grey[900],
            child: Column(
              children: [
                Text(connectionStatus, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 20),
                Text(
                  currentSpeed.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 80, fontWeight: FontWeight.bold, color: Colors.greenAccent),
                ),
                const Text("KM/H", style: TextStyle(color: Colors.greenAccent, fontSize: 20, letterSpacing: 2)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            icon: const Icon(Icons.search),
            onPressed: isScanning ? null : startScan,
            label: Text(isScanning ? "Searching..." : "SCAN FOR SENSORS"),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: scanResults.length,
              itemBuilder: (context, index) {
                final device = scanResults[index].device;
                return ListTile(
                  leading: const Icon(Icons.directions_bike),
                  title: Text(device.platformName.isEmpty ? "Unknown Sensor" : device.platformName),
                  subtitle: Text(device.remoteId.toString()),
                  onTap: () => _connectToDevice(device),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}