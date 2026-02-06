import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import 'recording_page.dart';
import 'sensor_service.dart';
import 'fit_inspector_page.dart';
import 'analysis_page.dart';
import 'ui/common_widgets.dart';

class PressureInputPage extends StatefulWidget {
  final String protocol;
  const PressureInputPage({super.key, this.protocol = 'coast_down'});

  @override
  State<PressureInputPage> createState() => _PressureInputPageState();
}

class _PressureInputPageState extends State<PressureInputPage> with SingleTickerProviderStateMixin {
  final TextEditingController _rearController = TextEditingController(text: '4.1');
  final TextEditingController _frontController = TextEditingController(text: '4.1'); // Only used in custom mode

  final List<Map<String, double>> _pastRuns = [];
  int completedRuns = 0;
  
  String _pressureUnit = 'PSI'; // Load from SharedPreferences
  
  // Bike type selection
  String _bikeType = 'road'; // 'road', 'tt', 'gravel', 'custom'
  
  // Silca front/rear pressure distribution ratios
  // Front = Rear × ratio (front_percent / rear_percent)
  static const Map<String, double> _bikeRatios = {
    'road': 0.923,      // Silca 48/52
    'tt': 1.0,          // Silca 50/50
    'gravel': 0.887,    // Silca 47/53
    'mountain': 0.869,  // Silca 46.5/53.5
  };

  final ScrollController _pastRunsScrollController = ScrollController();
  final FocusNode _rearFocus = FocusNode();
  final GlobalKey _rearFieldKey = GlobalKey();
  final FocusNode _frontFocus = FocusNode();
  final GlobalKey _frontFieldKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadPressureUnit();
    _rearFocus.addListener(() {
      if (_rearFocus.hasFocus) {
        final ctx = _rearFieldKey.currentContext;
        if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 250));
      }
    });
    _frontFocus.addListener(() {
      if (_frontFocus.hasFocus && _bikeType == 'custom') {
        final ctx = _frontFieldKey.currentContext;
        if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 250));
      }
    });
    // Listen to rear pressure changes to auto-calculate front in preset modes
    _rearController.addListener(_onRearPressureChanged);
  }

  Future<void> _loadPressureUnit() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pressureUnit = prefs.getString('pressure_unit') ?? 'PSI';
    });
  }

  @override
  void dispose() {
    _rearController.removeListener(_onRearPressureChanged);
    _frontController.dispose();
    _rearController.dispose();
    _pastRunsScrollController.dispose();
    _rearFocus.dispose();
    _frontFocus.dispose();
    super.dispose();
  }

  /// Auto-calculate front pressure from rear × Silca ratio
  void _onRearPressureChanged() {
    final rear = double.tryParse(_rearController.text) ?? 0.0;
    final ratio = _bikeRatios[_bikeType] ?? 0.923;
    final front = rear * ratio;
    _frontController.text = front.toStringAsFixed(1);
  }

  /// Change bike type (and update front pressure if needed)
  void _setBikeType(String bikeType) {
    setState(() {
      _bikeType = bikeType;
    });
    _onRearPressureChanged(); // Recalculate front if switching to preset
  }

  String get _protocolTitle {
    switch (widget.protocol) {
      case 'coast_down':
        return 'Coast-Down (Gravity)';
      case 'constant_power':
        return 'Constant Power / Speed';
      case 'lap_efficiency':
        return 'Lap Efficiency (Chung)';
      default:
        return 'Protocol';
    }
  }

  String get _protocolHint {
    switch (widget.protocol) {
      case 'coast_down':
        return 'No pedaling — hill coast runs. 3+ runs recommended.';
      case 'constant_power':
        return 'Flat road, steady effort; record speed vs. power.';
      case 'lap_efficiency':
        return 'Closed loop laps; record average power and speed.';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Disable back navigation to preserve protocol integrity
      child: Scaffold(
        backgroundColor: bgLight,
        appBar: AppBar(
          backgroundColor: bgLight,
          elevation: 0,
          automaticallyImplyLeading: false, // Remove back button
          title: const Text(
            'PRESSURE INPUT',
            style: TextStyle(color: Color(0xFF222222), fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16),
          ),
          centerTitle: true,
          foregroundColor: const Color(0xFF222222),
          actions: [
            IconButton(
              tooltip: 'Inspect last FIT',
              icon: const Icon(Icons.search, color: Color(0xFF222222)),
              onPressed: () async {
                if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => const FitInspectorPage()));
              },
            ),
          ],
        ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final insets = MediaQuery.of(context).viewInsets.bottom;
          final available = (constraints.maxHeight - insets).clamp(0.0, double.infinity);
          final appCardHeight = math.min(320.0, available * 0.45);

          // compute card sizes here (can't declare variables inside widget children)
          final baseCardHeight = insets > 0 ? math.max(80.0, appCardHeight * 0.45) : appCardHeight;
          final displayedCardHeight = math.max(60.0, baseCardHeight - 7.0);

          return SingleChildScrollView(
            padding: EdgeInsets.only(bottom: insets),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: available),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('RUN #${completedRuns + 1}', style: const TextStyle(color: accentGemini, fontWeight: FontWeight.w800, fontSize: 22)),
                            const SizedBox(height: 4),
                            Text(_protocolTitle, style: const TextStyle(color: Color(0xFF888888), fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: accentGemini.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('$completedRuns/3 DONE', style: const TextStyle(color: accentGemini, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    if (_protocolHint.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(_protocolHint, style: const TextStyle(color: Color(0xFF666666), fontSize: 13)),
                    ],
                    const SizedBox(height: 24),

                    // BIKE TYPE SELECTOR
                    Text('Bike Type', style: const TextStyle(color: Color(0xFF222222), fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildBikeTypeButton('Road', 'road'),
                        const SizedBox(width: 8),
                        _buildBikeTypeButton('TT', 'tt'),
                        const SizedBox(width: 8),
                        _buildBikeTypeButton('Gravel', 'gravel'),
                        const SizedBox(width: 8),
                        _buildBikeTypeButton('MTB', 'mountain'),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Previous Runs card — shrink smoothly when keyboard is visible instead of hiding
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      child: AppCard(
                        height: displayedCardHeight,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Previous Runs', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF222222))),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: [
                                    const Expanded(child: Text('Run', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF222222)))),
                                    Expanded(child: Text('Front $_pressureUnit', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF222222)))),
                                    Expanded(child: Text('Rear $_pressureUnit', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF222222)))),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),

                              SizedBox(
                                height: math.max(60.0, (displayedCardHeight) - 110.0),
                                child: _pastRuns.isEmpty
                                    ? const Center(child: Text('No previous runs', style: TextStyle(color: Color(0xFF222222))))
                                    : Scrollbar(
                                        controller: _pastRunsScrollController,
                                        thumbVisibility: true,
                                        child: ListView.separated(
                                          controller: _pastRunsScrollController,
                                          physics: const BouncingScrollPhysics(),
                                          itemCount: _pastRuns.length,
                                          separatorBuilder: (_, __) => const Divider(height: 1),
                                          itemBuilder: (context, i) {
                                            final r = _pastRuns[i];
                                            return Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 8),
                                              child: Row(
                                                children: [
                                                  Expanded(child: Text('#${i + 1}', style: const TextStyle(color: Color(0xFF222222)))),
                                                  Expanded(child: Text((r['front'] ?? 0.0).toStringAsFixed(1), style: const TextStyle(color: Color(0xFF222222)))),
                                                  Expanded(child: Text((r['rear'] ?? 0.0).toStringAsFixed(1), style: const TextStyle(color: Color(0xFF222222)))),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: AppCard(
                            child: _pressureFieldBody('FRONT $_pressureUnit', _frontController, key: _frontFieldKey, focusNode: _frontFocus, readOnly: true),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: AppCard(
                            child: _pressureFieldBody('REAR $_pressureUnit', _rearController, key: _rearFieldKey, focusNode: _rearFocus),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentGemini,
                          foregroundColor: bgLight,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () async {
                          final front = double.tryParse(_frontController.text) ?? 0.0;
                          final rear = double.tryParse(_rearController.text) ?? 0.0;

                          final result = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(builder: (context) => RecordingPage(frontPressure: front, rearPressure: rear, protocol: widget.protocol)),
                          );

                          if (result == true) {
                            setState(() {
                              completedRuns++;
                              _pastRuns.add({'front': front, 'rear': rear});
                            });

                            final msg = 'Run saved: front=${front.toStringAsFixed(1)} rear=${rear.toStringAsFixed(1)} | totalRuns=${_pastRuns.length}';
                            // ignore: avoid_print
                            print(msg);
                            // ignore: use_build_context_synchronously
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                          }
                        },
                        child: const Text('START RUN', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                      ),
                    ),

                    if (completedRuns >= 3) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: accentGemini, width: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () => _onFinishAndCalculate(context),
                          child: const Text('FINISH AND CALCULATE', style: TextStyle(color: accentGemini, fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      ), // PopScope
    );
  }

  void _onFinishAndCalculate(BuildContext context) async {
    if (completedRuns < 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Need at least 3 runs to calculate.')));
      return;
    }

    // show modal progress
    showDialog<void>(context: context, barrierDismissible: false, builder: (_) {
      return const AlertDialog(
        content: SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
      );
    });

    try {
      // Finalize the shared recording session so a single FIT file contains
      // all recorded laps. SensorService maintains the writer across runs.
      await SensorService().finalizeRecordingSession();

      // Get the FIT file path from the sensor service or reconstruct it
      // For now, we'll use a known pattern - look for the most recent FIT file
      final sensorService = SensorService();
      
      // Give the file a moment to write
      await Future.delayed(const Duration(milliseconds: 500));

      // Dismiss progress and launch analysis page
      if (mounted) {
        Navigator.of(context).pop(); // Dismiss progress dialog
        
        // Launch AnalysisPage with the FIT file path
        // This assumes the FIT file was just created - in production you'd pass the actual path
        final fitPath = sensorService.getLastRecordingPath(); // You'll need to add this method
        
        if (mounted && fitPath != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AnalysisPage(fitFilePath: fitPath, protocol: widget.protocol, bikeType: _bikeType),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not locate analysis file')),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save analysis: $e')));
    }
  }

  Widget _pressureFieldBody(String label, TextEditingController controller, {Key? key, FocusNode? focusNode, bool readOnly = false}) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: readOnly ? BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF888888), fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            focusNode: focusNode,
            controller: controller,
            readOnly: readOnly,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
              color: readOnly ? const Color(0xFF999999) : const Color(0xFF222222),
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
            decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
          ),
        ],
      ),
    );
  }

  /// Build bike type selection button
  Widget _buildBikeTypeButton(String label, String bikeType) {
    final isSelected = _bikeType == bikeType;
    return Expanded(
      child: GestureDetector(
        onTap: () => _setBikeType(bikeType),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? accentGemini : const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? accentGemini : const Color(0xFFDDDDDD),
              width: 2,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF222222),
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}