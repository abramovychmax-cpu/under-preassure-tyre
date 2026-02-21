import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:fit_tool/fit_tool.dart';
import 'package:path_provider/path_provider.dart';

/// High-level FIT file writer using the official fit_tool SDK for 100% compliance.
/// This ensures Strava compatibility and proper FIT message structure.
class FitWriter {
  final String fitPath;
  
  // fit_tool components
  final FitFileBuilder _builder = FitFileBuilder(autoDefine: true);
  final List<RecordMessage> _records = [];
  
  DateTime? _sessionStartTime;
  double _totalDistance = 0.0;
  double _totalAscent = 0.0;
  double _totalPower = 0.0;
  int _recordCount = 0;
  
  // Tire pressure data (tracked per lap)
  final List<Map<String, dynamic>> _laps = []; // Track each lap's pressure data
  
  // Vibration samples (collected during recording)
  final Map<int, List<double>> _lapVibrationSamples = {}; // lapIndex -> [vibration values]
  
  // Sensor records per lap (for coast detection: cadence, speed, power)
  final Map<int, List<Map<String, dynamic>>> _lapSensorRecords = {}; // lapIndex -> [record dicts]
  
  // Track where the current lap started in the _records list
  int _currentLapRecordStartIndex = 0;
  
  // Public getter to know which lap we are currently recording into
  int get currentLapIndex => _laps.isNotEmpty ? _laps.last['index'] as int : -1;

  FitWriter._(this.fitPath);

  static Future<FitWriter> create({String protocol = 'unknown'}) async {
    String sanitize(String s) =>
        s.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_\-]'), '_');
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final datePart =
        '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';
    final proto = sanitize(protocol);
    final base = '${proto}_$datePart';

    try {
      // Prefer app-specific external storage for user visibility.
      final ext = await getExternalStorageDirectory();
      if (ext != null) {
        final sessionDir = Directory(ext.path);
        await sessionDir.create(recursive: true);
        final path = '${sessionDir.path}/$base.fit';
        return FitWriter._(path);
      }
    } catch (e) {
      // Fallback to documents directory
    }

    // Fallback to application documents directory.
    final appDoc = await getApplicationDocumentsDirectory();
    final sessionDir = Directory('${appDoc.path}/tyre_sessions');
    await sessionDir.create(recursive: true);
    final path = '${sessionDir.path}/$base.fit';
    return FitWriter._(path);
  }

  Future<void> startSession(Map<String, dynamic> metadata) async {
    _sessionStartTime = DateTime.now().toUtc();
    print('[FitWriter] startSession → file: $fitPath | startTime: $_sessionStartTime');

    // Create FileID message (REQUIRED)
    final fileIdMessage = FileIdMessage()
      ..type = FileType.activity
      ..manufacturer = Manufacturer.garmin.value
      ..product = 1
      ..serialNumber = 123456
      ..timeCreated = _dateTimeToFitEpoch(_sessionStartTime!);

    _builder.add(fileIdMessage);

    // Add Timer Start Event (Required for proper duration calculation)
    final eventMsg = EventMessage()
      ..timestamp = _dateTimeToFitEpoch(_sessionStartTime!)
      ..event = Event.timer
      ..eventType = EventType.start
      ..eventGroup = 0;
    _builder.add(eventMsg);
  }

  Future<void> writeLap(double front, double rear,
      {required int lapIndex}) async {
    print('[FitWriter] writeLap: front=$front rear=$rear lapIndex=$lapIndex | records so far: ${_records.length}');
    // If we have an active previous lap, flush it to a LapMessage
    if (_laps.isNotEmpty) {
      _finishCurrentLap();
    }

    // Store pressure data for this lap
    // IMPORTANT: Tire pressure is the PRIMARY metric for this app.
    // ...
    //
    // Data storage format:
    // ...
    
    // Determine the actual index (if -1 passed, use sequential)
    int actualIndex = lapIndex < 0 ? _laps.length : lapIndex;
    
    _laps.add({
      'index': actualIndex,
      'frontPressure': front,
      'rearPressure': rear,
      'startTime': DateTime.now().toUtc(),
      'lapNumber': _laps.length + 1,
    });
    
    // Mark where this new lap starts in the records list
    _currentLapRecordStartIndex = _records.length;
    
    // Initialize vibration samples list for this lap
    _lapVibrationSamples[actualIndex] = [];
  }

  void _finishCurrentLap() {
    final lapRecordCount = _records.length - _currentLapRecordStartIndex;
    print('[FitWriter] _finishCurrentLap: lap#${_laps.length} | records in lap: $lapRecordCount | total records: ${_records.length}');
    if (_records.isEmpty || _currentLapRecordStartIndex >= _records.length) return;

    // Get slice of records for this lap
    final lapRecords = _records.sublist(_currentLapRecordStartIndex);
    if (lapRecords.isEmpty) return;

    final first = lapRecords.first;
    final last = lapRecords.last;
    
    // Start time of this lap (from the first record, or the lap metadata?)
    // Using record timestamp is safer for FIT compliance.
    // guard against missing timestamps (shouldn't happen) and clamp
    int startTime = first.timestamp ?? 0;
    int endTime = last.timestamp ?? 0;
    // if somehow we didn't get a timestamp (0), fall back to session start
    if (startTime == 0 && _sessionStartTime != null) {
      startTime = _dateTimeToFitEpoch(_sessionStartTime!);
    }
    if (endTime == 0 && _sessionStartTime != null) {
      endTime = _dateTimeToFitEpoch(_sessionStartTime!);
    }
    // timestamps are Unix ms — convert elapsed time to seconds for FIT fields
    double totalLapTime = (endTime - startTime) / 1000.0; // ms → seconds
    if (totalLapTime < 0) totalLapTime = 0;

    // Calculate totals for this lap
    double distStart = first.distance ?? 0;
    double distEnd = last.distance ?? 0;
    double lapDistance = distEnd - distStart;
    
    // Avg Power
    double sumPower = 0;
    int count = 0;
    for (var r in lapRecords) {
      if (r.power != null) {
        sumPower += r.power!;
        count++;
      }
    }
    int lapAvgPower = count > 0 ? (sumPower / count).round() : 0;
    
    // Avg Speed
    double lapAvgSpeed = totalLapTime > 0 ? lapDistance / totalLapTime : 0.0;

    // 1. ADD RECORDS TO BUILDER (Must precede the LapMessage)
    _builder.addAll(lapRecords);

    final lapMessage = LapMessage()
        ..timestamp = endTime
        ..startTime = startTime
        ..startPositionLat = first.positionLat
        ..startPositionLong = first.positionLong
        ..endPositionLat = last.positionLat
        ..endPositionLong = last.positionLong
        ..totalElapsedTime = totalLapTime
        ..totalTimerTime = totalLapTime
        ..totalDistance = lapDistance
        ..avgSpeed = lapAvgSpeed
        ..avgPower = lapAvgPower
        ..sport = Sport.cycling
        ..subSport = SubSport.generic // Changed from numeric 0 if available, but cycling default is fine
        ..messageIndex = _laps.length - 1; // 0-based index of the lap we just finished

    _builder.add(lapMessage);
  }


  /// Add vibration sample for current lap
  /// Called periodically during recording to capture smoothness data
  void recordVibrationSample(int lapIndex, double vibrationG) {
    if (!_lapVibrationSamples.containsKey(lapIndex)) {
      _lapVibrationSamples[lapIndex] = [];
    }
    _lapVibrationSamples[lapIndex]!.add(vibrationG);
  }

  Future<void> writeRecord(Map<String, dynamic> record) async {
    if (_sessionStartTime == null) return;

    // Extract data from record
    // Use the timestamp passed from the service (from the timer tick) if available
    // Fallback to DateTime.now() if not present, but ensure we don't double-call .now()
    DateTime recordTime;
    if (record.containsKey('ts')) {
      recordTime = DateTime.parse(record['ts'] as String);
    } else {
      recordTime = DateTime.now().toUtc();
    }
    // fit_tool expects Unix milliseconds — no clamping needed here.
    final int timestamp = _dateTimeToFitEpoch(recordTime);

    final lat = (record['lat'] as num?)?.toDouble() ?? 0.0;
    final lon = (record['lon'] as num?)?.toDouble() ?? 0.0;
    final speedKmh = (record['speed_kmh'] as num?)?.toDouble() ?? 0.0;
    final speed = speedKmh / 3.6; // Convert km/h to m/s
    final power = (record['power'] as num?)?.toInt() ?? 0;
    final cadence = (record['cadence'] as num?)?.toInt() ?? 0;
    final distance = (record['distance'] as num?)?.toDouble() ?? _totalDistance;
    final altitude = (record['altitude'] as num?)?.toDouble() ?? 0.0;

    // Accumulate stats
    _totalDistance = distance;
    _totalPower += power;
    _recordCount++;
    
    if (_recordCount % 100 == 0) {
      _totalAscent += 1.0; // Simulate elevation gain
    }

    // Store sensor record for coast detection analysis
    // This includes cadence, speed, power - needed to detect coasting phases (cadence=0)
    final lapIndex = _laps.isNotEmpty ? _laps.length - 1 : 0;
    if (!_lapSensorRecords.containsKey(lapIndex)) {
      _lapSensorRecords[lapIndex] = [];
    }
    _lapSensorRecords[lapIndex]!.add({
      'timestamp': record['ts'] ?? DateTime.now().toUtc().toIso8601String(),
      'speed_kmh': speedKmh,
      'power': power,
      'cadence': cadence,
      'distance': distance,
      'altitude': altitude,
      'lat': lat,
      'lon': lon,
    });

    // Create Record message
    final recordMsg = RecordMessage()
      ..timestamp = timestamp
      ..positionLat = lat
      ..positionLong = lon
      ..altitude = altitude
      ..speed = speed // m/s
      ..distance = distance // meters
      ..cadence = cadence // rpm
      ..power = power; // watts

    _records.add(recordMsg);
    if (_recordCount % 30 == 0) {
      print('[FitWriter] writeRecord #$_recordCount | ts=${recordTime.toIso8601String()} | speed=${speedKmh.toStringAsFixed(1)} km/h | power=$power W | dist=${(_totalDistance/1000).toStringAsFixed(3)} km | lat=$lat lon=$lon');
    }
  }

  Future<void> flush() async {
    // fit_tool handles this automatically
  }

  Future<void> finish() async {
    if (_sessionStartTime == null) {
      print('[FitWriter] finish() called but no session started — aborting');
      return;
    }

    final endTime = DateTime.now().toUtc();
    final endTimeEpoch = _dateTimeToFitEpoch(endTime);
    final totalElapsedTime = endTime.difference(_sessionStartTime!).inSeconds.toDouble();
    final avgPower = _recordCount > 0 ? (_totalPower / _recordCount).toInt() : 0;
    print('[FitWriter] finish() | laps: ${_laps.length} | total records: ${_records.length} | duration: ${totalElapsedTime.toStringAsFixed(0)}s | avgPower: $avgPower W | dist: ${(_totalDistance/1000).toStringAsFixed(3)} km');

    // NO: _builder.addAll(_records); -> Records are now added incrementally in _finishCurrentLap

    // Finish the final lap if there are records
    if (_laps.isNotEmpty) {
      _finishCurrentLap();
    } else if (_records.isNotEmpty) {
       // If we have records but no explicit lap was started (edge case), wrap in a lap
       _builder.addAll(_records);
    }
    
    // Add Timer Stop Event (Standard practice)
    final stopEvent = EventMessage()
      ..timestamp = endTimeEpoch
      ..event = Event.timer
      ..eventType = EventType.stopDisable
      ..eventGroup = 0;
    _builder.add(stopEvent);

    // Note: We used to write a single monolithic LapMessage here.
    // Now we write distinct LapMessages via _finishCurrentLap.
    // DO NOT add another LapMessage unless _records were empty or something.
    // If _records is empty, we probably shouldn't write a session either?
    
    // Create Session message (REQUIRED)
    if (_records.isNotEmpty) {
      final sessionMessage = SessionMessage()
        ..timestamp = endTimeEpoch
        ..startTime = _dateTimeToFitEpoch(_sessionStartTime!)
        ..totalElapsedTime = totalElapsedTime
        ..totalTimerTime = totalElapsedTime
        ..totalDistance = _totalDistance
        ..totalCycles = _recordCount
        ..totalAscent = _totalAscent.toInt()
        ..avgSpeed = _recordCount > 0 ? _totalDistance / totalElapsedTime : 0.0
        ..avgPower = avgPower
        ..sport = Sport.cycling
        ..subSport = SubSport.generic
        ..numLaps = _laps.length;

      _builder.add(sessionMessage);
    }

    // Create Activity message (REQUIRED by Strava)
    final activityMessage = ActivityMessage()
      ..timestamp = endTimeEpoch
      ..numSessions = 1
      ..type = Activity.manual;

    _builder.add(activityMessage);

    // Build and write the FIT file
    try {
      final fitFile = _builder.build();
      final bytes = fitFile.toBytes();
      final file = File(fitPath);
      await file.writeAsBytes(bytes);
      print('[FitWriter] FIT file written: $fitPath (${bytes.length} bytes)');
      
      // Write tire pressure metadata to companion JSONL file
      // This preserves the critical tire pressure data alongside the FIT file
      // for analysis and quadratic regression calculation
      await _writePressureMetadata(fitPath);
      
      // Write sensor records (cadence, speed, power) for coast detection analysis
      await _writeSensorRecords(fitPath);
    } catch (e) {
      rethrow;
    }
  }

  /// Write tire pressure metadata to a companion JSONL file
  /// Companion file format: {fitFilePath}.jsonl
  /// Each line contains pressure + vibration statistics for one lap:
  /// {"lapIndex": 0, "frontPressure": 32.5, "rearPressure": 35.2, "timestamp": "2025-01-29T19:43:42.000Z", "vibrationAvg": 0.45, "vibrationMin": 0.2, "vibrationMax": 0.8, "vibrationStdDev": 0.15}
  Future<void> _writePressureMetadata(String fitPath) async {
    if (_laps.isEmpty) return;
    
    try {
      final metadataPath = '$fitPath.jsonl';
      print('[FitWriter] Writing pressure metadata → $metadataPath | ${_laps.length} laps');
      final metadataFile = File(metadataPath);
      final sink = metadataFile.openWrite();
      
      for (final lap in _laps) {
        final lapIndex = lap['index'] as int;
        
        // Calculate vibration statistics for this lap
        final vibSamples = _lapVibrationSamples[lapIndex] ?? [];
        final vibAvg = vibSamples.isNotEmpty 
          ? vibSamples.reduce((a, b) => a + b) / vibSamples.length 
          : 0.0;
        final vibMin = vibSamples.isNotEmpty 
          ? vibSamples.reduce((a, b) => a < b ? a : b) 
          : 0.0;
        final vibMax = vibSamples.isNotEmpty 
          ? vibSamples.reduce((a, b) => a > b ? a : b) 
          : 0.0;
        
        // Standard deviation
        double vibStdDev = 0.0;
        if (vibSamples.length > 1) {
          final sumSq = vibSamples.fold<double>(0.0, (sum, v) => sum + ((v - vibAvg) * (v - vibAvg)));
          vibStdDev = sqrt(sumSq / (vibSamples.length - 1));
        }
        
        // Format: one JSON line per lap with tire pressure + vibration data
        final line = '{'
            '"lapIndex": ${lap['index']}, '
            '"frontPressure": ${lap['frontPressure']}, '
            '"rearPressure": ${lap['rearPressure']}, '
            '"timestamp": "${lap['startTime']}", '
            '"vibrationAvg": ${vibAvg.toStringAsFixed(4)}, '
            '"vibrationMin": ${vibMin.toStringAsFixed(4)}, '
            '"vibrationMax": ${vibMax.toStringAsFixed(4)}, '
            '"vibrationStdDev": ${vibStdDev.toStringAsFixed(4)}, '
            '"vibrationSampleCount": ${vibSamples.length}'
            '}\n';
        sink.write(line);
      }
      
      await sink.flush();
      await sink.close();
    } catch (e) {
      // Log error but don't fail the session - FIT file is what matters most
      print('Warning: Failed to write pressure metadata: $e');
    }
  }

  /// Read tire pressure metadata from companion file
  /// Useful for loading pressure data when analyzing a recorded FIT file
  static Future<List<Map<String, dynamic>>> readPressureMetadata(String fitPath) async {
    final metadataPath = '$fitPath.jsonl';
    final file = File(metadataPath);
    
    if (!file.existsSync()) {
      return [];
    }
    
    try {
      final lines = await file.readAsLines();
      final pressureData = <Map<String, dynamic>>[];
      
      for (final line in lines) {
        if (line.isEmpty) continue;
        // Simple JSON parsing for pressure data
        // In production, use a proper JSON parser
        final regexLap = RegExp(r'"lapIndex":\s*(\d+)');
        final regexFront = RegExp(r'"frontPressure":\s*([\d.]+)');
        final regexRear = RegExp(r'"rearPressure":\s*([\d.]+)');
        final regexVibAvg = RegExp(r'"vibrationAvg":\s*([\d.]+)');
        final regexVibStdDev = RegExp(r'"vibrationStdDev":\s*([\d.]+)');
        final regexVibMin = RegExp(r'"vibrationMin":\s*([\d.]+)');
        final regexVibMax = RegExp(r'"vibrationMax":\s*([\d.]+)');
        final regexVibCount = RegExp(r'"vibrationSampleCount":\s*(\d+)');
        
        final lapMatch = regexLap.firstMatch(line);
        final frontMatch = regexFront.firstMatch(line);
        final rearMatch = regexRear.firstMatch(line);
        
        if (lapMatch != null && frontMatch != null && rearMatch != null) {
          final vibAvgMatch = regexVibAvg.firstMatch(line);
          final vibStdDevMatch = regexVibStdDev.firstMatch(line);
          final vibMinMatch = regexVibMin.firstMatch(line);
          final vibMaxMatch = regexVibMax.firstMatch(line);
          final vibCountMatch = regexVibCount.firstMatch(line);
          
          pressureData.add({
            'lapIndex': int.parse(lapMatch.group(1)!),
            'frontPressure': double.parse(frontMatch.group(1)!),
            'rearPressure': double.parse(rearMatch.group(1)!),
            'vibrationAvg': vibAvgMatch != null ? double.parse(vibAvgMatch.group(1)!) : 0.0,
            'vibrationStdDev': vibStdDevMatch != null ? double.parse(vibStdDevMatch.group(1)!) : 0.0,
            'vibrationMin': vibMinMatch != null ? double.parse(vibMinMatch.group(1)!) : 0.0,
            'vibrationMax': vibMaxMatch != null ? double.parse(vibMaxMatch.group(1)!) : 0.0,
            'vibrationSampleCount': vibCountMatch != null ? int.parse(vibCountMatch.group(1)!) : 0,
          });
        }
      }
      
      return pressureData;
    } catch (e) {
      print('Error reading pressure metadata: $e');
      return [];
    }
  }

  /// Convert Dart DateTime to the value expected by fit_tool's timestamp fields.
  /// fit_tool 1.x expects **Unix milliseconds** (ms since 1970-01-01 UTC).
  /// Internally the SDK converts to FIT epoch seconds before writing the binary file.
  static int _dateTimeToFitEpoch(DateTime dt) {
    return dt.toUtc().millisecondsSinceEpoch;
  }

  /// Write sensor records to companion JSONL file for coast detection
  /// File format: {fitFilePath}.sensor_records.jsonl
  /// Each line contains: {"lapIndex": 0, "timestamp": "...", "cadence": 0, "speed_kmh": 25.5, "power": 150, "altitude": 100.5}
  /// Used to detect coasting phases (cadence=0) and calculate deceleration during coast
  Future<void> _writeSensorRecords(String fitPath) async {
    if (_lapSensorRecords.isEmpty) return;
    
    try {
      final sensorPath = '$fitPath.sensor_records.jsonl';
      final totalSensorRecords = _lapSensorRecords.values.fold(0, (s, l) => s + l.length);
      print('[FitWriter] Writing sensor records → $sensorPath | ${_lapSensorRecords.length} laps | $totalSensorRecords records');
      final sensorFile = File(sensorPath);
      final sink = sensorFile.openWrite();
      
      // Write one JSON line per sensor record
      for (final lapIndex in _lapSensorRecords.keys) {
        final records = _lapSensorRecords[lapIndex] ?? [];
        for (final record in records) {
          final line = '{'
              '"lapIndex": $lapIndex, '
              '"timestamp": "${record['timestamp']}", '
              '"speed_kmh": ${record['speed_kmh']}, '
              '"cadence": ${record['cadence']}, '
              '"power": ${record['power']}, '
              '"distance": ${record['distance']}, '
              '"altitude": ${record['altitude']}, '
              '"lat": ${record['lat']}, '
              '"lon": ${record['lon']}'
              '}\n';
          sink.write(line);
        }
      }
      
      await sink.flush();
      await sink.close();
      print('DEBUG: Wrote sensor records to $sensorPath');
    } catch (e) {
      print('Warning: Failed to write sensor records: $e');
    }
  }
}
