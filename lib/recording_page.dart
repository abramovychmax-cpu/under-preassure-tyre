import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sensor_service.dart';

class RecordingPage extends StatefulWidget {
  final double frontPressure;
  final double rearPressure;
  final String protocol;

  const RecordingPage({
    super.key,
    required this.frontPressure,
    required this.rearPressure,
    this.protocol = 'unknown',
  });

  @override
  State<RecordingPage> createState() => _RecordingPageState();
}

class _RecordingPageState extends State<RecordingPage> {
  final SensorService _sensorService = SensorService();
  double currentSpeed = 0.0;
  double currentDistance = 0.0;
  int currentPower = 0;
  int currentCadence = 0;
  double currentVibration = 0.0;
  DateTime? _runStart;
  Duration _elapsed = Duration.zero;
  Timer? _elapsedTimer;
  String _speedUnit = 'km/h'; // Load from SharedPreferences

  StreamSubscription? _speedSub;
  StreamSubscription? _distSub;
  StreamSubscription? _powerSub;
  StreamSubscription? _cadenceSub;
  StreamSubscription? _vibrationSub;

  @override
  void initState() {
    super.initState();
    _loadSpeedUnit();

    // Ensure keyboard is hidden and page doesn't resize when keyboard appears
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        FocusScope.of(context).unfocus();
      } catch (_) {}
      try {
        SystemChannels.textInput.invokeMethod('TextInput.hide');
      } catch (_) {}
    });

    // Initialize sensor session for this run
    _sensorService.resetDistance();
    // Don't call loadSavedSensors() here - sensors should already be connected from SensorSetupPage
    // Calling it again might cause unnecessary re-scanning and connection interruption
    
    // start FIT/JSONL recording session for this run
    _sensorService.startRecordingSession(widget.frontPressure, widget.rearPressure, protocol: widget.protocol);

    _distSub = _sensorService.distanceStream.listen((dist) {
      if (mounted) setState(() => currentDistance = dist);
    });

    _speedSub = _sensorService.speedStream.listen((speed) {
      if (mounted) setState(() => currentSpeed = speed);
    });

    _powerSub = _sensorService.powerStream.listen((power) {
      if (mounted) setState(() => currentPower = power);
    });

    _cadenceSub = _sensorService.cadenceStream.listen((rpm) {
      if (mounted) setState(() => currentCadence = rpm);
    });

    _vibrationSub = _sensorService.vibrationStream.listen((v) {
      if (mounted) setState(() => currentVibration = v);
    });

    // Start run elapsed timer automatically when RecordingPage is shown
    _runStart = DateTime.now();
    _elapsed = Duration.zero;
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsed = DateTime.now().difference(_runStart!);
      });
    });
  }

  Future<void> _loadSpeedUnit() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _speedUnit = prefs.getString('speed_unit') ?? 'km/h';
    });
  }

  double _convertSpeed(double kmh) {
    if (_speedUnit == 'mph') {
      return kmh * 0.621371;
    }
    return kmh;
  }

  @override
  void dispose() {
    _distSub?.cancel();
    _speedSub?.cancel();
    _powerSub?.cancel();
    _cadenceSub?.cancel();
    _vibrationSub?.cancel();
    _elapsedTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFF2F2F2),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Text(
              'RECORDING RUN',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.1),
            ),
            Text(
              'LAP METADATA: ${widget.frontPressure}/${widget.rearPressure} BAR',
              style: TextStyle(fontSize: 14, color: Colors.black.withAlpha((0.4 * 255).round()), fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 30),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _buildDataRow('SPEED', _convertSpeed(currentSpeed).toStringAsFixed(1), _speedUnit, 'POWER', '$currentPower', 'watts'),
                    _buildDataRow('CADENCE', '$currentCadence', 'RPM', 'vibrations', currentVibration.toStringAsFixed(2), 'g'),
                    _buildDataRow('DISTANCE', currentDistance.toStringAsFixed(2), 'km', 'TIME LAPSED', _formatDuration(_elapsed), '_'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: () {
                  // Just pop. The recording session continues in the background (Wait State)
                  // The next run will trigger a new Lap.
                  // The final "Fishish and Calculate" on the input page will stop the session.
                  Navigator.of(context).pop(true);
                },
                child: const Text(
                  'MARK RUN COMPLETE',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(String label1, String val1, String unit1, String label2, String val2, String unit2) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(child: _buildCard(label1, val1, unit1)),
            const SizedBox(width: 20),
            Expanded(child: _buildCard(label2, val2, unit2)),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(String label, String value, String unit) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE0E0E0),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.05 * 255).round()),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.black.withAlpha((0.5 * 255).round()), fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D))),
          ),
          Text(unit, style: TextStyle(fontSize: 14, color: Colors.black.withAlpha((0.4 * 255).round()))),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    return '${two(hours)}:${two(minutes)}:${two(seconds)}';
  }

}