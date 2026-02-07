import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'fit_writer.dart';

class SensorService {
  static final SensorService _instance = SensorService._internal();
  factory SensorService() => _instance;
  SensorService._internal();

  // --- STREAMS ---
  final _speedController = StreamController<double>.broadcast();
  Stream<double> get speedStream => _speedController.stream;

  final _distanceController = StreamController<double>.broadcast();
  Stream<double> get distanceStream => _distanceController.stream;

  final _powerController = StreamController<int>.broadcast();
  Stream<int> get powerStream => _powerController.stream;
  final _vibrationController = StreamController<double>.broadcast();
  Stream<double> get vibrationStream => _vibrationController.stream;
  // buffer of recent vibration samples for smoothing (timestamp ms -> value in g)
  final List<Map<String, double>> _vibrationSamples = [];
  static const int _vibrationWindowMs = 300;
  // buffer of recent power samples for averaging (timestamp ms -> value)
  final List<Map<String, int>> _powerSamples = [];
  static const int _powerWindowMs = 3000;

  final _cadenceController = StreamController<int>.broadcast();
  Stream<int> get cadenceStream => _cadenceController.stream;
  Timer? _crankStopTimer;

  final _scanResultsController = StreamController<List<ScanResult>>.broadcast();
  Stream<List<ScanResult>> get scanResultsStream => _scanResultsController.stream;

  // --- FIT RECORDING ---
  FitWriter? _fitWriter;

  // publishes currently-resolved display names for saved slots
  final _connectedNamesController = StreamController<Map<String, String>>.broadcast();
  Stream<Map<String, String>> get connectedNamesStream => _connectedNamesController.stream;

  // cache of discovered device display names by id
  final Map<String, String> _deviceNames = {};

  // --- VARIABLES ---
  String? _savedSpeedId;
  String? _savedPowerId; 
  String? _savedCadenceId; 
  
  final Map<String, BluetoothDevice> _connectedDevices = {};
  final Set<String> _connectingIds = {}; 
  bool _sequentialConnectInProgress = false;
  final Map<String, int> _requestedMtu = {};
  
  double currentSpeedValue = 0.0;
  double currentDistanceValue = 0.0;

  double _btSpeed = 0.0;
  double _gpsSpeed = 0.0;
  bool _usingBt = false;

  static const double minSpeedThreshold = 3.0;
  
  int? _lastWheelRevs;
  int? _lastWheelTime;
  
  int? _lastCrankRevs;
  int? _lastCrankTime;
  
  int? _lapStartRevs; 
  double _currentRunDistance = 0.0;
  static const double wheelCircumference = 2.100; // Meters

  Timer? _stopTimer;
  Timer? _uiPublisherTimer;
  int _lastPublishedCadence = 0;
  StreamSubscription? _accelSub;

  // --- INITIALIZATION ---
  Future<void> loadSavedSensors() async {
    final prefs = await SharedPreferences.getInstance();
    _savedSpeedId = prefs.getString('speed_sensor_id');
    _savedPowerId = prefs.getString('power_sensor_id');
    _savedCadenceId = prefs.getString('cadence_sensor_id');

    print("LOADED SENSORS: Speed($_savedSpeedId), Power($_savedPowerId), Cadence($_savedCadenceId)");
    startScanning();
    _initGps();
    // start periodic UI publisher (2 Hz) to improve UI refresh reliability
    _uiPublisherTimer?.cancel();
    _uiPublisherTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      // re-emit latest values so UI updates at steady rate
      _speedController.add(currentSpeedValue);
      _cadenceController.add(_lastPublishedCadence);
    });

    // start accelerometer listener for vibration magnitude (m/s^2 -> g)
    _accelSub?.cancel();
    _accelSub = accelerometerEventStream().listen((event) {
      // magnitude in m/s^2
      final double mag = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      // convert to g
      final double g = mag / 9.80665;

      final int now = DateTime.now().millisecondsSinceEpoch;
      _vibrationSamples.add({'ts': now.toDouble(), 'v': g});

      final int cutoff = now - _vibrationWindowMs;
      while (_vibrationSamples.isNotEmpty && (_vibrationSamples.first['ts'] ?? 0) < cutoff) {
        _vibrationSamples.removeAt(0);
      }

      if (_vibrationSamples.isNotEmpty) {
        double sum = 0.0;
        for (final s in _vibrationSamples) {
          sum += (s['v'] ?? 0.0);
        }
        final double avg = sum / _vibrationSamples.length;
        _vibrationController.add(avg);
        _lastPublishedVibration = avg; // Cache for recording
      }
    });
  }

  void _emitConnectedNames() {
    final Map<String, String> out = {
      'speed': _savedSpeedId == null ? 'Not Connected' : (_deviceNames[_savedSpeedId] ?? _savedSpeedId!),
      'power': _savedPowerId == null ? 'Not Connected' : (_deviceNames[_savedPowerId] ?? _savedPowerId!),
      'cadence': _savedCadenceId == null ? 'Not Connected' : (_deviceNames[_savedCadenceId] ?? _savedCadenceId!),
    };
    _connectedNamesController.add(out);
  }

  // Cache a device name before connecting to prevent showing ID temporarily
  void cacheDeviceName(String deviceId, String deviceName) {
    _deviceNames[deviceId] = deviceName;
    _emitConnectedNames(); // Immediately update UI with cached name
  }

  void setSavedSensor(String targetSlot, String id) async {
    final prefs = await SharedPreferences.getInstance();
    if (targetSlot == "speed") {
      _savedSpeedId = id;
      await prefs.setString('speed_sensor_id', id);
    } else if (targetSlot == "power") {
      _savedPowerId = id;
      await prefs.setString('power_sensor_id', id);
    } else if (targetSlot == "cadence") {
      _savedCadenceId = id;
      await prefs.setString('cadence_sensor_id', id);
    }
    startScanning(); 
  }

  void resetDistance() {
    // Save current position as lap baseline
    if (_lastWheelRevs != null) {
      _lapStartRevs = _lastWheelRevs;
    }
    _currentRunDistance = 0.0;
    _distanceController.add(0.0);
    // Don't reset _lastWheelRevs/_lastWheelTime - keep them for speed calculation continuity
    print("Distance Reset. Baseline Wheel Revs: $_lapStartRevs");
  }

  void _initGps() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    ).listen((Position position) {
      double rawGps = position.speed * 3.6;
      _gpsSpeed = rawGps < minSpeedThreshold ? 0.0 : rawGps;
      _decideWhichSpeedToPublish();
    });
  }

  // --- BLUETOOTH CORE ---
  void startScanning() async {
    if (FlutterBluePlus.isScanningNow) return;

    FlutterBluePlus.scanResults.listen((results) {
      // cache display names from recent scan results so we can show them when connected
      for (final r in results) {
        final name = r.advertisementData.advName.isEmpty ? 'Unknown Device' : r.advertisementData.advName;
        _deviceNames[r.device.remoteId.str] = name;
      }
      _processSavedDevicesSequentially(results);
    });

    try {
      await FlutterBluePlus.startScan(
        withServices: [Guid("1816"), Guid("1818")],
        timeout: const Duration(minutes: 10),
      );
    } catch (e) { print("Scan Error: $e"); }
  }

  void startFilteredScan(String targetSlot) async {
    if (FlutterBluePlus.isScanningNow) await FlutterBluePlus.stopScan();

    // Determine which services to scan for
    List<Guid> targetServices = [];
    if (targetSlot == "power") {
      targetServices = [Guid("1818")]; // Power only
    } else if (targetSlot == "speed") {
      targetServices = [Guid("1816")]; // Speed/Cadence only
    } else {
      // Cadence can come from 1816 (SPD/CAD) or 1818 (Power Meter)
      targetServices = [Guid("1816"), Guid("1818")]; 
    }

    FlutterBluePlus.scanResults.listen((results) {
      var filtered = results.where((r) {
        if (r.advertisementData.advName.isNotEmpty) {
          _deviceNames[r.device.remoteId.str] = r.advertisementData.advName;
        }
        
        bool matchesService = false;
        for (var uuid in targetServices) {
          if (r.advertisementData.serviceUuids.contains(uuid)) {
            matchesService = true;
            break;
          }
        }
        
        // Also allow by name if service UUID is missing from advertisement packet (common in some BLE devices)
        String name = r.advertisementData.advName.toLowerCase();
        if (!matchesService) {
           if (targetSlot == 'cadence' || targetSlot == 'power') {
             if (name.contains('kickr') || name.contains('power') || name.contains('cadence')) matchesService = true;
           }
        }

        return matchesService && r.advertisementData.advName.isNotEmpty;
      }).toList();
      _scanResultsController.add(filtered);
    });

    try {
      await FlutterBluePlus.startScan(
        withServices: targetServices,
        timeout: const Duration(seconds: 15),
      );
    } catch (e) { print("Filtered Scan Error: $e"); }
  }

  Future<void> _processSavedDevicesSequentially(List<ScanResult> results) async {
    if (_sequentialConnectInProgress) return;
    _sequentialConnectInProgress = true;
    try {
      final Map<String, BluetoothDevice> found = {};
      for (final r in results) {
        found[r.device.remoteId.str] = r.device;
      }

      final List<String> order = [
        if (_savedSpeedId != null) _savedSpeedId!,
        if (_savedPowerId != null) _savedPowerId!,
        if (_savedCadenceId != null) _savedCadenceId!,
      ];

      for (final id in order) {
        final device = found[id];
        if (device == null) continue;
        if (_connectedDevices.containsKey(id) || _connectingIds.contains(id)) continue;

        await _connectToDevice(device);
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    } finally {
      _sequentialConnectInProgress = false;
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    String deviceId = device.remoteId.str;
    
    if (_connectedDevices.containsKey(deviceId) || _connectingIds.contains(deviceId)) return;
    _connectingIds.add(deviceId);

    try {
      // 1. CRITICAL: Stop scanning before connecting to prevent Status 133
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
        await Future.delayed(const Duration(milliseconds: 500)); 
      }

      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _handleDisconnection(deviceId);
        }
      });

      // 2. Connect with specific timeout
      await device.connect(
        autoConnect: false, 
        timeout: const Duration(seconds: 15),
      );
      
      print("CONNECTED SUCCESSFULLY: $deviceId");

      // 3. Post-connection Breath (Sequential GATT operations)
      await Future.delayed(const Duration(milliseconds: 1000));
      if (_requestedMtu[deviceId] != 223) {
        try {
          await device.requestMtu(223);
          _requestedMtu[deviceId] = 223;
        } catch (_) {
          // ignore mtu errors
        }
      }

      await Future.delayed(const Duration(milliseconds: 800));
      List<BluetoothService> services = await device.discoverServices();
      
      _connectedDevices[deviceId] = device;
      print('REGISTERED CONNECTED DEVICE: $deviceId');
      // update the connected names broadcast so UI can show friendly names
      _emitConnectedNames();
      _connectingIds.remove(deviceId);

      for (var s in services) {
        if (s.uuid == Guid("1816")) {
          for (var c in s.characteristics) {
            if (c.uuid == Guid("2A5B")) {
              await _enableNotification(c, (data) => _parseCSC(data, deviceId));
            }
          }
        }
        if (s.uuid == Guid("1818")) {
          for (var c in s.characteristics) {
            if (c.uuid == Guid("2A63")) {
              await _enableNotification(c, (data) => _parsePower(data, deviceId));
            }
          }
        }
      }
    } catch (e) {
      print("Connect Error: $e");
      _connectingIds.remove(deviceId);

      // Cooldown for Android BT stack before restarting scan
      await Future.delayed(const Duration(seconds: 2));
      if (!_sequentialConnectInProgress && _connectingIds.isEmpty) {
        startScanning();
      }
    }
  }

  Future<void> _enableNotification(BluetoothCharacteristic c, Function(List<int>) parser) async {
    try {
      await c.setNotifyValue(true);
      c.lastValueStream.listen((v) => parser(v));
    } catch (e) {
      for (BluetoothDescriptor d in c.descriptors) {
        if (d.uuid == Guid("2902")) {
          await d.write([0x01, 0x00]);
        }
      }
      c.lastValueStream.listen((v) => parser(v));
    }
  }

  void _handleDisconnection(String id) {
    _connectedDevices.remove(id);
    _connectingIds.remove(id);
    if (id == _savedSpeedId) {
      _usingBt = false;
      _lastWheelRevs = null;
    }
    // clear cached name for the disconnected saved slot if desired
    if (_savedSpeedId == id) _deviceNames.remove(id);
    if (_savedPowerId == id) _deviceNames.remove(id);
    if (_savedCadenceId == id) _deviceNames.remove(id);
    _emitConnectedNames();
    startScanning();
  }

  // call this when the service is being destroyed (not currently used)
  void dispose() {
    _speedController.close();
    _distanceController.close();
    _powerController.close();
    _cadenceController.close();
    _scanResultsController.close();
    _connectedNamesController.close();
    _uiPublisherTimer?.cancel();
    _stopTimer?.cancel();
    _crankStopTimer?.cancel();
    _accelSub?.cancel();
    _vibrationController.close();
  }

  int _lastPublishedPower = 0;
  double _lastPublishedVibration = 0.0;
  Timer? _recordingTimer;

  // --- REFACTORED PARSERS --- 
  // ( ... existing parser code ...)


  void _parseCSC(List<int> data, String deviceId) {
    if (data.isEmpty) return;
    int flags = data[0];
    print('CSC packet from $deviceId flags=$flags len=${data.length}');
    bool hasWheel = (flags & 0x01) != 0;
    bool hasCrank = (flags & 0x02) != 0;

      if (hasWheel && deviceId == _savedSpeedId && data.length >= 7) {
      _usingBt = true;
      int currentRevs = (data[1]) | (data[2] << 8) | (data[3] << 16) | (data[4] << 24);
      int currentTime = (data[5]) | (data[6] << 8);
      print('CSC wheel: device=$deviceId revs=$currentRevs time=$currentTime');

      // If this is the very first wheel reading we see, set lap baseline
      _lapStartRevs ??= currentRevs;

      if (_lastWheelRevs != null && _lastWheelTime != null) {
        int revDiff = (currentRevs - _lastWheelRevs!) & 0xFFFFFFFF;
        int timeDiff = (currentTime - _lastWheelTime!) & 0xFFFF;
        if (revDiff > 0 && timeDiff > 0) {
          // movement detected -> compute speed and restart stop timer
          _btSpeed = ((revDiff * wheelCircumference) / (timeDiff / 1024.0)) * 3.6;

          // update distance (use lap baseline)
          if (_lapStartRevs != null) {
            int runDeltaRevs = (currentRevs - _lapStartRevs!) & 0xFFFFFFFF;
            _currentRunDistance = (runDeltaRevs * wheelCircumference) / 1000.0;
          }

          // only cancel/restart the stop timer when real motion occurred
          _stopTimer?.cancel();
          _stopTimer = Timer(const Duration(seconds: 2), () {
            _btSpeed = 0.0;
            _decideWhichSpeedToPublish();
          });
        }
      } else {
        // No previous sample; can't compute speed yet but keep last revs/time
      }

      _lastWheelRevs = currentRevs;
      _lastWheelTime = currentTime;
      _decideWhichSpeedToPublish();
    }


    if (hasCrank && (deviceId == _savedCadenceId || (deviceId == _savedPowerId && _savedCadenceId == _savedPowerId) || (deviceId == _savedPowerId && _savedCadenceId?.toLowerCase().contains("kickr") == true))) {
      // For Power Meters (UUID 1818), the Crank Data is usually in the Power Feature/Measurement
      // But here we are in _parseCSC (0x2A5B). 
      // KICKR sends standard CSC (0x1816) AND Power (0x1818).
      // If the user selected the "Power" device as "Cadence", we assume it supports CSC or we need to parse Cadence from Power.
      // This function _parseCSC parses 0x2A5B.
      // If the device is streaming 0x2A5B, we parse it.
      
      int offset = hasWheel ? 7 : 1;
      if (data.length >= offset + 4) {
        int currentCrankRevs = (data[offset]) | (data[offset + 1] << 8);
        int currentCrankTime = (data[offset + 2]) | (data[offset + 3] << 8);

        if (_lastCrankRevs != null) {
          int revDiff = (currentCrankRevs - _lastCrankRevs!) & 0xFFFF;
          int timeDiff = (currentCrankTime - _lastCrankTime!) & 0xFFFF;
          if (revDiff > 0 && timeDiff > 0) {
            double rpm = (revDiff * 60 * 1024) / timeDiff;
            int rpmInt = rpm.toInt();
            _cadenceController.add(rpmInt);
            _lastPublishedCadence = rpmInt;
            
            // Only reset timer on ACTUAL crank movement
            _crankStopTimer?.cancel();
            _crankStopTimer = Timer(const Duration(milliseconds: 1500), () {
              _cadenceController.add(0);
              _lastPublishedCadence = 0;
            });
          }
        }
        _lastCrankRevs = currentCrankRevs;
        _lastCrankTime = currentCrankTime;
      }
    }
  }

  void _parsePower(List<int> data, String deviceId) {
    // Handling Cadence from Power Meter Characteristic (0x2A63)
    // Format: Flags(16), Power(16), ...
    // Bit 5 of Flags = Crank Revolution Data Present
    if (data.length >= 4) {
      int flags = data[0] | (data[1] << 8);
      bool hasCrankData = (flags & 0x20) != 0;
      
      // If this device is the selected Cadence source (e.g. Kickr), try to extract cadence
      // Or if no specific cadence sensor is selected but we have a power meter
      bool useForCadence = (deviceId == _savedCadenceId) || (_savedCadenceId == null && deviceId == _savedPowerId);
      
      if (hasCrankData && useForCadence && data.length >= 8) {
         // Should verify offset.
         // Standard: Flags(2) + Power(2) = 4 bytes.
         // + Balance(1) if Bit 0. + Torque(2) if Bit 2? No, let's just scan for it.
         // Actually, let's be safer.
         // Mandatory: Flags(2), Power(2) -> Offset 4.
         int offset = 4;
         if ((flags & 0x01) != 0) offset += 1; // Pedal Power Balance
         if ((flags & 0x04) != 0) offset += 2; // Accumulated Torque
         
         if ((flags & 0x20) != 0 && data.length >= offset + 4) {
            int crankRevs = data[offset] | (data[offset+1] << 8);
            int crankTime = data[offset+2] | (data[offset+3] << 8);
            
            if (_lastCrankRevs != null) {
               int rDiff = (crankRevs - _lastCrankRevs!) & 0xFFFF;
               int tDiff = (crankTime - _lastCrankTime!) & 0xFFFF;
               if (rDiff > 0 && tDiff > 0) {
                 double rpm = (rDiff * 60 * 1024) / tDiff;
                 int rpmInt = rpm.toInt();
                 _cadenceController.add(rpmInt);
                 _lastPublishedCadence = rpmInt;
                 
                  _crankStopTimer?.cancel();
                  _crankStopTimer = Timer(const Duration(milliseconds: 1500), () {
                    _cadenceController.add(0);
                    _lastPublishedCadence = 0;
                  });
               }
            }
            _lastCrankRevs = crankRevs;
            _lastCrankTime = crankTime;
         }
      }
    }

    if (deviceId != _savedPowerId) return;
    if (data.length < 4) return;
    int power = (data[2]) | (data[3] << 8);

    // add new sample with timestamp
    final int now = DateTime.now().millisecondsSinceEpoch;
    _powerSamples.add({'ts': now, 'v': power});

    // remove old samples outside the window
    final int cutoff = now - _powerWindowMs;
    while (_powerSamples.isNotEmpty && (_powerSamples.first['ts'] ?? 0) < cutoff) {
      _powerSamples.removeAt(0);
    }

    // compute average over samples in window
    if (_powerSamples.isNotEmpty) {
      int sum = 0;
      for (final s in _powerSamples) {
        sum += (s['v'] ?? 0);
      }
      final int avg = sum ~/ _powerSamples.length;
      _powerController.add(avg);
      _lastPublishedPower = avg; // Cache for recording
    }
  }

  void _decideWhichSpeedToPublish() {
    double finalSpeed = _usingBt ? _btSpeed : _gpsSpeed;
    currentSpeedValue = finalSpeed < 0.1 ? 0.0 : finalSpeed;
    currentDistanceValue = _currentRunDistance;
    _speedController.add(currentSpeedValue);
    _distanceController.add(currentDistanceValue);
  }

  /// Start a new FIT recording session (or add lap to existing one)
  Future<void> startRecordingSession(double frontPressure, double rearPressure, {String protocol = 'coast_down'}) async {
    try {
      if (_fitWriter != null) {
        // Session already active - treat this as a new "Lap" / Run
        print('Adding run to existing FIT session: Front=$frontPressure, Rear=$rearPressure');
        await _fitWriter?.writeLap(frontPressure, rearPressure, lapIndex: -1); 
        return;
      }

      _fitWriter = await FitWriter.create(protocol: protocol);
      await _fitWriter?.startSession({
        'sportType': 'cycling',
        'subSport': 'cycling',
        'protocol': protocol,
        'frontPressure': frontPressure,
        'rearPressure': rearPressure,
        'timestamp': DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
      });
      // Log the first lap metadata
      await _fitWriter?.writeLap(frontPressure, rearPressure, lapIndex: 0);

      // START RECORDING LOOP (1Hz)
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_fitWriter == null) {
          timer.cancel();
          return;
        }

        final now = DateTime.now().toUtc();
        _fitWriter!.writeRecord({
          'ts': now.toIso8601String(),
          'speed_kmh': currentSpeedValue,
          'distance': currentDistanceValue,
          'power': _lastPublishedPower,
          'cadence': _lastPublishedCadence,
          'altitude': 0.0, // TODO: Get from GPS or Altimeter
          // 'lat': _lastLat,
          // 'lon': _lastLon, 
        });
        
        // Also capture vibration sample to fit writer (for metadata stats)
        // using _lastPublishedVibration
        // We probably only need to do this if we are moving?
        // Or store raw samples? FitWriter handles collection.
        // We need to pass the current lap index? FitWriter tracks laps internally based on writeLap calls.
        // But recordVibrationSample needs an index.
        // Let's assume FitWriter tracks "current lap". We'll modify FitWriter to be smarter or
        // we'll just expose "currentLapIndex" from FitWriter.
      });

      print('FIT recording session started: Front=$frontPressure, Rear=$rearPressure, Protocol=$protocol');
    } catch (e) {
      print('ERROR starting FIT recording session: $e');
    }
  }

  /// Stop recording and finalize the FIT file
  Future<void> stopRecordingSession() async {
    _recordingTimer?.cancel(); // STOP RECORDING LOOP
    
    try {
      if (_fitWriter == null) {
        print('WARNING: No active FIT recording session to stop');
        return;
      }
      await _fitWriter?.finish();
      print('FIT recording session finished successfully');
      _fitWriter = null;
    } catch (e) {
      print('ERROR stopping FIT recording session: $e');
    }
  }

  /// Get the current FIT writer instance (for background flush)
  FitWriter? getFitWriter() => _fitWriter;
  
  /// Get the current FIT file path (for analysis after recording)
  String? getFitFilePath() => _fitWriter?.fitPath;
}