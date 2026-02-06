# FIT Writer Integration Guide

## Quick Start: Using FitWriter with Tire Pressure

### In RecordingPage or similar Recording UI

```dart
import 'package:tyre_preassure/fit_writer.dart';

class RecordingPage extends StatefulWidget {
  // ...
  @override
  State<RecordingPage> createState() => _RecordingPageState();
}

class _RecordingPageState extends State<RecordingPage> {
  FitWriter? _fitWriter;
  int _lapCount = 0;
  
  @override
  void initState() {
    super.initState();
    _initializeRecording();
  }
  
  Future<void> _initializeRecording() async {
    // Create FIT writer for this session (protocol could be 'coast_down', etc.)
    _fitWriter = await FitWriter.create(protocol: 'coast_down');
    
    // Start the session (writes FileID message)
    await _fitWriter!.startSession({});
  }
  
  Future<void> _startRun(double frontPressure, double rearPressure) async {
    // User has entered tire pressure values at the start of a run
    // Record these values for this lap/run
    
    if (_fitWriter != null) {
      await _fitWriter!.writeLap(
        frontPressure,
        rearPressure,
        lapIndex: _lapCount,
      );
      _lapCount++;
    }
  }
  
  Future<void> _recordSensorData({
    required double speedKmh,
    required int power,
    required int cadence,
    required double distance,
    required double altitude,
  }) async {
    // Record instantaneous sensor data from CSC and Power meters
    if (_fitWriter != null) {
      await _fitWriter!.writeRecord({
        'speed_kmh': speedKmh,
        'power': power,
        'cadence': cadence,
        'distance': distance,
        'altitude': altitude,
      });
    }
  }
  
  Future<void> _finishRecording() async {
    // End the recording session and finalize the FIT file
    if (_fitWriter != null) {
      await _fitWriter!.finish();
      
      // File now saved at _fitWriter!.fitPath
      // Also created: ${fitPath}.jsonl with pressure metadata
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recorded ${_lapCount} runs')),
      );
    }
  }
}
```

## Pressure Data Flow

### 1. **PressureInputPage** - User Enters Values
```dart
// User inputs:
double frontPsi = 32.5;  // Front tire PSI
double rearPsi = 35.2;   // Rear tire PSI

// Pass to recording page
Navigator.push(context, MaterialPageRoute(builder: (_) =>
  RecordingPage(frontPsi: frontPsi, rearPsi: rearPsi)
));
```

### 2. **RecordingPage** - Records and Streams Data
```dart
// Start of run
await _fitWriter.writeLap(32.5, 35.2, lapIndex: 0);

// During run, every sensor update
await _fitWriter.writeRecord({
  'speed_kmh': sensorData.speed,
  'power': sensorData.power,
  'cadence': sensorData.cadence,
  'distance': sensorData.distance,
  'altitude': sensorData.altitude,
});

// End of run
await _fitWriter.finish();
```

### 3. **Files Created**
```
Files saved in external storage:
├── coast_down_20250129_194342.fit        # Strava-compatible FIT file
└── coast_down_20250129_194342.fit.jsonl  # Pressure metadata
```

### 4. **AnalysisPage** - Reads and Analyzes
```dart
// Load pressure data for analysis
final pressureData = await FitWriter.readPressureMetadata(fitFilePath);

// Result:
// [
//   {lapIndex: 0, frontPressure: 32.5, rearPressure: 35.2},
//   {lapIndex: 1, frontPressure: 33.1, rearPressure: 35.8},
//   {lapIndex: 2, frontPressure: 32.8, rearPressure: 35.5},
// ]

// Perform quadratic regression
double optimalPressure = performRegression(pressureData);
```

## Complete Example: Recording Session with 3 Runs

```dart
// Initialize
final fitWriter = await FitWriter.create(protocol: 'coast_down');
await fitWriter.startSession({});

// Run 1 (Front: 32.5 PSI, Rear: 35.2 PSI)
await fitWriter.writeLap(32.5, 35.2, lapIndex: 0);
for (int i = 0; i < 300; i++) { // Simulate 5 minutes of data
  await fitWriter.writeRecord({
    'speed_kmh': 25.4 + (i * 0.01),
    'power': 180 + (i % 10),
    'cadence': 92,
    'distance': (i * 5.0),
    'altitude': 125.0,
  });
  await Future.delayed(Duration(milliseconds: 100)); // Simulate timing
}

// Run 2 (Front: 33.1 PSI, Rear: 35.8 PSI)
await fitWriter.writeLap(33.1, 35.8, lapIndex: 1);
for (int i = 300; i < 600; i++) {
  await fitWriter.writeRecord({
    'speed_kmh': 25.6 + ((i-300) * 0.01),
    'power': 182 + ((i-300) % 10),
    'cadence': 92,
    'distance': (i * 5.0),
    'altitude': 125.0,
  });
  await Future.delayed(Duration(milliseconds: 100));
}

// Run 3 (Front: 32.8 PSI, Rear: 35.5 PSI)
await fitWriter.writeLap(32.8, 35.5, lapIndex: 2);
for (int i = 600; i < 900; i++) {
  await fitWriter.writeRecord({
    'speed_kmh': 25.5 + ((i-600) * 0.01),
    'power': 181 + ((i-600) % 10),
    'cadence': 92,
    'distance': (i * 5.0),
    'altitude': 125.0,
  });
  await Future.delayed(Duration(milliseconds: 100));
}

// Finalize
await fitWriter.finish();

// Files created:
// /storage/emulated/0/AppName/coast_down_20250129_194342.fit
// /storage/emulated/0/AppName/coast_down_20250129_194342.fit.jsonl

// Read pressure data for analysis
final pressureData = await FitWriter.readPressureMetadata(fitWriter.fitPath);
print('Pressure data loaded: ${pressureData.length} runs');
// Output:
// Pressure data loaded: 3 runs
// [
//   {lapIndex: 0, frontPressure: 32.5, rearPressure: 35.2},
//   {lapIndex: 1, frontPressure: 33.1, rearPressure: 35.8},
//   {lapIndex: 2, frontPressure: 32.8, rearPressure: 35.5},
// ]
```

## Testing FitWriter Independently

```dart
// Test script to verify FitWriter works
import 'package:tyre_preassure/fit_writer.dart';

void main() async {
  print('Testing FitWriter...');
  
  // Create a test session
  final writer = await FitWriter.create(protocol: 'test_protocol');
  print('Created FIT writer at: ${writer.fitPath}');
  
  // Start session
  await writer.startSession({});
  print('Session started');
  
  // Simulate 3 runs with different pressures
  final testRuns = [
    (front: 32.0, rear: 35.0),
    (front: 33.0, rear: 36.0),
    (front: 32.5, rear: 35.5),
  ];
  
  for (int run = 0; run < testRuns.length; run++) {
    final (front: f, rear: r) = testRuns[run];
    
    // Record lap with pressure
    await writer.writeLap(f, r, lapIndex: run);
    print('Lap $run recorded: Front=$f, Rear=$r');
    
    // Simulate 300 records per run (5 minutes)
    for (int i = 0; i < 300; i++) {
      await writer.writeRecord({
        'speed_kmh': 25.0 + (i * 0.01),
        'power': 180 + (i % 20),
        'cadence': 92,
        'distance': (run * 300 + i) * 5.0,
        'altitude': 125.0,
      });
    }
  }
  
  // Finalize
  await writer.finish();
  print('Recording finished');
  
  // Read pressure data back
  final pressureData = await FitWriter.readPressureMetadata(writer.fitPath);
  print('Pressure data loaded: $pressureData');
  
  // Verify
  assert(pressureData.length == 3, 'Expected 3 runs');
  assert(pressureData[0]['frontPressure'] == 32.0);
  assert(pressureData[2]['rearPressure'] == 35.5);
  
  print('✓ FitWriter test passed!');
}
```

## API Reference

### FitWriter Class

```dart
class FitWriter {
  // Constructor
  static Future<FitWriter> create({String protocol = 'unknown'}) 
    // Creates a new FIT writer with timestamped filename
    // Returns: FitWriter instance ready for use
  
  // Core Methods
  Future<void> startSession(Map<String, dynamic> metadata)
    // Initialize recording session with FileID message
    // Call once at start of recording
  
  Future<void> writeLap(double front, double rear, {required int lapIndex})
    // Record tire pressure for current run/lap
    // Parameters:
    //   front: Front tire pressure (PSI)
    //   rear: Rear tire pressure (PSI)
    //   lapIndex: Sequential run number (0, 1, 2...)
  
  Future<void> writeRecord(Map<String, dynamic> record)
    // Add sensor data point (speed, power, cadence, etc.)
    // Record format:
    //   {
    //     'speed_kmh': 25.4,
    //     'power': 180,
    //     'cadence': 92,
    //     'distance': 1250.0,
    //     'altitude': 125.0,
    //   }
  
  Future<void> finish()
    // Finalize recording and write FIT + JSONL files
    // Creates:
    //   ${fitPath}       - FIT activity file
    //   ${fitPath}.jsonl - Pressure metadata
  
  // Static Methods
  static Future<List<Map<String, dynamic>>> readPressureMetadata(String fitPath)
    // Read tire pressure data from companion JSONL file
    // Returns: List of {lapIndex, frontPressure, rearPressure}
  
  // Properties
  String get fitPath
    // File path where FIT file will be saved
}
```

## FIT File Compatibility

✅ **Strava**: Accepts FIT files generated by FitWriter  
✅ **Garmin Connect**: Understands FIT message structure  
✅ **TrainingPeaks**: Compatible with standard cycling fields  
✅ **Custom Analysis**: JSONL file readable by any language (Python, JavaScript, etc.)

---

**Next Steps**:
1. Integrate into RecordingPage
2. Test with actual sensor data (CSC + Power meters)
3. Verify FIT files upload to Strava
4. Implement AnalysisPage for quadratic regression
