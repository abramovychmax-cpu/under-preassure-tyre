import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'sensor_service.dart';
import 'wheel_metrics_guide_page.dart';
import 'ui/app_menu_button.dart';
import 'ui/common_widgets.dart';

class SensorSetupPage extends StatefulWidget {
  final bool isOverlay;
  const SensorSetupPage({super.key, this.isOverlay = false});

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

    // Seed UI immediately from current service state (handles page re-push)
    final svc = SensorService();
    final initNames = svc.currentConnectedNames;
    final initSlots = svc.currentConnectedSlots;
    speedSensorName   = initNames['speed']   ?? '';
    powerMeterName    = initNames['power']    ?? '';
    cadenceSensorName = initNames['cadence']  ?? '';
    speedConnected    = initSlots.contains('speed');
    powerConnected    = initSlots.contains('power');
    cadenceConnected  = initSlots.contains('cadence');
    _useGpsSpeed      = svc.useGpsAsSpeed;
    
    // Subscribe to per-slot connection status
    _connectedSlotsSub = svc.connectedSlotsStream.listen((slots) {
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
    _connectedNamesSub = svc.connectedNamesStream.listen((map) {
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
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF222222))),
              const SizedBox(height: 8),
              const LinearProgressIndicator(backgroundColor: Color(0xFFE0E0E0), color: Color(0xFF47D1C1)),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<List<ScanResult>>(
                  stream: SensorService().scanResultsStream,
                  initialData: const [],
                  builder: (context, snapshot) {
                    final results = snapshot.data ?? [];

                    final filteredResults = results.where((data) {
                      final name = data.advertisementData.advName.toLowerCase();
                      final serviceUuids = data.advertisementData.serviceUuids.map((e) => e.toString().toLowerCase()).toList();

                      if (targetSlot == "speed") {
                        return serviceUuids.contains("1816") || name.contains("speed") || name.contains("cadence");
                      }
                      if (targetSlot == "cadence") {
                        return serviceUuids.contains("1816") || serviceUuids.contains("1818") || 
                               name.contains("cadence") || name.contains("power") || name.contains("kickr");
                      }
                      if (targetSlot == "power") {
                        return serviceUuids.contains("1818") || name.contains("power") || name.contains("kickr");
                      }
                      return true;
                    }).toList();

                    return ListView(
                      children: [
                        // GPS speed option — only shown in the speed sensor picker
                        if (targetSlot == "speed") ...[
                          ListTile(
                            leading: Icon(
                              Icons.gps_fixed,
                              color: _useGpsSpeed ? const Color(0xFF47D1C1) : Colors.black54,
                            ),
                            title: const Text(
                              'Use GPS Speed',
                              style: TextStyle(color: Color(0xFF222222), fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              _useGpsSpeed ? 'Currently active' : 'No Bluetooth sensor needed',
                              style: TextStyle(
                                color: _useGpsSpeed ? const Color(0xFF47D1C1) : Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            trailing: _useGpsSpeed
                                ? const Icon(Icons.check_circle, color: Color(0xFF47D1C1))
                                : null,
                            onTap: () {
                              _toggleGpsSpeed(true);
                              Navigator.pop(context);
                            },
                          ),
                          const Divider(height: 1),
                        ],
                        if (filteredResults.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 32),
                            child: Center(
                              child: Text("Searching for compatible sensors...", style: TextStyle(color: Colors.grey)),
                            ),
                          )
                        else
                          ...filteredResults.map((data) {
                            final name = data.advertisementData.advName.isEmpty ? "Unknown Device" : data.advertisementData.advName;
                            return ListTile(
                              leading: const Icon(Icons.bluetooth, color: Color(0xFF47D1C1)),
                              title: Text(name, style: const TextStyle(color: Color(0xFF222222), fontWeight: FontWeight.bold)),
                              subtitle: const Text("Tap to select", style: TextStyle(color: Colors.grey, fontSize: 12)),
                              onTap: () {
                                // Switching to BT sensor — disable GPS mode
                                if (targetSlot == "speed") _toggleGpsSpeed(false);
                                SensorService().cacheDeviceName(data.device.remoteId.str, name);
                                SensorService().setSavedSensor(targetSlot, data.device.remoteId.str);
                                setState(() {
                                  if (targetSlot == "speed") speedSensorName = name;
                                  if (targetSlot == "power") powerMeterName = name;
                                  if (targetSlot == "cadence") cadenceSensorName = name;
                                });
                                Navigator.pop(context);
                              },
                            );
                          }),
                      ],
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
        actions: const [AppMenuButton()],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: widget.isOverlay ? null : (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! < -200 && canProceed) {
            _handleSwipeUp();
          }
        },
        child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // top small status cards
            Expanded(
              child: AppCard(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Icon(Icons.gps_fixed, color: gpsGranted ? accentGemini : Colors.black54, size: 24),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('GPS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF222222))),
                              const SizedBox(height: 2),
                              Text(gpsGranted ? 'Locked' : 'Waiting...', style: TextStyle(fontSize: 12, color: gpsGranted ? accentGemini : Colors.black54)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: AppCard(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Icon(Icons.sensors, color: accelActive ? accentGemini : Colors.orangeAccent, size: 24),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Phone Vibration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF222222))),
                              const SizedBox(height: 2),
                              accelActive
                                  ? const Text('Ready', style: TextStyle(fontSize: 12, color: accentGemini, fontWeight: FontWeight.w600))
                                  : const Text('SHAKE YOUR PHONE NOW', style: TextStyle(fontSize: 12, color: Colors.orangeAccent, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // main sensor cards
            Expanded(
              child: InkWell(
                onTap: () => _startSensorScan('speed'),
                borderRadius: BorderRadius.circular(12),
                child: AppCard(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Icon(
                            _useGpsSpeed ? Icons.gps_fixed : Icons.speed,
                            color: (_useGpsSpeed || speedConnected) ? accentGemini : Colors.black54,
                            size: 24,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Speed Sensor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF222222))),
                                const SizedBox(height: 2),
                                if (_useGpsSpeed) ...[                                  
                                  const Text('GPS Speed', style: TextStyle(fontSize: 12, color: accentGemini, fontWeight: FontWeight.bold)),
                                  if (liveSpeedValue > 0.1) Text(liveSpeed, style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
                                ] else if (speedConnected) ...[                                  
                                  Text(speedSensorName, style: const TextStyle(fontSize: 12, color: accentGemini, fontWeight: FontWeight.bold)),
                                  if (liveSpeedValue > 0.1) Text(liveSpeed, style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
                                ] else if (speedSensorName.isNotEmpty)
                                  const Text('Connecting...', style: TextStyle(fontSize: 12, color: Colors.orange))
                                else
                                  const Text('Tap to add sensor', style: TextStyle(fontSize: 12, color: Colors.black54)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            (_useGpsSpeed || speedConnected) ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: (_useGpsSpeed || speedConnected) ? accentGemini : Colors.black26,
                            size: 24,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: InkWell(
                onTap: () => _startSensorScan('power'),
                borderRadius: BorderRadius.circular(12),
                child: AppCard(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Icon(Icons.bolt, color: powerConnected ? accentGemini : Colors.black54, size: 24),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Power Meter', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF222222))),
                                const SizedBox(height: 2),
                                if (powerConnected) ...[                                  
                                  Text(powerMeterName, style: const TextStyle(fontSize: 12, color: accentGemini, fontWeight: FontWeight.bold)),
                                  if (livePowerValue > 0) Text(livePower, style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
                                ] else if (powerMeterName.isNotEmpty)
                                  const Text('Connecting...', style: TextStyle(fontSize: 12, color: Colors.orange))
                                else
                                  const Text('Tap to add sensor', style: TextStyle(fontSize: 12, color: Colors.black54)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            powerConnected ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: powerConnected ? accentGemini : Colors.black26,
                            size: 24,
                          ),
                        ],
                      ),
                    ),
                  ),
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
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Icon(Icons.loop, color: cadenceConnected ? accentGemini : Colors.black54, size: 24),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Cadence', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF222222))),
                                const SizedBox(height: 2),
                                if (cadenceConnected) ...[                                  
                                  Text(cadenceSensorName, style: const TextStyle(fontSize: 12, color: accentGemini, fontWeight: FontWeight.bold)),
                                  if (liveCadenceValue > 0) Text(liveCadence, style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
                                ] else if (cadenceSensorName.isNotEmpty)
                                  const Text('Connecting...', style: TextStyle(fontSize: 12, color: Colors.orange))
                                else
                                  const Text('Tap to add sensor', style: TextStyle(fontSize: 12, color: Colors.black54)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            cadenceConnected ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: cadenceConnected ? accentGemini : Colors.black26,
                            size: 24,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),
            // Swipe indicator
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.keyboard_arrow_left,
                    color: canProceed ? accentGemini : Colors.grey.shade400,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    canProceed
                        ? 'SWIPE TO CONFIGURE WHEEL'
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
            ),
            const SafeArea(top: false, child: SizedBox(height: 16)),
          ],
        ),
      ),
    ),
    );
  }
}
