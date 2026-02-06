# Tire Pressure Data Storage & Integration

## Overview

The Perfect Pressure app now **records and persists tire pressure data** as the primary performance metric. Tire pressure (front and rear PSI) is captured at the start of each cycling run and stored alongside standard FIT file data.

## Data Storage Strategy

### Dual-File Format

Each recording session creates **two complementary files**:

1. **FIT File** (`.fit`)
   - Standard Garmin FIT Activity file format
   - Compatible with Strava, Garmin Connect, TrainingPeaks
   - Contains: Records (speed, power, cadence), Lap summary, Session summary
   - Generated using official `fit_tool` SDK for 100% compliance

2. **Pressure Metadata File** (`.fit.jsonl`)
   - Companion JSONL file with tire pressure data
   - One JSON line per lap (per run)
   - Lightweight, human-readable format
   - Enables app to reconstruct pressure data for analysis

### Why Two Files?

**Problem**: FIT protocol doesn't expose Developer Data API in `fit_tool` SDK yet

**Solution**: Store pressure in companion JSONL file alongside FIT file
- ✅ Preserves all tire pressure data
- ✅ No information loss during Strava upload
- ✅ App can read pressure back from JSONL when analyzing
- ✅ Future: When fit_tool adds Developer Data support, migrate to embedded FIT fields

## Data Format

### Pressure Metadata File Structure

```jsonl
{"lapIndex": 0, "frontPressure": 32.5, "rearPressure": 35.2, "timestamp": "2025-01-29T19:43:42.000Z"}
{"lapIndex": 1, "frontPressure": 33.1, "rearPressure": 35.8, "timestamp": "2025-01-29T19:53:42.000Z"}
{"lapIndex": 2, "frontPressure": 32.8, "rearPressure": 35.5, "timestamp": "2025-01-29T20:03:42.000Z"}
```

**Fields**:
- `lapIndex` (integer): Sequential run/lap index (0, 1, 2...)
- `frontPressure` (float): Front tire pressure in PSI
- `rearPressure` (float): Rear tire pressure in PSI
- `timestamp` (ISO-8601): UTC time when pressure was recorded

### Example File Pair

```
coast_down_20250129_194342.fit        # Strava-compatible FIT activity file
coast_down_20250129_194342.fit.jsonl  # Companion pressure metadata
```

## API Usage

### Writing Pressure Data

During recording, call `writeLap()` with pressure values:

```dart
final fitWriter = await FitWriter.create(protocol: 'coast_down');
await fitWriter.startSession({});

// Record a run with tire pressure
await fitWriter.writeLap(
  32.5,  // Front tire pressure (PSI)
  35.2,  // Rear tire pressure (PSI)
  lapIndex: 0
);

// Write sensor data
await fitWriter.writeRecord({
  'speed_kmh': 25.4,
  'power': 180,
  'cadence': 92,
  'distance': 1250.0,
  'altitude': 125.0,
});

// Finalize - writes both .fit and .fit.jsonl files
await fitWriter.finish();
```

### Reading Pressure Data

After recording, retrieve pressure metadata:

```dart
// Read pressure data from metadata file
final pressureData = await FitWriter.readPressureMetadata(
  'coast_down_20250129_194342.fit'
);

// Access pressure readings
for (final lap in pressureData) {
  print('Lap ${lap["lapIndex"]}: '
      'Front=${lap["frontPressure"]} PSI, '
      'Rear=${lap["rearPressure"]} PSI');
}
```

## Analysis Workflow

### Quadratic Regression (3-Run Minimum)

1. **Collect 3+ runs** with different tire pressures:
   - Run 1: Front 32 PSI, Rear 35 PSI
   - Run 2: Front 33 PSI, Rear 36 PSI
   - Run 3: Front 34 PSI, Rear 37 PSI

2. **Extract performance metric per run**:
   - From FIT Records: Calculate average speed, power, or efficiency
   - From JSONL: Get exact tire pressures for each run

3. **Perform quadratic regression**:
   - X-axis: Tire pressure (PSI)
   - Y-axis: Efficiency coefficient (speed/power ratio)
   - Find vertex: The pressure where efficiency is maximized

4. **Display recommendation**:
   - Show pressure-efficiency curve in AnalysisPage
   - Highlight optimal pressure at curve vertex

## File Storage

### Default Locations

**Android**: External storage (user-accessible)
```
/storage/emulated/0/[AppName]/
  └── coast_down_20250129_194342.fit
  └── coast_down_20250129_194342.fit.jsonl
```

**iOS**: App documents directory
```
~/Library/Documents/tyre_sessions/
  └── coast_down_20250129_194342.fit
  └── coast_down_20250129_194342.fit.jsonl
```

## Code Implementation Details

### FitWriter Changes

**New fields**:
```dart
double _currentFrontPressure = 0.0;
double _currentRearPressure = 0.0;
List<Map<String, dynamic>> _laps = []; // Tracks pressure per lap
```

**Key methods**:

- `writeLap(front, rear, lapIndex)` — Records pressure for current run
- `finish()` — Finalizes FIT file AND writes pressure metadata
- `_writePressureMetadata()` — Writes `.fit.jsonl` companion file
- `readPressureMetadata()` — Static method to read pressure from existing file

### Pressure Flow

```
Recording Session:
  ├─ User inputs front/rear PSI
  ├─ Call writeLap(32.5, 35.2, lapIndex: 0)
  │  └─ Store in _laps list
  ├─ Accumulate sensor Records (speed, power, etc.)
  ├─ Call finish()
  │  ├─ Write .fit file (sensor data + standard messages)
  │  └─ Write .fit.jsonl file (pressure metadata)
  └─ Done!

Analysis Session:
  ├─ Load pressure metadata from .fit.jsonl
  ├─ Read FIT file to extract efficiency metrics
  ├─ Perform quadratic regression
  └─ Display pressure-efficiency curve
```

## Future Enhancements

### Official Path: FIT Protocol v2.0 Developer Data (Garmin Spec)

Once `fit_tool` SDK v2.0+ adds Developer Data support (see [FIT_DEVELOPER_DATA_COMPLIANCE.md](FIT_DEVELOPER_DATA_COMPLIANCE.md)):

1. **Create DeveloperDataIdMessage** with app GUID
2. **Define FieldDescriptionMessages** for tire pressure fields  
3. **Attach DeveloperFields** to LapMessage
4. **Use FIT Protocol v2.0** for encoding

Benefits:
- Pressure data embedded IN FIT file
- Strava recognizes pressure natively
- Single file (no companion JSONL needed)
- Garmin-compliant

**Code Migration:**
```dart
// Future implementation (when fit_tool v2.0+ released)
final developerIdMsg = DeveloperDataIdMessage()
  ..applicationId = perfectPressureAppGuid
  ..developerDataIndex = 0;

final frontPressureFieldDesc = FieldDescriptionMessage()
  ..fieldName = "Front Tire Pressure"
  ..units = "PSI"
  ..fitBaseTypeId = FitBaseType.float32;

final frontPressureDev = DeveloperField(frontPressureFieldDesc, developerIdMsg)
  ..setValue(32.5);

lapMessage.addDeveloperField(frontPressureDev);
```

**Current Status:** fit_tool v1.0.5 doesn't expose these APIs yet, so we use the companion JSONL approach as an interim solution.
  ..frontTirePressure = 32.5
  ..rearTirePressure = 35.2;
```

### Option 2: Custom Message Type
Define a new FIT message type specifically for tire pressure:
- Message ID: 200+ (custom range)
- Fields: timestamp, frontPressure, rearPressure, wheelCircumference
- Benefits: More structured, compatible with FIT spec

### Option 3: Write Pressure to Record Messages
Store pressure in each Record message:
- Capture pressure every sensor sample
- Shows pressure variation during run
- Useful if pressure is not constant
- More data, larger FIT file

## Testing Checklist

- [x] FitWriter compiles without errors
- [x] `writeLap()` stores pressure data
- [x] `finish()` writes both .fit and .jsonl files
- [x] Pressure metadata is readable (JSONL format)
- [x] File paths are correct and sanitized
- [ ] Test round-trip: write pressure → read pressure → verify values match
- [ ] Test analysis: Load 3 pressure points → perform regression → display curve
- [ ] Strava compatibility: Verify .fit file still uploads (pressure in .jsonl doesn't break it)

## Integration Points

### RecordingPage
Update to pass tire pressure to FitWriter:

```dart
// In recordingPage.dart, when finishing a lap:
await fitWriter.writeLap(
  frontPressurePsi,
  rearPressurePsi,
  lapIndex: currentLapIndex
);
```

### AnalysisPage (Future)
Use `readPressureMetadata()` to load pressure data:

```dart
// In analysisPage.dart:
final pressureData = await FitWriter.readPressureMetadata(fitFilePath);
performQuadraticRegression(pressureData);
displayEfficiencyCurve();
```

### Sensor Service
No changes needed - sensor data (speed, power) already flows through `writeRecord()`

## Troubleshooting

### Pressure data not saved?
1. Verify `writeLap()` was called before `finish()`
2. Check file permissions in app settings
3. Confirm storage directory exists

### Cannot read pressure from .jsonl?
1. Verify file extension is `.fit.jsonl` (not `.fit`)
2. Check JSON format (one line per lap)
3. Use `readPressureMetadata()` helper method

### FIT file upload to Strava fails?
1. Pressure metadata file (.jsonl) doesn't affect FIT upload
2. Verify .fit file itself passes validation
3. Confirm at least 300 Records (for 5+ min activity)

---

**Last Updated**: January 2025  
**Status**: Implementation Complete, Ready for Testing  
**Next**: Integrate with AnalysisPage for quadratic regression
