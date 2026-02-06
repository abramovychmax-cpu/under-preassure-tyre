import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'sensor_service.dart';
import 'home_page.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:background_fetch/background_fetch.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Lock to portrait orientation only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Enable wakelock for continuous background recording
  await WakelockPlus.enable();
  
  // Setup background fetch for long sessions (iOS only)
  _setupBackgroundFetch();

  final sensorService = SensorService();
  await sensorService.loadSavedSensors();

  runApp(const MyApp());
}

void _setupBackgroundFetch() {
  BackgroundFetch.configure(
    BackgroundFetchConfig(
      minimumFetchInterval: 5, // Re-wake every 5 minutes
      stopOnTerminate: false,
      enableHeadless: true,
    ),
    (String taskId) async {
      // Flush pending data to disk during background activity
      try {
        SensorService().getFitWriter()?.flush();
      } catch (_) {}
      BackgroundFetch.finish(taskId);
    },
  ).then((int status) {
    print('Background fetch initialized with status: $status');
  }).catchError((e) {
    print('Background fetch error: $e');
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

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
      title: 'Tyre Pressure App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}