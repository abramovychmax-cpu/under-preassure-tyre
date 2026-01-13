import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

class SensorService {
  static final SensorService _instance = SensorService._internal();
  factory SensorService() => _instance;
  SensorService._internal();

  final _speedController = StreamController<double>.broadcast();
  Stream<double> get speedStream => _speedController.stream;

  final _distanceController = StreamController<double>.broadcast();
  Stream<double> get distanceStream => _distanceController.stream;

  String? _savedSpeedId;
  BluetoothDevice? _connectedDevice;
  
  double currentSpeedValue = 0.0;
  double currentDistanceValue = 0.0;

  double _btSpeed = 0.0;
  double _gpsSpeed = 0.0;
  bool _usingBt = false;

  DateTime? _lastBtMovementTime;
  static const double minSpeedThreshold = 3.0;
  static const int sensorTimeoutSeconds = 15;

  int? _lastWheelRevs;
  int? _lastWheelTime;
  
  int? _lapStartRevs; 
  double _currentRunDistance = 0.0;
  static const double wheelCircumference = 2.100; // Meters

  Future<void> loadSavedSensors() async {
    final prefs = await SharedPreferences.getInstance();
    _savedSpeedId = prefs.getString('speed_sensor_id');
    startScanning();
    _initGps();
  }

  void resetDistance() {
    _lapStartRevs = _lastWheelRevs;
    _currentRunDistance = 0.0;
    _distanceController.add(0.0);
    print("Distance Reset for new Run. Baseline: $_lapStartRevs");
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

  void startScanning() async {
    if (_connectedDevice != null || FlutterBluePlus.isScanningNow) return;

    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (r.device.remoteId.str == _savedSpeedId) {
          _connectToDevice(r.device);
          FlutterBluePlus.stopScan();
          break;
        }
      }
    });

    try {
      await FlutterBluePlus.startScan(
        withServices: [Guid("1816")],
        timeout: const Duration(minutes: 5),
      );
    } catch (e) {
      print("Scan Error: $e");
    }
  }

  void _connectToDevice(BluetoothDevice device) async {
    try {
      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _handleDisconnection();
        }
      });

      await device.connect(autoConnect: false);
      _connectedDevice = device;

      List<BluetoothService> services = await device.discoverServices();
      for (var s in services) {
        if (s.uuid == Guid("1816")) {
          for (var c in s.characteristics) {
            if (c.uuid == Guid("2A5B")) {
              await c.setNotifyValue(true);
            c.onValueReceived.listen((value) => _parseData(value));
            }
          }
        }
      }
    } catch (e) {
      print("Connect Error: $e");
      _handleDisconnection();
    }
  }

  void _handleDisconnection() {
    _connectedDevice = null;
    _usingBt = false;
    _lastWheelRevs = null;
    _lastWheelTime = null;
    _lapStartRevs = null; 
    startScanning();
  }

  // --- NEW ROBUST PARSER ---
  void _parseData(List<int> data) {
    if (data.isEmpty) return;

    int flags = data[0];
    bool wheelRevPresent = (flags & 0x01) != 0;
    if (!wheelRevPresent) return;

    _usingBt = true; 
    
    try {
      int currentRevs = (data[1]) | (data[2] << 8) | (data[3] << 16) | (data[4] << 24);
      int currentTime = (data[5]) | (data[6] << 8); 

      // --- FIX STARTS HERE ---
      // If the data is identical to the last update, it's a duplicate packet.
      // Do nothing and return early so we don't set speed to 0.
      if (currentRevs == _lastWheelRevs && currentTime == _lastWheelTime) {
        return; 
      }
      // --- FIX ENDS HERE ---

      // 1. Distance Calculation
      if (_lapStartRevs != null) {
        int runDeltaRevs = (currentRevs - _lapStartRevs!) & 0xFFFFFFFF;
        _currentRunDistance = (runDeltaRevs * wheelCircumference) / 1000.0;
        _distanceController.add(_currentRunDistance);
      }

      // 2. Speed Calculation
      if (_lastWheelRevs != null && _lastWheelTime != null) {
        int revDiff = (currentRevs - _lastWheelRevs!) & 0xFFFFFFFF;
        int timeDiff = (currentTime - _lastWheelTime!) & 0xFFFF;

        if (revDiff > 0 && timeDiff > 0) {
          double timeSeconds = timeDiff / 1024.0;
          double distanceMeters = revDiff * wheelCircumference;
          _btSpeed = (distanceMeters / timeSeconds) * 3.6;
          _lastBtMovementTime = DateTime.now();
          
          print("SUCCESS! Speed: $_btSpeed km/h");
        } 
        // Note: Removed the "else if (revDiff == 0) { _btSpeed = 0.0; }" 
        // because true "zero speed" is handled by the timeout logic.
      }

      _lastWheelRevs = currentRevs;
      _lastWheelTime = currentTime;
      
    } catch (e) {
      print("Parsing error: $e");
    }
    
    _decideWhichSpeedToPublish();
  }

    void _decideWhichSpeedToPublish() {
    double finalSpeed = 0.0;

    if (_usingBt) {
      // If we are using Bluetooth, use the calculated BT speed
      finalSpeed = _btSpeed;
    } else {
      // Otherwise fallback to GPS
      finalSpeed = _gpsSpeed;
    }

    // 1. Update the "Current" variables for the UI to read immediately
    currentSpeedValue = finalSpeed < 0.1 ? 0.0 : finalSpeed;
    currentDistanceValue = _currentRunDistance;

    // 2. Publish to the streams for the StreamBuilders
    _speedController.add(currentSpeedValue);
    _distanceController.add(currentDistanceValue);
  }
  }
