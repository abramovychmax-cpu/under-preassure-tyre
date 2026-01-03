import 'package:flutter/material.dart'; // Import basic UI building blocks
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; // Import Bluetooth tools
import 'package:geolocator/geolocator.dart'; // Import GPS/Location tools
import 'package:sensors_plus/sensors_plus.dart'; // Import Accelerometer tools
import 'dart:async'; // Import tools for data streams (real-time info)

// FUNCTION: 'main' is the entry point that kicks off the whole app
void main() {
  runApp(const TireLabApp()); // Action: Run the TireLabApp class
}

// CLASS: This is the "Blueprint" for the entire App's theme and structure
class TireLabApp extends StatelessWidget {
  const TireLabApp({super.key}); // Constructor: Sets up this class

  @override // Replaces default code with our custom design
  Widget build(BuildContext context) {
    return MaterialApp( // A wrapper providing standard app navigation/styles
      title: 'Tire Lab Pro', // The app's name in the phone's system
      theme: ThemeData( // Defines the colors and fonts
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue), // Blue theme
        useMaterial3: true, // Uses the modern Android/iOS style
      ),
      home: const SensorSetupPage(), // Set the first screen to our Setup Page
      debugShowCheckedModeBanner: false, // Hides the "Debug" banner
    );
  }
}

// CLASS: The Blueprint for the Sensor Screen (Stateful means it can change)
class SensorSetupPage extends StatefulWidget {
  const SensorSetupPage({super.key});

  @override // Connects this class to the 'State' logic below
  State<SensorSetupPage> createState() => _SensorSetupPageState();
}

// CLASS (STATE): This holds the live data and refreshes the UI
class _SensorSetupPageState extends State<SensorSetupPage> {
  // VARIABLES: "Boxes" to store the names and status of your gear
  String speedSensorName = "Not Connected"; // Stores speed sensor name
  String powerMeterName = "Not Connected"; // Stores power meter name
  String cadenceStatus = "Waiting for Power..."; // Stores cadence info
  bool gpsGranted = false; // Tracks if the user allowed GPS
  bool accelActive = false; // Tracks if the motion sensor is sending data

  // BLUETOOTH DATA: Stores the list of sensors found during a scan
  List<ScanResult> scanResults = []; // A list (collection) of found devices
  StreamSubscription? scanSubscription; // A "listener" for the Bluetooth radio

  @override
  // FUNCTION: 'initState' runs once immediately when the app opens
  void initState() {
    super.initState(); // Does standard Flutter setup first
    _initInternalSensors(); // Action: Start checking GPS and Motion right away
  }

  // FUNCTION (Async): Checks GPS and Motion (Async means it waits for a reply)
  Future<void> _initInternalSensors() async {
    // Action: Check if GPS permission is already granted
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) { // If it's blocked...
      permission = await Geolocator.requestPermission(); // ...ask the user for access
    }
    
    // If the user said yes, update our variable and refresh the screen
    if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
      setState(() => gpsGranted = true); // Refresh UI
    }

    // Action: Start listening to the Accelerometer stream
    accelerometerEvents.listen((AccelerometerEvent event) {
      if (!accelActive) { // If we haven't confirmed it's working yet...
        setState(() => accelActive = true); // ...mark it as active now
      }
    });
  }

  // FUNCTION: Searches for Bluetooth sensors using their specific "Service ID"
  void _startSensorScan(String serviceUuid) async {
    setState(() => scanResults.clear()); // Clear previous search results

    // Action: Tell the phone to look for specific cycling gear
    await FlutterBluePlus.startScan(
      withServices: [Guid(serviceUuid)], // 1816 for Speed, 1818 for Power
      timeout: const Duration(seconds: 5), // Stop searching after 5 seconds
    );

    // Action: Watch the "stream" of found devices and add them to our list
    scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      setState(() => scanResults = results); // Update list on screen
    });

    _showDevicePicker(serviceUuid); // Action: Open the selection menu
  }

  // FUNCTION: Creates the pop-up menu for the user to select their sensor
  void _showDevicePicker(String serviceId) {
    showModalBottomSheet( // A sliding menu from the bottom
      context: context,
      builder: (context) {
        return Container( // A container box for the list
          padding: const EdgeInsets.all(16),
          height: 350,
          child: ListView.builder( // Builds a row for every sensor found
            itemCount: scanResults.length, // How many items in the list
            itemBuilder: (context, index) {
              final data = scanResults[index]; // Get data for this specific row
              return ListTile( // A clickable row
                title: Text(data.advertisementData.localName.isEmpty 
                    ? "Unknown Sensor" : data.advertisementData.localName),
                subtitle: Text(data.device.remoteId.toString()), // Show ID
                onTap: () { // Action when user clicks the sensor name
                  setState(() { // Update the main UI with the choice
                    if (serviceId == "1816") speedSensorName = data.advertisementData.localName;
                    if (serviceId == "1818") {
                      powerMeterName = data.advertisementData.localName;
                      cadenceStatus = "Linked to Power Meter";
                    }
                  });
                  Navigator.pop(context); // Close the menu
                  FlutterBluePlus.stopScan(); // Turn off radio to save battery
                },
              );
            },
          ),
        );
      },
    );
  }

  // WIDGET BUILDER: A reusable function to draw each of the 5 windows
  Widget sensorWindow(String title, String subtitle, bool isActive, IconData icon, VoidCallback? onConnect) {
    return Card( // A box with a shadow
      color: isActive ? Colors.green.withOpacity(0.1) : Colors.white, // Green tint if ready
      elevation: 0,
      shape: RoundedRectangleBorder( // Adds a border around the box
        side: BorderSide(color: isActive ? Colors.green : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile( // A row with an icon, title, and optional button
        leading: Icon(icon, color: isActive ? Colors.green : Colors.grey), // Sensor icon
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), // Sensor name
        subtitle: Text(subtitle), // Status text (e.g., "Not Connected")
        trailing: onConnect != null // If an 'Action' was provided...
          ? IconButton(icon: const Icon(Icons.add_circle, color: Colors.blue), onPressed: onConnect) // ...show '+'
          : (isActive ? const Icon(Icons.check_circle, color: Colors.green) : null), // ...else show checkmark
      ),
    );
  }

  @override // This "Function" describes how the whole screen looks
  Widget build(BuildContext context) {
    return Scaffold( // The basic layout skeleton
      appBar: AppBar(title: const Text("Tire Lab: Sensor Setup")), // Top header
      body: Padding( // Space around the edges
        padding: const EdgeInsets.all(16.0),
        child: Column( // Stack the 5 windows on top of each other
          children: [
            // CALLING SENSOR WINDOWS: Using our function 5 times
            sensorWindow("GPS Location", gpsGranted ? "Ready" : "Tap to enable", gpsGranted, Icons.location_on, null),
            sensorWindow("Accelerometer", accelActive ? "Ready" : "Waiting for motion", accelActive, Icons.vibration, null),
            
            const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()), // Line separator
            
            sensorWindow("Speed Sensor", speedSensorName, speedSensorName != "Not Connected", Icons.speed, () => _startSensorScan("1816")),
            sensorWindow("Power Meter", powerMeterName, powerMeterName != "Not Connected", Icons.bolt, () => _startSensorScan("1818")),
            sensorWindow("Cadence", cadenceStatus, powerMeterName != "Not Connected", Icons.autorenew, null),

            const Spacer(), // Pushes the button to the very bottom

            // ACTION BUTTON: The "Go" button for the test
            SizedBox(
              width: double.infinity, // Full width
              height: 50,
              child: ElevatedButton(
                // Logic: Only active if GPS is working and Speed is connected
                onPressed: (gpsGranted && speedSensorName != "Not Connected") ? () {
                  // Action: Move to the next screen (Scenario Selection)
                } : null, // Greyed out if sensors are missing
                child: const Text("NEXT: SELECT TEST PROTOCOL"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}