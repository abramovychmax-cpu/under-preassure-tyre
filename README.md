# Perfect Pressure — Tire Optimization App

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)
![Bluetooth](https://img.shields.io/badge/Bluetooth-0082FC?style=for-the-badge&logo=bluetooth&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-iOS%20|%20Android-lightgrey?style=for-the-badge)
![Version](https://img.shields.io/badge/version-1.0.4-blue?style=for-the-badge)

**Perfect Pressure** is a precision cycling tool that determines the mathematically optimal tire pressure for a specific rider, bike, and surface combination. By measuring the relationship between Speed/Distance and Power Output across multiple test runs, the app calculates the exact point where rolling resistance is minimized before surface impedance (vibration) causes it to rise again.

---

## 🚴 Core Methodology

The application implements a **3-Run Minimum Protocol** using Quadratic Regression to identify the vertex of your pressure-efficiency curve — the sweet spot between too-hard (harsh, vibrating) and too-soft (high rolling resistance) tires.

### Testing Protocols

| Protocol | Action | Power Meter Required | Min Runs |
|---|---|---|---|
| **Coast-Down** | Coast a hill with no pedaling | No | 3 |
| **Constant Power** | Flat road at steady wattage | Yes | 3 |
| **Lap Efficiency** (Chung) | Closed loop — Avg Power vs Avg Speed | Yes | 3 |

---

## ✨ Features

- **Persistent Bluetooth Connectivity** — Connects and holds CSC (Speed/Cadence) and Power Meter sensors via standard GATT profiles. Automatically reconnects on drop.
- **GPS Speed Fallback** — When no Bluetooth speed sensor is paired, GPS-derived speed is used seamlessly as a substitute.
- **Continuous FIT File Recording** — All run data is streamed directly to a `.fit` file on disk (not buffered in RAM). Uses FIT Lap messages to tag each pressure interval.
- **Quadratic Regression Analysis** — After 3+ runs the app solves for the Coefficient of Rolling Resistance (CRR) vertex and displays the optimal pressure recommendation.
- **Interactive Pressure–Efficiency Chart** — Visual curve rendered with `fl_chart` showing all tested pressures and the calculated optimum.
- **Previous Tests History** — Browse and re-analyse past FIT files stored on device.
- **FIT File Inspector** — In-app viewer to inspect raw FIT message records from any session.
- **Silca Pressure Ratios** — Front pressure is automatically calculated from rear input using bike-type-specific Silca ratios (Road 95 %, MTB 85 %, Gravel/Hybrid 90 %).
- **Wakelock** — Keeps CPU and screen alive during active recording to prevent OS from killing Bluetooth or file I/O.
- **Standardised Dark UI** — Consistent dark theme (`#121418` background, `#47D1C1` accent) across all recording and analysis pages.

---

## 🛠 Tech Stack

| Package | Purpose |
|---|---|
| `flutter_blue_plus ^1.35.3` | BLE GATT scanning, connection, characteristic notifications |
| `geolocator ^10.1.0` | GPS speed fallback |
| `sensors_plus ^6.1.1` | Accelerometer (setup validation) |
| `fit_tool ^1.0.5` | Binary FIT file encoding / decoding |
| `path_provider ^2.1.0` | Device-local file system paths |
| `fl_chart ^0.63.0` | Pressure–efficiency curve chart |
| `share_plus ^7.2.1` | Export / share FIT files |
| `shared_preferences ^2.2.2` | Persist sensor IDs, bike settings, unit preferences |
| `permission_handler ^11.3.1` | Runtime Bluetooth + Location permissions |
| `wakelock_plus ^1.4.0` | Prevent screen/CPU sleep during recording |
| `http ^1.1.0` | Weather data fetch (wind / temperature context) |

---

## 📱 Hardware Requirements

### Bluetooth Sensors (BLE, GATT standard)

| Sensor | Service UUID | Characteristic UUID | Data |
|---|---|---|---|
| Speed / Cadence (CSC) | `0x1816` | `0x2A5B` | Cumulative wheel revolutions + time |
| Power Meter (CPP) | `0x1818` | `0x2A63` | Instantaneous watts (bytes 2–3) |

### Device Support

- **Android:** API 26+ — Location + Bluetooth permissions required
- **iOS:** iOS 12.0+ — Bluetooth + Location permissions required
- **Physical device required** — Simulators do not support Bluetooth

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) ≥ 3.0.0
- Physical Android or iOS device with Bluetooth LE

### Installation

```bash
# Clone
git clone https://github.com/abramovychmax-cpu/under-preassure-tyre.git
cd tyre_preassure

# Install dependencies
flutter pub get

# Run on device (ensure BT + Location are enabled)
flutter run

# Release build
flutter run --release
flutter build apk --release
```

---

## 📂 Project Structure

```
lib/
├── main.dart                          # App entry point, theme, routing
├── sensor_service.dart                # Bluetooth + GPS singleton service
│
├── welcome_page.dart                  # Splash / onboarding
├── safety_guide_page.dart             # Pre-ride safety checklist
├── wheel_metrics_guide_page.dart      # Wheel metrics explainer
├── wheel_metrics_page.dart            # Bike type, wheel size, unit config
├── sensor_guide_page.dart             # Sensor pairing guide
├── sensor_setup_page.dart             # BLE scanning & pairing UI
│
├── protocol_selection_page.dart       # Choose test protocol
├── coast_down_instructions.dart       # Coast-down method guide
├── constant_power_instructions.dart   # Constant power method guide
├── lap_efficiency_instructions.dart   # Lap efficiency method guide
│
├── pressure_input_page.dart           # Per-run front/rear PSI input
├── recording_page.dart                # Live sensor stream + run recording
├── analysis_page.dart                 # Quadratic regression + chart
│
├── home_page.dart                     # Dashboard / session overview
├── previous_tests_page.dart           # Saved FIT file history
├── fit_inspector_page.dart            # Raw FIT message viewer
├── settings_page.dart                 # App preferences
│
├── fit_writer.dart                    # Binary FIT file encoder
├── coast_down_service.dart            # Coast-down analysis logic
├── circle_protocol_service.dart       # Lap efficiency analysis logic
├── clustering_service.dart            # Run data clustering
├── constant_power_clustering_service.dart
├── tire_optimization_service.dart     # Quadratic regression solver
├── weather_service.dart               # Wind / temperature fetch
│
└── ui/
    └── common_widgets.dart            # AppCard, shared constants, theme
```

---

## 🔬 Algorithm Overview

1. **Data Collection** — Each run records `(pressure, avgSpeed, avgPower)` tuples, tagged by FIT Lap messages.
2. **CRR Derivation** — Rolling resistance coefficient is estimated from the speed–power relationship:  
   $C_{rr} = \frac{P - P_{aero}}{m \cdot g \cdot v}$
3. **Quadratic Regression** — Fit $f(p) = ax^2 + bx + c$ to the (pressure, CRR) dataset.
4. **Vertex** — Optimal pressure $p^* = -\frac{b}{2a}$, where rolling resistance is minimal.

---

## 🏪 App Store Submission Checklist

### Before building the release IPA

1. **Register `PrivacyInfo.xcprivacy` in Xcode** *(required — hard rejection without this since May 2024)*
   - Open `ios/Runner.xcodeproj` in Xcode
   - In the file navigator, right-click the **Runner** group → **Add Files to "Runner"**
   - Select `ios/Runner/PrivacyInfo.xcprivacy`
   - Ensure **"Add to target: Runner"** is checked → click **Add**
   - Clean build folder (`⇧⌘K`) then rebuild

2. **Set your team & signing** in Xcode → Runner target → Signing & Capabilities → select your Apple Developer team.

3. **Bundle ID** is set to `app.perfectpressure` — register it in [App Store Connect](https://appstoreconnect.apple.com) → Identifiers before first archive.

4. **App Store Connect metadata** required before submission:
   - At least one screenshot for **6.7"** and **6.1"** iPhone sizes
   - App **description**, subtitle, keywords
   - Category: **Sports** (or Health & Fitness)
   - **Privacy Policy URL** (mandatory — app uses Location)
   - Age rating questionnaire

### Release build commands

```bash
# iOS (requires macOS + Xcode)
flutter build ipa --release

# Android
flutter build apk --release
flutter build appbundle --release   # preferred for Play Store
```

---

## ⚠️ Safety & Testing Guidelines

- **Traffic** — Use routes with zero or minimal traffic.
- **Pressure Limits** — Never exceed your rim's or tire's rated max/min pressure.
- **Consistency** — Hold the same body position, line, and effort across all runs.
- **Mounting** — Secure the phone to the handlebars for valid accelerometer data.
- **Conditions** — Avoid comparing runs across significantly different wind, temperature, or road-surface conditions.

---

## 🤝 Contributing

Contributions are welcome. Please open an issue to discuss changes before submitting a pull request.

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

*Built for cycling efficiency enthusiasts. Active branch: `dev_2`.*
