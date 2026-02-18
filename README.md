# Perfect Pressure - Tire Optimization App

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)
![Bluetooth](https://img.shields.io/badge/Bluetooth-0082FC?style=for-the-badge&logo=bluetooth&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-iOS%20|%20Android-lightgrey?style=for-the-badge)

**Perfect Pressure** is a specialized precision cycling tool designed to determine the mathematically optimal tire pressure for a specific rider, bike, and surface combination. By measuring the relationship between Speed/Distance and Power Output across multiple test runs, the app calculates the exact point where rolling resistance is minimized before surface impedance (vibration) causes it to rise again.

## 🚴 Core Purpose & Methodology

The application implements a **3-Run Minimum Protocol** using Quadratic Regression to identify the "vertex" of your tire pressure efficiency curve.

### Testing Protocols
1.  **Coast-Down (Gravity):**
    -   **Action:** Coast down a hill with no pedaling.
    -   **Requirement:** At least 3 runs at different pressures.
    -   **Note:** Minimizes variables; Power Meter *not* required.
2.  **Constant Power / Speed:**
    -   **Action:** Ride a flat road at a steady effort.
    -   **Requirement:** At least 3 runs.
    -   **Data:** Speed vs. Wattage efficiency.
3.  **Lap Efficiency (Chung Method):**
    -   **Action:** Ride a closed loop.
    -   **Requirement:** At least 3 laps per pressure.
    -   **Data:** Avg Power vs. Avg Speed (Virtual Elevation).

## ✨ Key Features

-   **Persistent Bluetooth Connectivity:** connects to Cycle Speed & Cadence (CSC) sensors and Power Meters.
-   **Continuous FIT File Recording:** Streams sensor data (Speed, Power, Cadence) directly to a `.fit` file on disk to minimize RAM usage and prevent data loss.
-   **Quadratic Regression Analysis:** Solves for the Coefficient of Rolling Resistance (CRR) vertex.
-   **Foreground Service Architecture:** Ensures recording continues reliably even when the app is backgrounded or the screen is off.
-   **Real-time Sensor Fusion:** Prioritizes Bluetooth wheel revolutions for speed accuracy, falling back to GPS only when necessary.

## 🛠 Tech Stack

-   **Framework:** [Flutter](https://flutter.dev/) (Dart)
-   **Bluetooth:** `flutter_blue_plus` (GATT profile management)
-   **Location:** `geolocator` (GPS fallback)
-   **Sensors:** `sensors_plus` (Accelerometer for vibration analysis)
-   **File I/O:** `fit_tool`, `path_provider` (Direct-to-file binary stream)
-   **Permission Handling:** `permission_handler`

## 📱 Hardware Requirements

### Supported Sensors
The app requires Bluetooth Low Energy (BLE) sensors supporting standard GATT profiles:
*   **Speed Sensor (CSC Profile):** `0x1816` Service, `0x2A5B` Characteristic (Wheel Revolutions).
*   **Power Meter (CPP Profile):** `0x1818` Service, `0x2A63` Characteristic (Instantaneous Power).

### Device Support
*   **Android:** API Level 26+ (Requires Location/Bluetooth permissions).
*   **iOS:** iOS 12.0+ (Requires Bluetooth/Location permissions).

## 🚀 Getting Started

### Prerequisites
*   [Flutter SDK](https://docs.flutter.dev/get-started/install) installed.
*   Physical testing device (Simulators do not support Bluetooth).

### Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/your-username/tyre_pressure_app.git
    cd tyre_preassure
    ```

2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Run on a physical device:**
    ```bash
    flutter run
    ```
    *Note: Ensure Bluetooth and Location services are enabled on your device.*

## 📂 Project Structure

```
lib/
├── main.dart                  # Application entry point
├── sensor_service.dart        # Core Bluetooth & Data Logic (Singleton)
├── protocol_selection_page.dart # Protocol Choice UI
├── sensor_setup_page.dart     # Bluetooth Scanning & Pairing
├── ui/                        # Reusable widgets (AppCard, etc.)
└── ...Instructions.dart       # Specific protocol guides
```

## ⚠️ Safety & Testing Guidelines

*   **Traffic:** Always choose routes with minimal or no traffic.
*   **Pressure Limits:** Never exceed the maximum or minimum pressure ratings for your rim or tire.
*   **Consistency:** Maintain body position and line choice for valid data.
*   **Mounting:** Mount the phone rigidly to the handlebars for accurate accelerometer (vibration) data.

## 🤝 Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) (coming soon) for details on our code of conduct and the process for submitting pull requests.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---
*Developed for cycling efficiency enthusiasts.*
