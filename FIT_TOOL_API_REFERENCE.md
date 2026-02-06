# fit_tool Package v1.0.5 - Complete API Reference

## Import Statement
```dart
import 'package:fit_tool/fit_tool.dart';
```

## Core Classes and Message Types

### Message Classes Available
- `FileIdMessage` - File metadata (REQUIRED first message)
- `RecordMessage` - Sensor data points (timestamp, speed, power, cadence, position)
- `LapMessage` - Lap/segment summary
- `SessionMessage` - Activity session summary (REQUIRED)
- `ActivityMessage` - File-level activity wrapper (REQUIRED)
- `LapMessage` - Per-lap statistics

### Enumeration Types
- `FileType` - `.activity`, `.device`, etc.
- `Manufacturer` - `garmin`, `specialized`, etc. (use `.value` for integer)
- `Sport` - `.cycling`, `.running`, `.swimming`, etc.
- `Activity` - `.manual`, `.auto_multi_sport`, etc.

## FIT File Creation Pattern

### 1. Create the Builder
```dart
final FitFileBuilder _builder = FitFileBuilder(autoDefine: true);
```
**Parameters:**
- `autoDefine: true` - Automatically generates FIT message definitions (recommended)

### 2. Create FileID Message (REQUIRED - Must be first)
```dart
final fileIdMessage = FileIdMessage()
  ..type = FileType.activity           // Activity type
  ..manufacturer = Manufacturer.garmin.value  // Manufacturer ID
  ..product = 1                        // Product ID
  ..serialNumber = 123456              // Device serial number
  ..timeCreated = startTimeEpoch;      // Creation timestamp (FIT epoch)
```

**FileIdMessage Fields:**
- `type` - FileType enum (activity, settings, device, etc.)
- `manufacturer` - Use `.value` to get integer from enum
- `product` - Integer product ID
- `serialNumber` - Integer serial number
- `timeCreated` - FIT epoch timestamp (int - seconds since 1989-12-31)

### 3. Create Record Messages (Sensor Data)
```dart
final recordMessages = <RecordMessage>[];

for (int i = 0; i < numSamples; i++) {
  final record = RecordMessage()
    ..timestamp = tsEpoch              // FIT epoch timestamp
    ..positionLat = 37.7749            // Latitude in degrees
    ..positionLong = -122.4194         // Longitude in degrees
    ..altitude = 100.0                 // Altitude in meters
    ..speed = 6.5                      // Speed in m/s
    ..distance = 6500.0                // Cumulative distance in meters
    ..cadence = 90                     // Cadence in rpm
    ..power = 250;                     // Power in watts

  recordMessages.add(record);
}
```

**RecordMessage Key Fields:**
| Field | Type | Unit | Notes |
|-------|------|------|-------|
| `timestamp` | int | FIT epoch | Seconds since 1989-12-31 00:00:00 UTC |
| `positionLat` | double | degrees | Positive = North, Negative = South |
| `positionLong` | double | degrees | Positive = East, Negative = West |
| `altitude` | double | meters | Height above sea level |
| `speed` | double | m/s | Speed (NOT km/h - must convert) |
| `distance` | double | meters | Cumulative distance from start |
| `cadence` | int | rpm | Pedaling cadence |
| `power` | int | watts | Instantaneous power output |

### 4. Create Lap Message (REQUIRED)
```dart
final lapMessage = LapMessage()
  ..timestamp = endTimeEpoch           // End time of lap
  ..startTime = startTimeEpoch         // Start time of lap
  ..startPositionLat = 37.7749         // Starting latitude
  ..startPositionLong = -122.4194      // Starting longitude
  ..totalElapsedTime = 1800.0          // Total elapsed time in seconds
  ..totalTimerTime = 1800.0            // Total timer time in seconds
  ..totalDistance = 45000.0            // Total distance in meters
  ..totalCycles = 1800                 // Total cadence cycles or revolutions
  ..totalAscent = 250                  // Total elevation gain in meters
  ..avgSpeed = 6.25                    // Average speed in m/s
  ..avgPower = 240                     // Average power in watts
  ..sport = Sport.cycling              // Sport type enum
  ..messageIndex = 0;                  // Message index (0 = primary)
```

**LapMessage Key Fields:**
| Field | Type | Unit | Notes |
|-------|------|------|-------|
| `timestamp` | int | FIT epoch | End time of lap |
| `startTime` | int | FIT epoch | Start time of lap |
| `startPositionLat` | double | degrees | Latitude at lap start |
| `startPositionLong` | double | degrees | Longitude at lap start |
| `totalElapsedTime` | double | seconds | Total elapsed time |
| `totalTimerTime` | double | seconds | Total timer time (may differ if paused) |
| `totalDistance` | double | meters | Total distance covered |
| `totalCycles` | int | count | Total cadence cycles or wheel revolutions |
| `totalAscent` | int | meters | Total elevation gain |
| `avgSpeed` | double | m/s | Average speed |
| `avgPower` | int | watts | Average power |
| `sport` | Sport | enum | Sport type |
| `messageIndex` | int | index | 0 = primary lap |

### 5. Create Session Message (REQUIRED)
```dart
final sessionMessage = SessionMessage()
  ..timestamp = endTimeEpoch           // Session end time
  ..startTime = startTimeEpoch         // Session start time
  ..totalElapsedTime = 1800.0          // Total elapsed time
  ..totalTimerTime = 1800.0            // Total timer time
  ..totalDistance = 45000.0            // Total distance
  ..totalCycles = 1800                 // Total cycles
  ..totalAscent = 250                  // Total elevation gain
  ..avgSpeed = 6.25                    // Average speed
  ..avgPower = 240                     // Average power
  ..sport = Sport.cycling              // Sport type
  ..numLaps = 1;                       // Number of laps in session
```

**SessionMessage Key Fields:**
- Summarizes the entire activity session
- Required for Strava compatibility
- Same field types as LapMessage
- `numLaps` - Total number of laps in the session

### 6. Create Activity Message (REQUIRED by Strava)
```dart
final activityMessage = ActivityMessage()
  ..timestamp = endTimeEpoch           // Activity timestamp
  ..numSessions = 1                    // Number of sessions in file
  ..type = Activity.manual;            // Activity type (manual, auto, etc.)
```

**ActivityMessage Key Fields:**
| Field | Type | Notes |
|-------|------|-------|
| `timestamp` | int | Activity end timestamp |
| `numSessions` | int | Number of sessions (usually 1) |
| `type` | Activity | Activity type enum |

### 7. Build and Encode FIT File
```dart
// Add all messages to builder (order matters!)
final builder = FitFileBuilder(autoDefine: true)
  ..add(fileIdMessage)           // MUST be first
  ..addAll(recordMessages)       // All sensor records
  ..add(lapMessage)              // Lap summary
  ..add(sessionMessage)          // Session summary
  ..add(activityMessage);        // Activity wrapper (LAST)

// Build the FIT file object
final fitFile = builder.build();

// Encode to bytes (includes CRC calculation)
final bytes = fitFile.toBytes();

// Write to disk
final file = File('output.fit');
await file.writeAsBytes(bytes);
```

**Builder Methods:**
- `add(Message)` - Add single message
- `addAll(List<Message>)` - Add multiple messages
- `build()` - Returns FitFile object (handles CRC calculation automatically)

**FitFile Methods:**
- `toBytes()` - Returns encoded binary data as `Uint8List`

## Time Conversion Utility

### Convert DateTime to FIT Epoch
```dart
/// Convert Dart DateTime to FIT epoch (seconds since 1989-12-31 00:00:00 UTC)
int dateTimeToFitEpoch(DateTime dt) {
  final fitEpoch = DateTime.utc(1989, 12, 31);
  return dt.difference(fitEpoch).inSeconds;
}

// Usage:
final now = DateTime.now().toUtc();
final fitTimestamp = dateTimeToFitEpoch(now);
```

## Complete Working Example

```dart
import 'dart:io';
import 'package:fit_tool/fit_tool.dart';

void main() async {
  // Setup timestamps
  final startTime = DateTime.utc(2025, 1, 30, 10, 0, 0);
  final endTime = startTime.add(Duration(minutes: 30));
  
  final startTimeEpoch = _dateTimeToFitEpoch(startTime);
  final endTimeEpoch = _dateTimeToFitEpoch(endTime);

  // 1. Create FileID message (REQUIRED FIRST)
  final fileIdMessage = FileIdMessage()
    ..type = FileType.activity
    ..manufacturer = Manufacturer.garmin.value
    ..product = 1
    ..serialNumber = 123456
    ..timeCreated = startTimeEpoch;

  // 2. Create Record messages (sensor data)
  final recordMessages = <RecordMessage>[];
  double distance = 0.0;
  double totalElevationGain = 0.0;
  double totalSpeed = 0.0;
  double totalPower = 0.0;

  for (int i = 0; i < 1800; i++) {
    final ts = startTime.add(Duration(seconds: i));
    final tsEpoch = _dateTimeToFitEpoch(ts);
    
    final speed = 6.0 + (i % 15) * 0.3;  // m/s
    final cadence = 85 + (i % 20);       // rpm
    final power = 240 + (i % 80);        // watts
    
    distance += speed * 1.0;
    totalSpeed += speed;
    totalPower += power;
    
    if (i % 10 == 0) {
      totalElevationGain += 0.5;
    }

    recordMessages.add(RecordMessage()
      ..timestamp = tsEpoch
      ..positionLat = 37.7749 + (i * 0.000002)
      ..positionLong = -122.4194 + (i * -0.000003)
      ..altitude = 100.0 + totalElevationGain
      ..speed = speed
      ..distance = distance
      ..cadence = cadence
      ..power = power);
  }

  final avgSpeed = totalSpeed / 1800;
  final avgPower = totalPower / 1800;

  // 3. Create Lap message (REQUIRED)
  final lapMessage = LapMessage()
    ..timestamp = endTimeEpoch
    ..startTime = startTimeEpoch
    ..startPositionLat = 37.7749
    ..startPositionLong = -122.4194
    ..totalElapsedTime = 1800.0
    ..totalTimerTime = 1800.0
    ..totalDistance = distance
    ..totalCycles = 1800
    ..totalAscent = totalElevationGain.toInt()
    ..avgSpeed = avgSpeed
    ..avgPower = avgPower.toInt()
    ..sport = Sport.cycling;

  // 4. Create Session message (REQUIRED)
  final sessionMessage = SessionMessage()
    ..timestamp = endTimeEpoch
    ..startTime = startTimeEpoch
    ..totalElapsedTime = 1800.0
    ..totalTimerTime = 1800.0
    ..totalDistance = distance
    ..totalCycles = 1800
    ..totalAscent = totalElevationGain.toInt()
    ..avgSpeed = avgSpeed
    ..avgPower = avgPower.toInt()
    ..sport = Sport.cycling
    ..numLaps = 1;

  // 5. Create Activity message (REQUIRED)
  final activityMessage = ActivityMessage()
    ..timestamp = endTimeEpoch
    ..numSessions = 1
    ..type = Activity.manual;

  // 6. Build the FIT file
  final builder = FitFileBuilder(autoDefine: true)
    ..add(fileIdMessage)
    ..addAll(recordMessages)
    ..add(lapMessage)
    ..add(sessionMessage)
    ..add(activityMessage);

  // 7. Encode and write
  final fitFile = builder.build();
  final bytes = fitFile.toBytes();
  
  final outFile = File('output.fit');
  await outFile.writeAsBytes(bytes);
  
  print('✓ FIT file created: ${outFile.path}');
  print('  Size: ${bytes.length} bytes');
  print('  Distance: ${(distance/1000).toStringAsFixed(2)} km');
  print('  Avg Speed: ${(avgSpeed * 3.6).toStringAsFixed(1)} km/h');
  print('  Avg Power: ${avgPower.toStringAsFixed(0)} W');
}

int _dateTimeToFitEpoch(DateTime dt) {
  final fitEpoch = DateTime.utc(1989, 12, 31);
  return dt.difference(fitEpoch).inSeconds;
}
```

## File Structure Order (CRITICAL for Strava)

The order of messages in the FIT file matters:

```
1. FileIdMessage (MUST BE FIRST)
2. RecordMessage(s) - Multiple sensor data points
3. LapMessage - Lap summary
4. SessionMessage - Session summary
5. ActivityMessage - Activity wrapper
```

**DO NOT reorder these messages.** Strava expects this specific structure.

## Key Constraints & Gotchas

### Unit Conversions Required
| Input | FIT Unit | Conversion |
|-------|----------|-----------|
| km/h | m/s | divide by 3.6 |
| m/s | km/h | multiply by 3.6 |
|°C | °C | no conversion (native support) |
| bpm | bpm | no conversion |

### Null Handling
- fit_tool uses nullable fields with `??` getters
- Set fields explicitly: `message.field = value;`
- Unset fields are encoded as sentinel values by fit_tool

### autoDefine Parameter
- `autoDefine: true` - Automatically generates FIT data definitions (RECOMMENDED)
- `autoDefine: false` - Requires manual FIT protocol knowledge (not recommended)

## Known Limitations (v1.0.5)

### What fit_tool DOES NOT Support
1. **Developer Data Fields** - No DeveloperDataIdMessage or FieldDescriptionMessage
   - Solution: Use companion `.jsonl` metadata file for custom fields
2. **Protocol v2.0 Features** - Limited to Protocol v1.2 for custom fields
3. **Compression** - Not supported

### Workaround: Companion JSONL File
For tire pressure data not supported by fit_tool:

```dart
// Write pressure data alongside FIT file
final metadataPath = '$fitPath.jsonl';
final sink = File(metadataPath).openWrite();

for (final lap in laps) {
  final line = '''{"lapIndex": ${lap['index']}, "frontPressure": ${lap['front']}, "rearPressure": ${lap['rear']}, "timestamp": "${lap['time']}"}
''';
  sink.write(line);
}

await sink.close();
```

Then read it back:
```dart
static Future<List<Map<String, dynamic>>> readPressureMetadata(String fitPath) async {
  final file = File('$fitPath.jsonl');
  if (!file.existsSync()) return [];
  
  final lines = await file.readAsLines();
  final results = <Map<String, dynamic>>[];
  
  for (final line in lines) {
    if (line.isEmpty) continue;
    // Parse JSON manually or use jsonDecode from dart:convert
    results.add(jsonDecode(line));
  }
  
  return results;
}
```

## References

**Workspace Implementation Examples:**
- [fit_writer.dart](lib/fit_writer.dart) - Production FIT writer with tire pressure companion file
- [generate_fit_proper.dart](tools/generate_fit_proper.dart) - Complete working example
- [test_developer_data_support.dart](test_developer_data_support.dart) - Limitations test

**Official Resources:**
- Garmin FIT Protocol Spec: https://developer.garmin.com/fit/overview/
- FIT Cookie (Timestamp Epoch): https://developer.garmin.com/fit/cookbook/
- fit_tool on pub.dev: https://pub.dev/packages/fit_tool

**Time Conversion:**
- FIT Epoch = December 31, 1989 00:00:00 UTC
- JavaScript epoch (Jan 1, 1970) is 631152000 seconds after FIT epoch
