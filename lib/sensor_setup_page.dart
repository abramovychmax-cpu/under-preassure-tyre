import 'package:flutter/material.dart'; 
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; 
import 'package:geolocator/geolocator.dart'; 
import 'package:sensors_plus/sensors_plus.dart'; 
import 'dart:async'; 

class SensorSetupPage extends StatefulWidget {
  const SensorSetupPage({super.key});

  @override
  State<SensorSetupPage> createState() => _SensorSetupPageState();
}

class _SensorSetupPageState extends State<SensorSetupPage> {
  // VARIABLES: "Boxes" to store sensor info
  String speedSensorName = "Not Connected"; 
  String powerMeterName = "Not Connected"; 
  String cadenceSensorName = "Not Connected"; // [NEW] Separate variable for Cadence
  
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
    accelerometerEvents.listen((AccelerometerEvent event) {
      if (!accelActive) {
        setState(() => accelActive = true); 
      }
    });
  }

  // [CHANGED] Added 'targetSlot' so the function knows which window to fill
  void _startSensorScan(String serviceUuid, String targetSlot) async {
    setState(() => scanResults.clear()); 

    // [CHANGED] Pass targetSlot to the picker
    _showDevicePicker(serviceUuid, targetSlot); 

    await FlutterBluePlus.startScan(
      withServices: [Guid(serviceUuid)], 
      timeout: const Duration(seconds: 10), 
    );

    scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      setState(() => scanResults = results); 
    });
  }

  // [CHANGED] Added 'targetSlot' to this function too
  void _showDevicePicker(String serviceId, String targetSlot) {
    showModalBottomSheet( 
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // This ensures the list updates while the menu is open
            FlutterBluePlus.scanResults.listen((results) {
              if (mounted) setModalState(() {});
            });

            return Container( 
              padding: const EdgeInsets.all(16),
              height: 400,
              child: ListView.builder( 
                itemCount: scanResults.length, 
                itemBuilder: (context, index) {
                  final data = scanResults[index]; 
                  String foundName = data.advertisementData.localName.isEmpty 
                      ? "Unknown Sensor" : data.advertisementData.localName;

                  return ListTile( 
                    title: Text(foundName),
                    onTap: () { 
                      setState(() { 
                        // [CHANGED] Logic to fill the correct box based on what '+' was clicked
                        if (targetSlot == "speed") {
                          speedSensorName = foundName;
                        } else if (targetSlot == "power") {
                          powerMeterName = foundName;
                        } else if (targetSlot == "cadence") {
                          cadenceSensorName = foundName;
                        }
                      });
                      Navigator.pop(context); 
                      FlutterBluePlus.stopScan(); 
                    },
                  );
                },
              ),
            );
          }
        );
      }
    );
  }

  // WIDGET BUILDER: Draws the windows
  Widget sensorWindow(String title, String subtitle, bool isActive, IconData icon, VoidCallback? onConnect) {
    return Card( 
      color: isActive ? Colors.green.withOpacity(0.1) : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: isActive ? Colors.green : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile( 
        leading: Icon(icon, color: isActive ? Colors.green : Colors.grey), 
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), 
        subtitle: Text(subtitle), 
        trailing: onConnect != null 
          ? IconButton(icon: const Icon(Icons.add_circle, color: Colors.blue), onPressed: onConnect) 
          : (isActive ? const Icon(Icons.check_circle, color: Colors.green) : null), 
      ),
    );
  }

  @override 
  Widget build(BuildContext context) {
    return Scaffold( 
      appBar: AppBar(title: const Text("Tire Lab Setup")), 
      body: Padding( 
        padding: const EdgeInsets.all(16.0),
        child: Column( 
          children: [
            sensorWindow("GPS Location", gpsGranted ? "Ready" : "Waiting", gpsGranted, Icons.location_on, null),
            sensorWindow("Accelerometer", accelActive ? "Ready" : "Waiting", accelActive, Icons.vibration, null),
            
            const Divider(height: 30),

            // [CHANGED] 'speed' label added
            sensorWindow("Speed Sensor", speedSensorName, speedSensorName != "Not Connected", Icons.speed, 
              () => _startSensorScan("1816", "speed")),

            // [CHANGED] 'power' label added
            sensorWindow("Power Meter", powerMeterName, powerMeterName != "Not Connected", Icons.bolt, 
              () => _startSensorScan("1818", "power")),

            // [CHANGED] Now has its own '+' button and uses 'cadence' label
            sensorWindow("Cadence Sensor", cadenceSensorName, cadenceSensorName != "Not Connected", Icons.autorenew, 
              () => _startSensorScan("1816", "cadence")),

            const Spacer(), 
            
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (gpsGranted && speedSensorName != "Not Connected") ? () {} : null,
                child: const Text("NEXT: SELECT TEST PROTOCOL"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}