import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'recording_page.dart';
import 'analysis_page.dart';
import 'sensor_service.dart';
import 'ui/common_widgets.dart';

class PressureInputPage extends StatefulWidget {
  final String protocol; // 'constant_power', 'lap_efficiency', or 'coast_down'
  
  const PressureInputPage({
    super.key,
    this.protocol = 'coast_down',
  });

  @override
  State<PressureInputPage> createState() => _PressureInputPageState();
}

class _PressureInputPageState extends State<PressureInputPage> {
  // Controllers for pressure input
  final TextEditingController _rearController = TextEditingController(text: "60.0");

  int completedRuns = 0;
  String _pressureUnit = 'PSI';
  String _bikeType = 'Road';
  double _calculatedFrontPressure = 60.0;
  final List<Map<String, double>> _previousPressures = []; // Store previous run pressures
  
  // Silca pressure ratios (front as % of rear) based on bike type
  final Map<String, double> _silcaRatios = {
    'Road': 0.95,        // Front slightly lower for road bikes
    'Mountain': 0.85,    // MTBs prefer lower front pressure
    'Gravel': 0.90,      // Gravel slightly lower than rear
    'Hybrid': 0.90,      // Hybrid same as gravel
    'BMX': 1.00,         // BMX tends to use equal pressure
  };

  @override
  void initState() {
    super.initState();
    // Ensure any previous recording session is closed when starting a new flow
    // But be careful not to close it if we are just returning from a run.
    // Actually, PressureInputPage is created fresh when coming from Instructions.
    // It is NOT re-created between runs if we just push RecordingPage.
    // So initState runs once at the beginning of the 3-run sequence.
    SensorService().stopRecordingSession();
    
    _loadSettings();
    _rearController.addListener(_updateFrontPressure);
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pressureUnit = prefs.getString('pressure_unit') ?? 'PSI';
      _bikeType = prefs.getString('bike_type') ?? 'Road';

      // Set default pressure based on unit
      if (_pressureUnit == 'Bar') {
        _rearController.text = "5.0";
      } else {
        _rearController.text = "60.0";
      }
      _updateFrontPressure();
    });
  }
  
  void _updateFrontPressure() {
    // Replace comma with dot to support formatted inputs (e.g. from iOS keyboard)
    String cleanText = _rearController.text.replaceAll(',', '.');
    final rearValue = double.tryParse(cleanText);
    
    if (rearValue != null && rearValue > 0) {
      final ratio = _silcaRatios[_bikeType] ?? 0.95;
      setState(() {
        _calculatedFrontPressure = rearValue * ratio;
      });
    }
  }

  @override
  void dispose() {
    _rearController.removeListener(_updateFrontPressure);
    _rearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        backgroundColor: bgLight,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          "PRESSURE INPUT", 
          style: TextStyle(color: Color(0xFF222222), fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16)
        ),
        centerTitle: true,
        foregroundColor: const Color(0xFF222222),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "RUN #${completedRuns + 1}", 
                            style: const TextStyle(color: accentGemini, fontWeight: FontWeight.w900, fontSize: 24)
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: accentGemini.withAlpha((0.1 * 255).round()),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: accentGemini, width: 1.5),
                            ),
                            child: Text(
                              "$completedRuns - DONE", 
                              style: const TextStyle(color: accentGemini, fontSize: 12, fontWeight: FontWeight.bold)
                            ),
                          ),
                        ],
                      ),
                      
                      // Pressure selection guidance
                      const SizedBox(height: 20),
                      AppCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pressure Selection',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF222222)),
                            ),
                            const SizedBox(height: 8),
                            _pressureGuideStep('Run 1', 'HIGHEST  (sidewall/rim max)'),
                            const SizedBox(height: 6),
                            _pressureGuideStep('Run 2', 'MINIMUM  (sidewall min)'),
                            const SizedBox(height: 6),
                            _pressureGuideStep('Run 3', 'MIDDLE  between Max & Min'),
                            const SizedBox(height: 6),
                            _pressureGuideStep('Run 4+', 'Any pressure between Max & Min'),
                          ],
                        ),
                      ),
                      
                      // Show previous run pressures if any
                      const SizedBox(height: 20),
                      if (_previousPressures.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: AppCard(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Previous Runs',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF666666)),
                                ),
                                const SizedBox(height: 8),
                                ..._previousPressures.asMap().entries.map((entry) {
                                  int idx = entry.key;
                                  Map<String, double> pressure = entry.value;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      'Run ${idx + 1}: Front ${pressure['front']!.toStringAsFixed(_pressureUnit == 'Bar' ? 2 : 1)} $_pressureUnit  |  Rear ${pressure['rear']!.toStringAsFixed(_pressureUnit == 'Bar' ? 2 : 1)} $_pressureUnit',
                                      style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 30),
                      Row(
                        children: [
                          // FRONT PRESSURE - Read-only, calculated from rear based on Silca ratios
                          Expanded(
                            child: Container(
                              height: 125, // Fixed height to match neighbor
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: cardBorder, width: 1),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "FRONT $_pressureUnit", 
                                    style: const TextStyle(color: accentGemini, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _calculatedFrontPressure.toStringAsFixed(_pressureUnit == 'Bar' ? 2 : 1),
                                    style: const TextStyle(color: Color(0xFF222222), fontSize: 32, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "$_bikeType Ratio",
                                    style: const TextStyle(color: Color(0xFF888888), fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // REAR PRESSURE - User input
                          Expanded(
                            child: SizedBox(
                              height: 125,
                              child: _buildPressureField("REAR $_pressureUnit", _rearController)
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentGemini,
                            foregroundColor: bgLight,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                          onPressed: () async {
                            String cleanText = _rearController.text.replaceAll(',', '.');
                            final rearVal = double.tryParse(cleanText) ?? 0.0;
                            
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RecordingPage(
                                  frontPressure: _calculatedFrontPressure,
                                  rearPressure: rearVal,
                                  protocol: widget.protocol,
                                  pressureUnit: _pressureUnit,
                                ),
                              ),
                            );

                            if (result == true) {
                              setState(() {
                                // Store current run pressure
                                _previousPressures.add({
                                  'front': _calculatedFrontPressure,
                                  'rear': rearVal,
                                });
                                completedRuns++;
                              });
                            }
                          },
                          child: const Text(
                            "START RUN", 
                            style: TextStyle(fontWeight: FontWeight.bold)
                          ),
                        ),
                      ),
                      if (completedRuns >= 3) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: accentGemini, width: 2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                            onPressed: () async {
                              // Stop recording and get FIT file path
                              final fitPath = SensorService().getFitFilePath();
                              if (fitPath == null) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('No recording session found. Please complete at least one run first.')),
                                );
                                return;
                              }
                              
                              // Capture navigator before async call to avoid BuildContext warning
                              final navigator = Navigator.of(context);
                              await SensorService().stopRecordingSession();
                              
                              // Navigate to analysis page using captured navigator
                              if (!mounted) return;
                              navigator.pushReplacement(
                                MaterialPageRoute(
                                  builder: (context) => AnalysisPage(
                                    fitFilePath: fitPath,
                                    protocol: widget.protocol,
                                    bikeType: _bikeType.toLowerCase(),
                                  ),
                                ),
                              );
                            },
                            child: const Text(
                              "FINISH AND CALCULATE", 
                              style: TextStyle(color: accentGemini, fontWeight: FontWeight.bold)
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPressureField(String label, TextEditingController controller) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.03 * 255).round()),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label, 
            style: const TextStyle(color: accentGemini, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Color(0xFF222222), fontSize: 32, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pressureGuideStep(String run, String guidance) {
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            run,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: accentGemini),
          ),
        ),
        Expanded(
          child: Text(
            guidance,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
          ),
        ),
      ],
    );
  }
}
