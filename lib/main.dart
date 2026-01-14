import 'package:flutter/material.dart';
import 'sensor_service.dart';
import 'sensor_setup_page.dart'; // <--- ADD THIS IMPORT

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final sensorService = SensorService();
  await sensorService.loadSavedSensors();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tyre Pressure App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark, // Changed to Dark to match your Setup/Input pages
        useMaterial3: true,
      ),
      // CHANGE THIS LINE BELOW:
      home: const SensorSetupPage(), // <--- Starts the flow correctly
    );
  }
}