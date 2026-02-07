import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'sensor_service.dart';
import 'wheel_metrics_page.dart';
import 'ui/common_widgets.dart';

class SensorSetupPage extends StatefulWidget {
  const SensorSetupPage({super.key});

  @override
  State<SensorSetupPage> createState() => _SensorSetupPageState();
}

class _SensorSetupPageState extends State<SensorSetupPage> {
  String speedSensorName = "";
  String powerMeterName = "";
  String cadenceSensorName = "";

  String liveCadence = "0 RPM";
  String livePower = "0 W";
  String liveSpeed = "0.0 km/h";
  String _speedUnit = 'km/h'; // Load from SharedPreferences
  // numeric copies to determine whether to display non-zero readings
  double liveSpeedValue = 0.0;
  int liveCadenceValue = 0;
  int livePowerValue = 0;

  bool gpsGranted = false;
  bool accelActive = false;

  StreamSubscription? _speedSub;
  StreamSubscription? _cadenceSub;
  StreamSubscription? _powerSub;
  StreamSubscription? _connectedNamesSub;

  @override
  void initState() {
    super.initState();
    _loadSpeedUnit();
    _initInternalSensors();
    _initDataStreams();
    // ensure any open keyboard is dismissed when entering this page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).unfocus();
    });
    // listen for automatic discovery/connection name updates
    _connectedNamesSub = SensorService().connectedNamesStream.listen((map) {
      if (!mounted) return;
      setState(() {
        speedSensorName = map['speed'] ?? '';
        powerMeterName = map['power'] ?? '';
        cadenceSensorName = map['cadence'] ?? '';
      });
    });
  }

  Future<void> _loadSpeedUnit() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _speedUnit = prefs.getString('speed_unit') ?? 'km/h';
    });
  }

  double _convertSpeed(double kmh) {
    if (_speedUnit == 'mph') {
      return kmh * 0.621371;
    }
    return kmh;
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
      if (mounted) {
        setState(() {
        liveSpeedValue = speed;
        final displaySpeed = _convertSpeed(speed);
        liveSpeed = "${displaySpeed.toStringAsFixed(1)} $_speedUnit";
      });
      }
    });
    _cadenceSub = SensorService().cadenceStream.listen((rpm) {
      if (mounted) {
        setState(() {
        liveCadenceValue = rpm;
        liveCadence = "$rpm RPM";
      });
      }
    });
    _powerSub = SensorService().powerStream.listen((watts) {
      if (mounted) {
        setState(() {
        livePowerValue = watts;
        livePower = "$watts W";
      });
      }
    });
  }

  Future<void> _initInternalSensors() async {
    // REQUEST GPS PERMISSION (iOS popup)
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) {
        _showPermissionError('GPS', 'Please enable Location in Settings → Privacy → Location Services');
        return;
      }
    }
    if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
      setState(() => gpsGranted = true);
      print('GPS Permission Granted: $permission');
    }

    // ACCELEROMETER LISTENER (for shake detection)
    accelerometerEventStream().listen((event) {
      // Vibration magnitude in m/s² → convert to G (divide by 9.81)
      final magnitude = (event.x.abs() + event.y.abs() + event.z.abs()) / 3.0;
      final magnitudeInG = magnitude / 9.81;
      
      // Lower threshold: any shake >0.8G should register (typical phone shake = 2-5G)
      if (!accelActive && magnitudeInG > 0.8) {
        setState(() => accelActive = true);
        print('ACCELEROMETER DETECTED: Magnitude=$magnitudeInG G');
        // Vibrate/haptic feedback on detection
        try {
          HapticFeedback.mediumImpact();
        } catch (_) {}
      }
    });
  }

  void _showPermissionError(String permissionName, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$permissionName Permission Required: $message'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _startSensorScan(String targetSlot) {
    SensorService().startFilteredScan(targetSlot);
    _showDevicePicker(targetSlot);
  }

  void _showDevicePicker(String targetSlot) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF2F2F2), // Light theme background
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          height: 500,
          child: Column(
            children: [
              Text("Select ${targetSlot.toUpperCase()} Sensor",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF222222))),
              const SizedBox(height: 8),
              const LinearProgressIndicator(backgroundColor: Color(0xFFE0E0E0), color: Color(0xFF47D1C1)),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<List<ScanResult>>(
                  stream: SensorService().scanResultsStream,
                  initialData: const [],
                  builder: (context, snapshot) {
                    final results = snapshot.data ?? [];

                    // CHANGE 1: Filtering the results based on the Slot
                    final filteredResults = results.where((data) {
                      final name = data.advertisementData.advName.toLowerCase();
                      final serviceUuids = data.advertisementData.serviceUuids.map((e) => e.toString().toLowerCase()).toList();

                      if (targetSlot == "speed") {
                        // 1816 is Cycling Speed and Cadence Service
                        return serviceUuids.contains("1816") || name.contains("speed") || name.contains("cadence") || name.contains("kickr");
                      }
                      if (targetSlot == "cadence") {
                        // 1816 is Cycling Speed and Cadence Service - KICKR also provides cadence
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
                        final name = data.advertisementData.advName.isEmpty ? "Unknown Device" : data.advertisementData.advName;

                        return ListTile(
                          leading: const Icon(Icons.bluetooth, color: Color(0xFF47D1C1)),
                          title: Text(name, style: const TextStyle(color: Color(0xFF222222), fontWeight: FontWeight.bold)),
                          subtitle: Text(data.device.remoteId.str, style: const TextStyle(color: Colors.grey)),
                          onTap: () {
                            // Cache the device name immediately before connecting
                            SensorService().cacheDeviceName(data.device.remoteId.str, name);
                            
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
    const Color cardDark = Color(0xFFF2F2F2);
    const Color geminiTeal = Color(0xFF47D1C1);
    const Color borderGrey = Color(0xFFD8D8D8);

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
        minLeadingWidth: 44,
        horizontalTitleGap: 12,
        leading: Icon(icon, color: isActive ? geminiTeal : Colors.grey, size: 30),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF222222))),
        subtitle: Text(isActive ? subtitle : "Not Connected", style: TextStyle(color: isActive ? geminiTeal.withAlpha((0.9 * 255).round()) : Colors.grey)),
        trailing: onConnect != null
            ? IconButton(icon: const Icon(Icons.add_link, color: geminiTeal, size: 30), onPressed: onConnect)
            : (isActive ? const Icon(Icons.check_circle, color: geminiTeal) : null),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // use light background and shared app card styles
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        backgroundColor: bgLight,
        elevation: 0,
        title: const Text(
          'SENSOR SETUP',
          style: TextStyle(color: Color(0xFF222222), fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16),
        ),
        centerTitle: true,
        foregroundColor: const Color(0xFF222222),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // top small status cards (match styling of the main sensor cards)
            Expanded(
              child: AppCard(
                child: Center(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    minLeadingWidth: 44,
                    horizontalTitleGap: 12,
                    leading: Icon(Icons.gps_fixed, color: gpsGranted ? accentGemini : Colors.black54),
                    title: const Text('GPS', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF222222))),
                    subtitle: Text(gpsGranted ? 'Locked' : 'Waiting...', style: TextStyle(color: gpsGranted ? accentGemini : Colors.black54)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: AppCard(
                child: Center(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    minLeadingWidth: 44,
                    horizontalTitleGap: 12,
                    leading: Icon(Icons.sensors, color: accelActive ? accentGemini : Colors.black54),
                    title: const Text('Phone Vibration', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF222222))),
                    subtitle: Text(accelActive ? 'Ready' : 'Shake phone', style: TextStyle(color: accelActive ? accentGemini : Colors.black54)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // main sensor cards (same height)
            Expanded(
              child: AppCard(
                child: Center(
                    child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  minLeadingWidth: 44,
                  horizontalTitleGap: 12,
                  leading: Icon(Icons.speed, color: speedSensorName.isNotEmpty ? accentGemini : Colors.black54),
                  title: const Text('Speed Sensor', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF222222))),
                  subtitle: speedSensorName.isNotEmpty
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(speedSensorName, style: const TextStyle(color: accentGemini, fontWeight: FontWeight.bold)),
                        if (liveSpeedValue > 0.1) ...[
                          const SizedBox(height: 4),
                          Text(liveSpeed, style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
                        ],
                      ],
                    )
                  : const Text('add sensor', style: TextStyle(color: Colors.black54)),
              trailing: IconButton(icon: const Icon(Icons.add_link, color: accentGemini), onPressed: () => _startSensorScan('speed')))))),
            const SizedBox(height: 8),
            Expanded(
              child: AppCard(
                child: Center(
                    child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    minLeadingWidth: 44,
                  horizontalTitleGap: 12,
                  leading: Icon(Icons.bolt, color: powerMeterName.isNotEmpty ? accentGemini : Colors.black54),
                  title: const Text('Power Meter', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF222222))),
                  subtitle: powerMeterName.isNotEmpty
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(powerMeterName, style: const TextStyle(color: accentGemini, fontWeight: FontWeight.bold)),
                        if (livePowerValue > 0) ...[
                          const SizedBox(height: 4),
                          Text(livePower, style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
                        ],
                      ],
                    )
                  : const Text('add sensor', style: TextStyle(color: Colors.black54)),
              trailing: IconButton(icon: const Icon(Icons.add_link, color: accentGemini), onPressed: () => _startSensorScan('power')))))),
            const SizedBox(height: 8),
            Expanded(
              child: AppCard(
                child: Center(
                    child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  minLeadingWidth: 44,
                  horizontalTitleGap: 12,
                  leading: Icon(Icons.loop, color: cadenceSensorName.isNotEmpty ? accentGemini : Colors.black54),
                  title: const Text('Cadence', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF222222))),
                  subtitle: cadenceSensorName.isNotEmpty
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cadenceSensorName, style: const TextStyle(color: accentGemini, fontWeight: FontWeight.bold)),
                        if (liveCadenceValue > 0) ...[
                          const SizedBox(height: 4),
                          Text(liveCadence, style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
                        ],
                      ],
                    )
                  : const Text('add sensor', style: TextStyle(color: Colors.black54)),
              trailing: IconButton(icon: const Icon(Icons.add_link, color: accentGemini), onPressed: () => _startSensorScan('cadence')))))),

            const SizedBox(height: 12),
            // fixed action button - navigate to wheel metrics setup first
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: (speedSensorName != "Not Connected" && gpsGranted) ? () => Navigator.push(context, MaterialPageRoute(builder: (context) => const WheelMetricsPage())) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentGemini,
                  foregroundColor: bgLight,
                  disabledBackgroundColor: Colors.grey.shade400,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text("CONFIGURE WHEEL & TIRE", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}