import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'fit_writer.dart';
import 'weather_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/widgets.dart';

class SensorService with WidgetsBindingObserver {
  static final SensorService _instance = SensorService._internal();
  factory SensorService() => _instance;
  SensorService._internal() {
    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {}
  }

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

  final _positionController = StreamController<Position>.broadcast();
  Stream<Position> get positionStream => _positionController.stream;

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
  
  // Track last FIT file path for analysis
  String? _lastRecordingPath;
  static const double wheelCircumference = 2.100; // Meters (default)
  late double _customWheelCircumference = 2.100; // Will be loaded from settings

  Timer? _stopTimer;
  Timer? _uiPublisherTimer;
  int _lastPublishedCadence = 0;
  int _lastPublishedPower = 0;
  StreamSubscription? _accelSub;
  // Recording
  bool _isRecording = false;
  FitWriter? _fitWriter;
  final List<StreamSubscription> _recordingSubs = [];
  int _lapIndex = 0;
  
  // Weather service for temperature and atmospheric pressure
  final WeatherService _weatherService = WeatherService();

  // --- INITIALIZATION ---
  Future<void> loadSavedSensors() async {
    final prefs = await SharedPreferences.getInstance();
    _savedSpeedId = prefs.getString('speed_sensor_id');
    _savedPowerId = prefs.getString('power_sensor_id');
    _savedCadenceId = prefs.getString('cadence_sensor_id');
    
    // Load custom wheel circumference from settings
    _customWheelCircumference = prefs.getDouble('wheel_circumference') ?? wheelCircumference;

    print("LOADED SENSORS: Speed($_savedSpeedId), Power($_savedPowerId), Cadence($_savedCadenceId)");
    print("LOADED WHEEL CIRCUMFERENCE: ${_customWheelCircumference}m");
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
    _accelSub = accelerometerEvents.listen((event) {
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
        
        // If recording, pass vibration sample to FitWriter for per-second aggregation
        if (_isRecording && _fitWriter != null) {
          _fitWriter!.recordVibrationSample(_lapIndex, g);
        }
      }
    });
  }

  /// Start recording session: opens writer, writes initial metadata and subscribes
  /// to sensor streams. The writer currently writes JSONL + placeholder .fit.
  Future<void> startRecordingSession(double frontPsi, double rearPsi, {String protocol = 'unknown'}) async {
    if (_isRecording) return;

    // Create a single FitWriter for the whole analysis session. If a writer
    // already exists, reuse it so multiple runs (laps) end up in the same
    // FIT file. Only initialize metadata once on the first run.
    if (_fitWriter == null) {
      _fitWriter = await FitWriter.create(protocol: protocol);
      await _fitWriter!.startSession({'protocol': protocol, 'wheel_circumference_m': _customWheelCircumference});
      _lapIndex = 0;
    } else {
      // increment lap index for subsequent runs
      _lapIndex = (_lapIndex) + 1;
    }

    await _fitWriter!.writeLap(frontPsi, rearPsi, lapIndex: _lapIndex);

    // Instead of writing separate records per sensor, consolidate into periodic combined records
    // This ensures GPS coordinates appear with speed/power/cadence in Strava
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isRecording) {
        timer.cancel();
        return;
      }
      
      // Write one combined record per second with ALL current values
      _fitWriter?.writeRecord({
        'ts': DateTime.now().toUtc().toIso8601String(),
        'lat': _lastGpsLat,
        'lon': _lastGpsLon,
        'altitude': (_lastGpsAlt ?? 0).round(),
        'speed_kmh': currentSpeedValue,
        'distance': (currentDistanceValue * 1000).round(), // km to meters
        'power': _lastPublishedPower,
        'cadence': _lastPublishedCadence,
        'temperature': _weatherService.getTemperature(),
        'atmospheric_pressure': _weatherService.getAtmosphericPressurePa(),
        'front_psi': frontPsi,
        'rear_psi': rearPsi,
        'vibration': 0.0, // TODO: add vibration if available
      });
    });

    _isRecording = true;
  }

  // Track last GPS values for consolidation
  double? _lastGpsLat;
  double? _lastGpsLon;
  double? _lastGpsAlt;


  /// Stop recording session and finalize writer
  Future<void> stopRecordingSession() async {
    if (!_isRecording) return;
    for (final s in _recordingSubs) {
      await s.cancel();
    }
    _recordingSubs.clear();
    // Do not finalize the writer here: keep the session writer alive so
    // multiple runs (laps) are appended to the same FIT/JSONL. Call
    // `finalizeRecordingSession()` when the user finishes the analysis.
    _isRecording = false;
  }

  /// Finalize and export the current recording session. This should be
  /// called once the user has completed all runs and wants to export a
  /// single FIT containing all laps.
  Future<void> finalizeRecordingSession() async {
    try {
      await _fitWriter?.finish();
      _lastRecordingPath = _fitWriter?.fitPath;
    } catch (_) {}
    _fitWriter = null;
  }

  /// Get the path to the last recording's FIT file
  String? getLastRecordingPath() => _lastRecordingPath;

  double getWheelCircumference() => _customWheelCircumference;

  /// Get the current FIT writer for flushing data during background operations
  FitWriter? getFitWriter() => _fitWriter;

  void _emitConnectedNames() {
    String resolveIfConnected(String? id) {
      if (id == null) return '';
      // Only show a name if the device is currently connected
      final connected = _connectedDevices[id];
      if (connected == null) return '';
      // Prefer cached advertisement name, then device.name, else fallback to id
      final cached = _deviceNames[id];
      if (cached != null && cached.isNotEmpty) return cached;
      try {
        final devName = connected.name;
        if (devName.isNotEmpty) return devName;
      } catch (_) {}
      return id;
    }

    final Map<String, String> out = {
      'speed': resolveIfConnected(_savedSpeedId),
      'power': resolveIfConnected(_savedPowerId),
      'cadence': resolveIfConnected(_savedCadenceId),
    };
    _connectedNamesController.add(out);
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
    _lapStartRevs = _lastWheelRevs;
    _currentRunDistance = 0.0;
    _distanceController.add(0.0);
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
      
      // Update last GPS position for consolidated recording
      _lastGpsLat = position.latitude;
      _lastGpsLon = position.longitude;
      _lastGpsAlt = position.altitude;
      
      // Fetch weather data based on GPS location (rate-limited to once per 10 min)
      _weatherService.updateWeather(position.latitude, position.longitude);
      
      // emit raw position for consumers
      try {
        _positionController.add(position);
      } catch (_) {}
      _decideWhichSpeedToPublish();
    });
  }

  // --- BLUETOOTH CORE ---
  void startScanning() async {
    if (FlutterBluePlus.isScanningNow) return;

    FlutterBluePlus.scanResults.listen((results) {
      // cache display names from recent scan results so we can show them when connected
      for (final r in results) {
        final name = r.advertisementData.localName;
        if (name.isNotEmpty) {
          _deviceNames[r.device.remoteId.str] = name;
        }
      }
      // emit any newly discovered friendly names so UI updates from MAC -> name
      _emitConnectedNames();
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

    // For cadence, accept both CSC (0x1816) and Power (0x1818) services
    // since many power meters include cadence data
    List<Guid> targetServices = [];
    if (targetSlot == "power") {
      targetServices = [Guid("1818")];
    } else if (targetSlot == "cadence") {
      targetServices = [Guid("1816"), Guid("1818")]; // CSC or Power with cadence
    } else {
      targetServices = [Guid("1816")]; // speed: CSC only
    }

    FlutterBluePlus.scanResults.listen((results) {
      var filtered = results.where((r) {
        final lname = r.advertisementData.localName;
        final services = r.advertisementData.serviceUuids.map((s) => s.toString()).join(',');
        print('Scan result: ${r.device.remoteId.str} name="$lname" services=[$services]');
        
        if (lname.isNotEmpty) {
          _deviceNames[r.device.remoteId.str] = lname;
        }
        // Accept devices with any matching service
        final matches = targetServices.any((service) => r.advertisementData.serviceUuids.contains(service));
        if (matches) print('  -> MATCHED for slot $targetSlot');
        return matches;
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
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // flush writer when app pauses or goes inactive to reduce data loss
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      try {
        _fitWriter?.flush();
      } catch (_) {}
    }
  }

  // --- REFACTORED PARSERS ---

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
          _btSpeed = ((revDiff * _customWheelCircumference) / (timeDiff / 1024.0)) * 3.6;

          // update distance (use lap baseline)
          if (_lapStartRevs != null) {
            int runDeltaRevs = (currentRevs - _lapStartRevs!) & 0xFFFFFFFF;
            _currentRunDistance = (runDeltaRevs * _customWheelCircumference) / 1000.0;
          }

          // only cancel/restart the stop timer when real motion occurred
          _stopTimer?.cancel();
          _stopTimer = Timer(const Duration(seconds: 3), () {
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

    if (hasCrank && deviceId == _savedCadenceId) {
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
            print('CSC crank: device=$deviceId rpm=${rpm.toStringAsFixed(1)}');
            
            // reset crank stop timer so we set cadence to zero when pedaling stops
            _crankStopTimer?.cancel();
            _crankStopTimer = Timer(const Duration(seconds: 2), () {
              _cadenceController.add(0);
              _lastPublishedCadence = 0;
            });
          }
        } else {
          // First sample: start the stop timer
          _crankStopTimer?.cancel();
          _crankStopTimer = Timer(const Duration(seconds: 2), () {
            _cadenceController.add(0);
            _lastPublishedCadence = 0;
          });
        }
        _lastCrankRevs = currentCrankRevs;
        _lastCrankTime = currentCrankTime;
      }
    }
  }

  void _parsePower(List<int> data, String deviceId) {
    // Check if this device is assigned to power or cadence
    final bool isPowerDevice = deviceId == _savedPowerId;
    final bool isCadenceDevice = deviceId == _savedCadenceId;
    if (!isPowerDevice && !isCadenceDevice) return;
    
    if (data.length < 4) return;
    
    // Parse flags (bytes 0-1)
    int flags = data[0] | (data[1] << 8);
    bool hasCrankRevData = (flags & 0x20) != 0; // bit 5: Crank Revolution Data Present
    
    // Parse power (bytes 2-3) if device is assigned to power slot
    if (isPowerDevice) {
      int power = (data[2]) | (data[3] << 8);
      print('Power meter raw: device=$deviceId bytes=[${data.sublist(0, 4).map((b) => b.toRadixString(16).padLeft(2, "0")).join(" ")}] power=$power watts');

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
        _lastPublishedPower = avg;
        _powerController.add(avg);
      }
    }
    
    // Parse cadence (bytes 4-7: cumulative crank revs + last crank time) if present and device assigned to cadence
    if (isCadenceDevice && hasCrankRevData && data.length >= 8) {
      int crankRevs = (data[4]) | (data[5] << 8);
      int crankTime = (data[6]) | (data[7] << 8); // 1/1024 second resolution
      
      print('Power meter cadence raw: revs=$crankRevs time=$crankTime (last: revs=$_lastCrankRevs time=$_lastCrankTime)');
      
      if (_lastCrankRevs != null) {
        int revDiff = (crankRevs - _lastCrankRevs!) & 0xFFFF;
        int timeDiff = (crankTime - _lastCrankTime!) & 0xFFFF;
        
        // Require minimum time delta to avoid huge RPM values from tiny time differences
        // 1024 units = 1 second, so 20 units = ~20ms minimum
        if (revDiff > 0 && timeDiff >= 20) {
          double rpm = (revDiff * 60 * 1024) / timeDiff;
          int rpmInt = rpm.toInt();
          
          // Sanity check: cadence should be 0-250 RPM for cycling
          if (rpmInt > 250) {
            print('Power meter cadence REJECTED: rpm=$rpmInt (revDiff=$revDiff timeDiff=$timeDiff) - value too high');
          } else {
            _cadenceController.add(rpmInt);
            _lastPublishedCadence = rpmInt;
            print('Power meter cadence: device=$deviceId rpm=${rpm.toStringAsFixed(1)}');
            
            // reset crank stop timer
            _crankStopTimer?.cancel();
            _crankStopTimer = Timer(const Duration(seconds: 2), () {
              _cadenceController.add(0);
              _lastPublishedCadence = 0;
            });
          }
        } else {
          print('Power meter cadence skipped: revDiff=$revDiff timeDiff=$timeDiff (minimum timeDiff=20)');
        }
      } else {
        print('Power meter cadence: first sample, establishing baseline');
        // First sample: start the stop timer
        _crankStopTimer?.cancel();
        _crankStopTimer = Timer(const Duration(seconds: 2), () {
          _cadenceController.add(0);
          _lastPublishedCadence = 0;
        });
      }
      
      // Update baseline for next comparison
      _lastCrankRevs = crankRevs;
      _lastCrankTime = crankTime;
    }
  }

  void _decideWhichSpeedToPublish() {
    double finalSpeed = _usingBt ? _btSpeed : _gpsSpeed;
    currentSpeedValue = finalSpeed < 0.1 ? 0.0 : finalSpeed;
    currentDistanceValue = _currentRunDistance;
    _speedController.add(currentSpeedValue);
    _distanceController.add(currentDistanceValue);
  }

  /// Export any existing session files from the app documents `tyre_sessions`
  /// directory to `/sdcard/tyre_sessions` so they are visible in the phone
  /// file explorer. Returns true if at least one file was copied.
  Future<bool> exportSessionsToSdcard() async {
    try {
      final appDoc = await getApplicationDocumentsDirectory();
      final src = Directory('${appDoc.path}/tyre_sessions');
      if (!await src.exists()) return false;

      // prefer external storage provided by path_provider (app-specific);
      // only attempt to write to public locations if we have storage
      // permission (or manageExternalStorage on modern Android).
      String? extBase;
      try {
        final ext = await getExternalStorageDirectory();
        extBase = ext?.path;
      } catch (_) {}

      bool publicAllowed = true;
      if (Platform.isAndroid) {
        // request manageExternalStorage first (Android 11+), else legacy storage
        if (!await Permission.manageExternalStorage.isGranted) {
          final res = await Permission.manageExternalStorage.request();
          if (!res.isGranted) {
            final res2 = await Permission.storage.request();
            if (!res2.isGranted) publicAllowed = false;
          }
        }
      }

      final candidates = <String?>[extBase];
      if (publicAllowed) candidates.addAll(['/storage/emulated/0', '/sdcard']);

      for (final base in candidates) {
        if (base == null) continue;
        try {
          final destRoot = Directory('$base/tyre_sessions');
          await destRoot.create(recursive: true);

          bool copiedAnything = false;
          await for (final entity in src.list(recursive: true)) {
            if (entity is File) {
              try {
                final rel = entity.path.substring(src.path.length + 1);
                final destPath = '${destRoot.path}/$rel';
                final destDir = Directory(p.dirname(destPath));
                await destDir.create(recursive: true);
                await entity.copy(destPath);
                copiedAnything = true;
              } catch (_) {
                // ignore single-file errors
              }
            }
          }
          if (copiedAnything) return true;
        } catch (_) {
          // try next candidate
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Export sessions and return a list of destination paths that were copied.
  /// Useful for debugging export failures from the UI.
  Future<List<String>> exportSessionsReport() async {
    final List<String> copied = [];
    try {
      final appDoc = await getApplicationDocumentsDirectory();
      final src = Directory('${appDoc.path}/tyre_sessions');
      if (!await src.exists()) return copied;

      String? extBase;
      try {
        final ext = await getExternalStorageDirectory();
        extBase = ext?.path;
      } catch (_) {}

      bool publicAllowed = true;
      if (Platform.isAndroid) {
        if (!await Permission.manageExternalStorage.isGranted) {
          final res = await Permission.manageExternalStorage.request();
          if (!res.isGranted) {
            final res2 = await Permission.storage.request();
            if (!res2.isGranted) publicAllowed = false;
          }
        }
      }

      final candidates = <String?>[extBase];
      if (publicAllowed) candidates.addAll(['/storage/emulated/0', '/sdcard']);

      for (final base in candidates) {
        if (base == null) continue;
        try {
          final destRoot = Directory('$base/tyre_sessions');
          await destRoot.create(recursive: true);

          await for (final entity in src.list(recursive: true)) {
            if (entity is File) {
              try {
                final rel = entity.path.substring(src.path.length + 1);
                final destPath = '${destRoot.path}/$rel';
                final destDir = Directory(p.dirname(destPath));
                await destDir.create(recursive: true);
                await entity.copy(destPath);
                copied.add(destPath);
              } catch (_) {
                // ignore single-file copy errors
              }
            }
          }
          if (copied.isNotEmpty) return copied;
        } catch (_) {
          // try next candidate
        }
      }
      return copied;
    } catch (e) {
      return copied;
    }
  }
}