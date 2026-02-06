# Coast Down Protocol: Data Extraction & Analysis

## Problem Statement

> **User Question:** "What data are we missing to do math and get result for perfect pressure?"

**Answer:** We were missing **Coast Phase Detection** - the ability to verify that the user is coasting (not pedaling) and measure the deceleration rate during the coast.

## Solution Implemented

### 1. Sensor Records File Generation

**File:** [fit_writer.dart](lib/fit_writer.dart)

**Changes:**
- Added `_lapSensorRecords` map to track individual sensor records per lap
- Modified `writeRecord()` to store each sensor record (cadence, speed, power, etc.) in `_lapSensorRecords[lapIndex]`
- Added `_writeSensorRecords()` method to write sensor data to companion JSONL file: `{fitPath}.sensor_records.jsonl`

**Format of sensor_records.jsonl:**
```json
{"lapIndex": 0, "timestamp": "2025-01-30T10:45:12.000Z", "speed_kmh": 25.5, "cadence": 0, "power": 0, "distance": 1000.0, "altitude": 100.5, "lat": 37.7749, "lon": -122.4194}
{"lapIndex": 0, "timestamp": "2025-01-30T10:45:13.000Z", "speed_kmh": 24.2, "cadence": 0, "power": 0, "distance": 1006.7, "altitude": 99.8, "lat": 37.7749, "lon": -122.4194}
...
```

### 2. Coast Phase Detection

**File:** [clustering_service.dart](lib/clustering_service.dart)

**Changes to `_extractLapDataFromJsonl()`:**
- Reads sensor records from `{fitPath}.sensor_records.jsonl`
- Groups records by lap index
- For each lap, analyzes sensor records to detect coast phases:
  - **Coast Phase Definition:** `cadence == 0 AND speed > 3 km/h`
  - Tracks `coastStartSpeed` when coast begins
  - Tracks `coastEndSpeed` at end of coast phase
  - Counts duration as consecutive 1-second records where coasting

**Output:** Calculates three coast metrics per lap:
1. `avgCadence` - Average cadence across entire lap (RPM)
2. `coastingDuration` - Total seconds spent coasting (cadence = 0)
3. `deceleration` - Speed loss rate during coast (km/h per second)

### 3. LapMetrics Expansion

**File:** [clustering_service.dart](lib/clustering_service.dart) - LapMetrics class

**Added Fields:**
```dart
final double avgCadence;        // Average cadence (RPM) - 0 = coasting
final double coastingDuration;  // Duration with cadence=0 (seconds)
final double deceleration;      // Rate of speed loss during coast (km/h per sec)
```

**Updated constructor** to include these three new parameters.

**Updated `extractMetricsFromFitAndJsonl()`** to pass coast metrics when creating LapMetrics instances.

## Data Flow Diagram

```
Sensor Service (Real-time)
  ├─ Captures cadence from CSC sensor
  ├─ Captures speed from CSC/GPS
  ├─ Captures power from Power Meter
  └─ Writes to record dict every 1 second
       ↓
Recording Page
  └─ Calls _fitWriter.writeRecord(record)
       ↓
FIT Writer
  ├─ Stores record in _lapSensorRecords[lapIndex]
  ├─ Writes FIT file (fit_tool encodes)
  ├─ Writes pressure metadata JSONL
  └─ Writes sensor records JSONL ✅ NEW
       ↓
Analysis Page
  └─ Calls ClusteringService.extractMetricsFromFitAndJsonl()
       ↓
Clustering Service
  ├─ Reads pressure metadata from {fitPath}.jsonl
  ├─ Reads sensor records from {fitPath}.sensor_records.jsonl ✅ NEW
  ├─ Detects coast phases (cadence=0)
  ├─ Calculates coastingDuration and deceleration ✅ NEW
  └─ Returns LapMetrics with coast data
       ↓
Regression Analysis
  └─ Uses deceleration as Y-value for quadratic regression ✅ READY
```

## Key Insights

### Why Cadence Verification?

The coast down protocol runs **without pedaling**. User must coast (cadence=0) to create a fair test where only tire pressure affects rolling resistance. By monitoring cadence in the FIT file and sensor records:
- ✅ Verifies user actually coasted (not cheating by pedaling)
- ✅ Measures deceleration during pure coast phase
- ✅ Identifies data to exclude if cadence wasn't zero

### Deceleration as the Efficiency Metric

**Formula:**
```
deceleration (km/h per second) = (coastStartSpeed - coastEndSpeed) / coastingDuration
```

**Interpretation:**
- **Lower deceleration** = better tire pressure (less rolling resistance)
- **Higher deceleration** = worse tire pressure (more rolling resistance)

**Example:**
- Pressure A: Decelerate from 25 km/h to 15 km/h in 10 seconds = 1.0 km/h per sec
- Pressure B: Decelerate from 25 km/h to 18 km/h in 10 seconds = 0.7 km/h per sec
- **Pressure B is better** (lower deceleration = less energy loss)

## Implementation Details

### Coast Phase Detection Algorithm

```dart
for (int i = 0; i < records.length; i++) {
  final cadence = record['cadence'];
  final speed = record['speed_kmh'];
  
  if (cadence == 0.0 && speed > 3.0) {  // Start of coast phase
    if (!inCoastPhase) {
      inCoastPhase = true;
      coastStartSpeed = speed;
    }
    coastingDuration += 1.0;  // 1 record = 1 second
    coastEndSpeed = speed;    // Update current speed
  } else {
    inCoastPhase = false;     // End of coast phase
  }
}

deceleration = (coastStartSpeed - coastEndSpeed) / coastingDuration;
```

**Key Parameters:**
- Minimum speed threshold: 3.0 km/h (avoids noise when stopped)
- Time resolution: 1 second per record (data captured every ~1 second in sensor_service.dart)
- Coast definition: cadence must be exactly 0 (not partial pedaling)

## Files Modified

| File | Changes | Status |
|------|---------|--------|
| [fit_writer.dart](lib/fit_writer.dart) | Added sensor record tracking + write to .sensor_records.jsonl | ✅ Complete |
| [clustering_service.dart](lib/clustering_service.dart) | Added coast detection + deceleration calculation | ✅ Complete |
| [clustering_service.dart](lib/clustering_service.dart) - LapMetrics | Added 3 new fields: avgCadence, coastingDuration, deceleration | ✅ Complete |

## Testing & Validation

To verify coast detection is working:

1. **Record a test run** with the app in coast down mode
2. **Check generated files:**
   - `*.fit` - FIT file with cadence records
   - `*.jsonl` - Pressure/vibration metadata
   - `*.sensor_records.jsonl` - **NEW**: Individual sensor records
3. **Check analysis output** in console:
   ```
   DEBUG: Lap 0 - avgCadence=15.2 RPM, coastingDuration=45.3s, deceleration=0.452 km/h per sec
   ```

## Next Steps

### Regression Analysis (TODO)

Once coast metrics are extracted, update the regression analysis in [analysis_page.dart](lib/analysis_page.dart) to:
1. Use `deceleration` as the Y-value (instead of generic speed)
2. Use `frontPressure` as the X-value
3. Perform quadratic regression: `Y = aX² + bX + c`
4. Find vertex (optimal pressure) where deceleration is minimized

**Current:** Regression uses speed/vibration (generic metrics)
**Proposed:** Regression uses deceleration (coast-down specific metric)

### Dashboard Visualization

Display coast metrics in AnalysisPage results:
- "Average Cadence: 12.5 RPM" (should be near 0 for valid coast)
- "Coasting Duration: 48.2 seconds"
- "Deceleration: 0.42 km/h per second"
- "Optimal Pressure: 32.5 PSI (front), 35.8 PSI (rear)"

## Conclusion

**Missing Data Problem:** ✅ SOLVED

The app now:
1. ✅ Captures cadence from CSC sensor in real-time
2. ✅ Stores cadence in both FIT file and sensor records JSONL
3. ✅ Detects coast phases (cadence=0, speed>3 km/h)
4. ✅ Calculates deceleration rate during coast
5. ✅ Stores all data in LapMetrics for regression analysis

**Ready for:** Quadratic regression analysis using deceleration as the efficiency metric

---

Last Updated: January 2025 | Feature: Coast Down Protocol Data Extraction Complete
