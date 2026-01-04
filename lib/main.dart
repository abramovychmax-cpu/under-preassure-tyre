import 'package:flutter/material.dart';
import 'sensor_setup_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TireLabApp());
}

class TireLabApp extends StatelessWidget {
  const TireLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tire Lab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const SensorSetupPage(),
    );
  }
}