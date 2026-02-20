import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'sensor_service.dart';
import 'welcome_page.dart';
import 'sensor_setup_page.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Lock to portrait orientation only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Enable wakelock for continuous background recording
  await WakelockPlus.enable();

  final sensorService = SensorService();
  await sensorService.loadSavedSensors();

  // Returning users (have saved sensors) skip onboarding and land on SensorSetupPage.
  // The scan started inside loadSavedSensors() will auto-reconnect saved devices.
  final bool returningUser = sensorService.hasSavedSensors;

  runApp(MyApp(returningUser: returningUser));
}

class MyApp extends StatefulWidget {
  final bool returningUser;
  const MyApp({super.key, this.returningUser = false});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Keep screen on while app is running in foreground
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      WakelockPlus.enable();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      WakelockPlus.disable();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Perfect Pressure',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      home: widget.returningUser ? const SensorSetupPage() : const WelcomePage(),
    );
  }
}
