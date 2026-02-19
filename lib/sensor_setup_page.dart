import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'sensor_service.dart';
import 'wheel_metrics_guide_page.dart';
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
  StreamSubscription? _connectedSlotsSub;

  bool speedConnected = false;
  bool powerConnected = false;
  bool cadenceConnected = false;

  /// True when user explicitly opts to use GPS as their speed source
  bool _useGpsSpeed = false;

  void _toggleGpsSpeed(bool value) {
    setState(() => _useGpsSpeed = value);
    SensorService().setUseGpsAsSpeed(value);
  }

  @override
  void initState() {
    super.initState();
    _loadSpeedUnit();
    _initInternalSensors();
    _initDataStreams();
    
    // Subscribe to per-slot connection status
    _connectedSlotsSub = SensorService().connectedSlotsStream.listen((slots) {
      if (!mounted) return;
      setState(() {
        speedConnected   = slots.contains('speed');
        powerConnected   = slots.contains('power');
        cadenceConnected = slots.contains('cadence');
      });
    });

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
    _connectedSlotsSub?.cancel();
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
                        return serviceUuids.contains("1816") || name.contains("speed") || name.contains("cadence");
                      }
                      if (targetSlot == "cadence") {
                        // 1816 is Cycling Speed and Cadence Service
                        // 1818 is Cycling Power Service (most power meters provide cadence)
                        return serviceUuids.contains("1816") || serviceUuids.contains("1818") || 
                               name.contains("cadence") || name.contains("power") || name.contains("kickr");
                      }
                      if (targetSlot == "power") {
                        // 1818 is Cycling Power Service
                        return serviceUuids.contains("1818") || name.contains("power") || name.contains("kickr");
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
                          subtitle: const Text("Tap to select", style: TextStyle(color: Colors.grey, fontSize: 12)),
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

  void _handleSwipeUp() {
    final bool canProceed = (_useGpsSpeed || speedConnected) && gpsGranted;
    if (canProceed) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const WheelMetricsGuidePage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canProceed = (_useGpsSpeed || speedConnected) && gpsGranted;
    
    // use light background and shared app card styles
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        backgroundColor: bgLight,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'SENSOR SETUP',
          style: TextStyle(color: Color(0xFF222222), fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16),
        ),
        centerTitle: true,
        foregroundColor: const Color(0xFF222222),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! < -500 && canProceed) {
            _handleSwipeUp();
          }
        },
        child: Padding(
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
                    leading: Icon(Icons.sensors, color: accelActive ? accentGemini : Colors.orangeAccent),
                    title: const Text('Phone Vibration', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF222222))),
                    subtitle: accelActive 
                        ? const Text('Ready', style: TextStyle(color: accentGemini, fontWeight: FontWeight.w600))
                        : const Text('⚠️ SHAKE YOUR PHONE NOW', style: TextStyle(color: Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.w900)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // main sensor cards (same height)
            Expanded(
              child: InkWell(
                onTap: () => _startSensorScan('speed'),
                borderRadius: BorderRadius.circular(12),
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
                    : const Text('tap to add sensor', style: TextStyle(color: Colors.black54)),
                trailing: Icon(
                  speedSensorName.isNotEmpty ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: speedSensorName.isNotEmpty ? accentGemini : Colors.black38,
                  size: 28,
                ))),
                ),
              ),
            ),
            // GPS speed fallback toggle — visible only when no BT speed sensor connected
            if (!speedConnected)
              GestureDetector(
                onTap: () => _toggleGpsSpeed(!_useGpsSpeed),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _useGpsSpeed ? Icons.gps_fixed : Icons.gps_not_fixed,
                        size: 13,
                        color: _useGpsSpeed ? accentGemini : Colors.grey.shade500,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _useGpsSpeed
                            ? 'GPS SPEED ACTIVE — tap to switch to BT sensor'
                            : 'No speed sensor? Tap to use GPS speed instead',
                        style: TextStyle(
                          fontSize: 11,
                          color: _useGpsSpeed ? accentGemini : Colors.grey.shade500,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              const SizedBox(height: 8),
            Expanded(
              child: InkWell(
                onTap: () => _startSensorScan('power'),
                borderRadius: BorderRadius.circular(12),
                child: AppCard(
                  child: Center(
                      child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      minLeadingWidth: 44,
                    horizontalTitleGap: 12,
                    leading: Icon(Icons.bolt, color: powerConnected ? accentGemini : Colors.black54),
                    title: const Text('Power Meter', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF222222))),
                    subtitle: powerConnected
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(powerMeterName, style: const TextStyle(color: accentGemini, fontWeight: FontWeight.bold)),
                          if (livePowerValue > 0) ...[const SizedBox(height: 4), Text(livePower, style: const TextStyle(color: Color(0xFF888888), fontSize: 12))],
                        ],
                      )
                    : powerMeterName.isNotEmpty
                      ? const Text('Connecting...', style: TextStyle(color: Colors.orange))
                      : const Text('tap to add sensor', style: TextStyle(color: Colors.black54)),
                  trailing: Icon(
                    powerConnected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: powerConnected ? accentGemini : Colors.black38,
                    size: 28,
                  ))),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: InkWell(
                onTap: () => _startSensorScan('cadence'),
                borderRadius: BorderRadius.circular(12),
                child: AppCard(
                  child: Center(
                      child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    minLeadingWidth: 44,
                    horizontalTitleGap: 12,
                    leading: Icon(Icons.loop, color: cadenceConnected ? accentGemini : Colors.black54),
                    title: const Text('Cadence', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF222222))),
                    subtitle: cadenceConnected
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cadenceSensorName, style: const TextStyle(color: accentGemini, fontWeight: FontWeight.bold)),
                          if (liveCadenceValue > 0) ...[const SizedBox(height: 4), Text(liveCadence, style: const TextStyle(color: Color(0xFF888888), fontSize: 12))],
                        ],
                      )
                    : cadenceSensorName.isNotEmpty
                      ? const Text('Connecting...', style: TextStyle(color: Colors.orange))
                      : const Text('tap to add sensor', style: TextStyle(color: Colors.black54)),
                  trailing: Icon(
                    cadenceConnected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: cadenceConnected ? accentGemini : Colors.black38,
                    size: 28,
                  ))),
                ),
              ),
            ),

            const SizedBox(height: 12),
            // Swipe indicator
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.keyboard_arrow_left,
                  color: canProceed ? accentGemini : Colors.grey.shade400,
                  size: 28,
                ),
                const SizedBox(height: 4),
                Text(
                  canProceed
                      ? 'SWIPE LEFT TO CONFIGURE WHEEL'
                      : _useGpsSpeed
                          ? 'ENABLE GPS FIRST'
                          : 'CONNECT SPEED SENSOR FIRST',
                  style: TextStyle(
                    color: canProceed ? accentGemini : Colors.grey.shade400,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ),
    );
  }
}