# Perfect Pressure App - Copilot Instructions

## Project Overview

**App Name:** Perfect Pressure (Working Title)

**Core Purpose:** Determine the mathematically optimal tire pressure for a specific cyclist on a specific surface by measuring the relationship between **Speed/Distance** and **Power Output** across multiple test runs.

The app uses a **3-Run Minimum Protocol** with Quadratic Regression to find the vertex of the pressure-efficiency curve—where rolling resistance is minimized before surface impedance causes it to rise again.

### Key Insight
> "We are building a Flutter-based cycling tool that uses persistent Bluetooth links to CSC and Power sensors. We record everything into one continuous FIT file, using Lap messages to tag specific tire pressures. After 3 data points (3 runs), we use quadratic regression to solve for the optimal pressure. The system must be resilient to backgrounding and minimize RAM usage by streaming directly to storage."

## Testing Protocol: The 3-Run Minimum

### Data Collection Structure
- **The Continuous Session:** All data for one session is recorded into a **single, continuous FIT file**. Recording does NOT stop between runs; it remains in a "Wait State" while the user returns to the starting anchor.
- **Run Definition:** A "Run" is a timed cycling bout where the user maintains steady power/speed on the same road segment (the "Anchor").
- **Metadata Injection:** At the start of every Run, the user inputs current **Front and Rear tire pressure**. The app inserts a **FIT Lap Message** with pressure metadata attached.

### Hardware Inputs
1. **CSC Sensor (Bluetooth UUID 1816, Char 2A5B):** High-precision wheel revolutions → speed + distance
2. **Power Meter (Bluetooth UUID 1818, Char 2A63):** Instantaneous watts (bytes 2-3 of characteristic)

### The Math: Quadratic Regression
- **Minimum 3 runs required** to enable "Finish and Calculate"
- **Goal:** Correlate Coefficient of Rolling Resistance (CRR) at each pressure point
- **Analysis:** Perform **Quadratic Regression** to find the vertex—the "Perfect Pressure" where rolling resistance is minimized
- **Future:** Analysis page will display the pressure-efficiency curve and target pressure recommendation

## Architecture & Data Flow

### Foreground Service & Memory Management (CRITICAL)

**DO NOT store sensor data in RAM.** Stream data points (Speed, Power, Cadence) **directly to `.fit` file handle on disk** using `IOSink`.

**Why:**
- Prevents app crashes during long sessions (> 30 min)
- Ensures data safety if app is backgrounded/killed
- Mobile OS kills Bluetooth and File I/O when screen is off

**Implementation:**
- Foreground Service owns the Bluetooth GATT connection
- UI is merely a "w (Current Implementation)
```
main.dart (initializes SensorService)
  └─> SensorSetupPage (Bluetooth pairing + GPS/Accel validation)
       ├─> ProtocolSelectionPage (light theme; currently 3 protocol cards)
       │    └─> CoastDownInstructions (dark theme)
       │         └─> PressureInputPage (dark theme; Front/Rear PSI input)
       │              └─> RecordingPage (live sensor stream display)
       │                   └─> [MISSING] AnalysisPage (Quadratic regression results)
       └─> Sensor scanning/pairing modal
```

**Future:** Add AnalysisPage after RecordingPage to display curve + target pressure. GPS fallback speed (via Geolocator when BT unavailable)
  - Wheel revolution parsing (CSC characteristic 2A5B) with 32-bit revolution counter and 16-bit time
  - Power meter data extraction (CP characteristic 2A63, bytes 2-3 = watts)
  - Distance calculation: `(wheelRevolutions - lapStartRevs) × 2.1m / 1000`

### Navigation Flow
```
main.dart
  └─> SensorSetupPage
       ├─> Protocol Selection (Coast-Down selected)
       │    └─> CoastDownInstructions
       │         └─> PressureInputPage (front/rear PSI)
       │              └─> RecordingPage (live sensor stream)
       └─> Sensor scanning/pairing
```

### Critical Sensor Fusion Logic
- **Speed Prioritization**: BT wheel revs prioritized over GPS (GPS = fallback)
- **Wheel Rev Parsing** [line 202-225]: 
  - Flags check (bit 0x01 = wheel data present)
  - Cumulative 32-bit counter wrapping handled with `& 0xFFFFFFFF`
  - Time in 1/1024s units; converted to seconds for speed calc
- **Stop Detection**: 2-second timer sets speed to 0 if no new BT data arrives
- **Distance Tracking**: Per-run (lap) distance stored with lap baseline (`_lapStartRevs`)
 Bluetooth GATT Requirements (Do NOT Ignore)

- **CSC Service (0x1816):** Characteristic `0x2A5B` for wheel revolutions (cumulative counter + time)
- **Power Service (0x1818):** Characteristic `0x2A63` for instantaneous power (watts in bytes 2-3)
- **MTU Management:** Request MTU 512 while catching `GATT_INVALID_PDU` errors for bonded devices
- **Service Discovery:** Always call `device.discoverServices()` **AFTER** `device.connect()`; UUIDs must be discovered dynamically per device modeltracted |
|---------|------|-----------------|-----------------|
| Speed & Cadence | 1816 | 2A5B | Wheel revs, cadence |
| Power | 1818 | 2A63 | Watts (bytes 2-3) |

### Constants
- **Wheel Circumference**: 2.1m (line 36 SensorService)
- **Min Speed Threshold**: 3.0 km/h (line 32; below = 0.0)
- **BT Timeout**: 15 seconds (line 33)
- **Stop Timeout**: 2 seconds of no BT data (line 177)

### UI Color Scheme (Dark Theme)
- **Background Dark**: `#121418`
- **Card Grey**: `#1E2228`
- **Accent (Gemini Teal)**: `#47D1C1`
- (Light theme used only in Protocol Selection and Coast-Down instructions)

### State Management Pattern
- No external state manager (Provider, Riverpod, etc.)
- Direct `SensorService` singleton access from pages
- `StreamSubscription` management in `initState`/`dispose` with `mounted` checks

## Common Pitfalls & Gotchas

1. **Bluetooth Service Discovery**: Always call `device.discoverServices()` AFTER `device.connect()`; UUIDs must be discovered dynamically per device model
2. **Stream Cleanup**: Must cancel subscriptions in `dispose()` and check `mounted` before `setState()` to prevent memory leaks
3. **32-bit Overflow**: Wheel revolution counter wraps at 2^32; handle with bitwise AND (`& 0xFFFFFFFF`)
4. **Distance Reset**: Call `sensorService.resetDistance()` at run start (line 34, RecordingPage); else lap distance = global distance
5. **GPS Permission**: Request BOTH `LocationPermission.always` AND `whileInUse` checks (not OR, properly sequenced)
6. **Device Reconnection**: If device disconnects, `_handleDisconnection()` nullifies `_connectedDevice` and restarts scan

## Building & Running

### Build Commands
```bash
# Flutter setup (one-time)
flutter pub get

# Run on Android/iOS
flutter run

# Run in release mode (performance testing)
flutter run --release

# Build APK (Android)
flutter build apk --release
```

### Debugging Sensor Data
- **Print statements** are active throughout SensorService (e.g., "SUCCESS! Speed:", "POWER RECEIVED:")
- Monitor Android logcat: `adb logcat | grep flutter`
- Use Bluetooth sniffer tools (nRF Connect app) to verify HCI packets

## Key Dependencies
- `flutter_blue_plus: ^1.35.3` — Bluetooth scanning/connection
- `geolocator: ^10.1.0` — GPS fallback speed
- `sensors_plus: ^6.1.1` — Accelerometer (setup page validation)
- `shared_preferences: ^2.5.4` — Persist BT sensor device ID
- `permission_handler: ^11.3.1` — Runtime permissions
- `wakelock_plus: ^1.2.8` — Keep screen/CPU awake during recording

## When Modifying Features

### Adding a New Sensor
1. Add UUID/characteristic IDs to [SensorService](lib/sensor_service.dart) line ~86-87
2. Parse data in `_connectToDevice()` or create new `_parse[SensorName]Data()` method
3. Create new broadcast StreamController (follow `_speedController` pattern)
4. Emit updates in parsing method
5. Subscribe in relevant page's `initState()` with `mounted` guards

### Adding a New Protocol
1. Create new instructions page (see [coast_down_instructions.dart](lib/coast_down_instructions.dart))
2. Add protocol card to [protocol_selection_page.dart](lib/protocol_selection_page.dart)
3. Create new recording variant (inherit from RecordingPage or duplicate with protocol-specific logic)

### Changing UI Theme
- Dark mode: Edit [main.dart](main.dart#L26) `theme: ThemeData(brightness: Brightness.dark)`
- Light mode: Edit pages individually (e.g., protocol_selection_page uses `backgroundColor: Colors.white`)

## File Structure
- **Main entry**: [main.dart](main.dart) — initializes SensorService and routes to SensorSetupPage
- **Core logic**: [sensor_service.dart](lib/sensor_service.dart) — all Bluetooth/GPS/distance calculations
- **Pages**: Each test phase has a page (setup → protocol → instructions → input → recording)
- **Analysis**: [analysis_options.yaml](analysis_options.yaml) — linting rules (follow existing patterns)

---
Last Updated: January 2025 | Flutter SDK: ^3.10.4
