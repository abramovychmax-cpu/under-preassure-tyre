import 'package:flutter/material.dart';
import 'app_logger.dart';
import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'ui/app_menu_button.dart';
import 'ui/common_widgets.dart';
import 'constant_power_clustering_service.dart';
import 'circle_protocol_service.dart';
import 'coast_down_service.dart';

/// Analysis page: Load FIT + JSONL, perform quadratic regression on tire pressure.
/// Displays optimal tire pressure recommendation based on 3+ runs.
/// Supports constant-power, circle, and coast-down protocols.
class AnalysisPage extends StatefulWidget {
  final String fitFilePath;
  final String protocol; // 'constant_power', 'lap_efficiency', or 'coast_down'
  final String bikeType;  // 'road', 'tt', 'gravel', 'mountain'

  final bool isOverlay;

  const AnalysisPage({
    required this.fitFilePath,
    required this.protocol,
    this.bikeType = 'road',
    this.isOverlay = false,
    super.key,
  });

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  bool _isLoading = true;
  String? _errorMessage;
  
  // UI Feedback states
  String _feedbackMessage = 'Loading analysis...';

  // Regression data (protocol-agnostic)
  List<MapEntry<double, double>> _regressionDataPoints = [];

  // Regression results
  double? _optimalRearPressure;
  double? _optimalFrontPressure;
  String _pressureUnit = 'PSI';
  double _rSquared = 0.0;
  double? _vibrationLossPercent;
  
  // Data quality validation
  double? _powerConsistencyPercent;  // CV of power across laps (circle/constant-power)
  String? _dataQualityWarning;       // Warning message if data quality is poor
  String _confidenceLevel = '';       // HIGH/MEDIUM/LOW based on R² and power CV

  // Tunable thresholds
  static const double _powerCvWarnThreshold = 25.0; // percent
  static const double _minQuadraticPoints = 3;
  
  // Silca front/rear pressure distribution ratios
  // Front = Rear × ratio (front_percent / rear_percent)
  static const Map<String, double> _silcaRatios = {
    'road': 0.923,      // Silca 48/52
    'tt': 1.0,           // Silca 50/50
    'gravel': 0.887,     // Silca 47/53
    'mountain': 0.869,   // Silca 46.5/53.5
  };

  // Quadratic coefficients: y = ax² + bx + c
  double? _coeffA, _coeffB, _coeffC;

  @override
  void initState() {
    super.initState();
    _loadAndAnalyze();
  }

  void _updateFeedback(String message) {
    if (mounted) {
      setState(() {
        _feedbackMessage = message;
      });
    }
  }

  double _psiToBar(double psi) => psi * 0.0689476;

  List<MapEntry<double, double>> _trimOutliers(List<MapEntry<double, double>> points) {
    if (points.length < 4) return List.of(points);
    final sorted = List<MapEntry<double, double>>.from(points)
      ..sort((a, b) => a.value.compareTo(b.value));
    // Drop min and max efficiency points (light trim)
    return sorted.sublist(1, sorted.length - 1);
  }

  Future<void> _loadAndAnalyze() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _feedbackMessage = 'Loading analysis...';
      });

      final prefs = await SharedPreferences.getInstance();
      _pressureUnit = prefs.getString('pressure_unit') ?? 'PSI';

      final jsonlPath = '${widget.fitFilePath}.jsonl';
      final jsonlFile = File(jsonlPath);
      AppLogger.log('[AnalysisPage] fitPath: ${widget.fitFilePath}');
      AppLogger.log('[AnalysisPage] jsonlPath: $jsonlPath | exists: ${jsonlFile.existsSync()}');
      final sensorPath = '${widget.fitFilePath}.sensor_records.jsonl';
      AppLogger.log('[AnalysisPage] sensorPath: $sensorPath | exists: ${File(sensorPath).existsSync()}');
      AppLogger.log('[AnalysisPage] protocol: ${widget.protocol} | bikeType: ${widget.bikeType}');
      if (!jsonlFile.existsSync()) {
        throw Exception('Companion JSONL file not found: $jsonlPath');
      }

      final fitFile = File(widget.fitFilePath);
      if (!fitFile.existsSync()) {
        throw Exception('FIT file not found: ${widget.fitFilePath}');
      }
      final fitBytes = await fitFile.readAsBytes();

      if (widget.protocol == 'constant_power' || widget.protocol == 'sim') {
        _updateFeedback('🔍 Detecting constant-power segments...');
        AppLogger.log('[AnalysisPage] Starting constant_power analysis...');
        final matchedSegments =
            await ConstantPowerClusteringService.analyzeConstantPower(
          fitBytes,
          jsonlPath,
          cda: _cdaForBikeType(widget.bikeType),
          rho: _standardAirDensity(),
        );
        AppLogger.log('[AnalysisPage] analyzeConstantPower returned ${matchedSegments.length} matched segments');
        await _analyzeConstantPowerProtocol(matchedSegments);
      } else if (widget.protocol == 'lap_efficiency') {
        _updateFeedback('🔄 Analyzing lap efficiency data...');
        final laps = await CircleProtocolService.analyzeLapsFromJsonl(
          jsonlPath,
          cda: _cdaForBikeType(widget.bikeType),
          rho: _standardAirDensity(),
        );
        await _analyzeCircleProtocol(laps);
      } else if (widget.protocol == 'coast_down') {
        _updateFeedback('📉 Analyzing coast-down data...');
        final runs = await CoastDownService.analyzeDescentRunsFromJsonl(
          jsonlPath,
          fitBytes,
        );
        await _analyzeCoastDownProtocol(runs);
      } else {
        throw Exception('Unknown protocol: ${widget.protocol}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Analysis failed: $e';
      });
    }
  }

  Future<void> _analyzeConstantPowerProtocol(
    List<MatchedSegment> matchedSegments,
  ) async {
    // matchedSegments already gate-trimmed and zone-aggregated by analyzeConstantPower
    if (matchedSegments.isEmpty) {
      AppLogger.log('[AnalysisPage] ERROR: matchedSegments is empty — throwing');
      throw Exception('No matching segments found across laps');
    }

    AppLogger.log('[AnalysisPage] _analyzeConstantPowerProtocol: ${matchedSegments.length} segments');
    for (int i = 0; i < matchedSegments.length; i++) {
      final m = matchedSegments[i];
      AppLogger.log('[AnalysisPage]   segment[$i]: ${m.pressures.length} laps | pressures=${m.pressures.map((p) => p.toStringAsFixed(1)).toList()} | efficiencies=${m.efficiencies.map((e) => e.toStringAsFixed(4)).toList()}');
    }

    final dataPoints =
        ConstantPowerClusteringService.buildRegressionPoints(matchedSegments);

    final trimmed = _trimOutliers(dataPoints);
    if (trimmed.length < 2) {
      throw Exception('Need at least 2 data points for regression');
    }

    // Calculate power consistency across matched segments
    // Each MatchedSegment contains multiple segments (one per lap)
    // Calculate average power across all segments in all matched segments
    final powers = <double>[];
    for (final matched in matchedSegments) {
      for (final segment in matched.segmentsByLap.values) {
        powers.add(segment.avgPower);
      }
    }
    final avgPower = powers.fold<double>(0, (a, b) => a + b) / powers.length;
    final powerVariance = powers.fold<double>(0, (sum, p) => sum + (p - avgPower) * (p - avgPower)) / powers.length;
    final powerCv = avgPower > 0 ? (powerVariance / (avgPower * avgPower)) : 0.0;

    setState(() {
      _regressionDataPoints = trimmed;
      _powerConsistencyPercent = powerCv * 100;
    });

    _performRegression(trimmed,
        allowTwoPoint: true,
        powerCvPercent: _powerConsistencyPercent,
        extraWarning: trimmed.length < _minQuadraticPoints ? 'Only ${trimmed.length} data points; using observed best result (low confidence).' : null);

    AppLogger.log('[AnalysisPage] regression done | optimalRear=$_optimalRearPressure | optimalFront=$_optimalFrontPressure | R²=$_rSquared | confidence=$_confidenceLevel');

    setState(() {
      _isLoading = false;
    });

    _updateFeedback('✅ Analysis complete!');
  }

  Future<void> _analyzeCircleProtocol(
    List<CircleLapData> laps,
  ) async {
    final dataPoints = CircleProtocolService.buildRegressionPoints(laps);
    final trimmed = _trimOutliers(dataPoints);
    if (trimmed.length < 2) {
      throw Exception('Need at least 2 data points for regression');
    }

    // Calculate power consistency across all laps
    final validLaps = laps.where((l) => l.isValid()).toList();
    if (validLaps.length >= 2) {
      final powers = validLaps.map((l) => l.avgPower).toList();
      final avgPower = powers.fold<double>(0, (a, b) => a + b) / powers.length;
      final powerVariance = powers.fold<double>(0, (sum, p) => sum + (p - avgPower) * (p - avgPower)) / powers.length;
      final powerCv = avgPower > 0 ? (powerVariance / (avgPower * avgPower)) : 0.0;

      setState(() {
        _powerConsistencyPercent = powerCv * 100;
      });
    }

    setState(() {
      _regressionDataPoints = trimmed;
    });

    _performRegression(trimmed,
        allowTwoPoint: true,
        powerCvPercent: _powerConsistencyPercent,
        extraWarning: trimmed.length < _minQuadraticPoints ? 'Only ${trimmed.length} data points; using observed best result (low confidence).' : null);

    setState(() {
      _isLoading = false;
    });

    _updateFeedback('✅ Analysis complete!');
  }

  Future<void> _analyzeCoastDownProtocol(
    List<CoastDownRunData> runs,
  ) async {
    // For coast-down, we use average pressure (front + rear) / 2 as the regression variable
    // And efficiency (distance / max_speed) as the dependent variable
    final dataPoints = <MapEntry<double, double>>[];
    
    for (final run in runs) {
      // Use REAR pressure as regression X-axis; front derived via Silca ratio
      dataPoints.add(MapEntry(run.rearPressure, run.efficiency));
    }

    final trimmed = _trimOutliers(dataPoints);

    if (trimmed.length < 2) {
      throw Exception('Need at least 2 data points for regression');
    }

    setState(() {
      _regressionDataPoints = trimmed;
    });

    _performRegression(trimmed,
        allowTwoPoint: true,
        extraWarning: trimmed.length < _minQuadraticPoints ? 'Only ${trimmed.length} data points; using observed best result (low confidence).' : null);

    setState(() {
      _isLoading = false;
    });

    _updateFeedback('✅ Analysis complete!');
  }

  /// CdA (m²) defaults by bike type — standard literature values.
  static double _cdaForBikeType(String bikeType) {
    switch (bikeType) {
      case 'tt':       return 0.240;
      case 'gravel':   return 0.380;
      case 'mountain': return 0.500;
      default:         return 0.320; // road
    }
  }

  /// Standard air density (kg/m³) at 20 °C, 1013 hPa.
  /// Good enough for relative comparisons; a weather-API version can refine.
  static double _standardAirDensity() => 1.204;

  void _performRegression(
    List<MapEntry<double, double>> dataPoints, {
    bool allowTwoPoint = false,
    double? powerCvPercent,
    String? extraWarning,
  }) {
    if (dataPoints.length < 2) {
      setState(() {
        _errorMessage = 'Need at least 2 data points for regression';
      });
      return;
    }

    // Two-point fallback: pick best observed point; mark low confidence
    if (dataPoints.length < _minQuadraticPoints && allowTwoPoint) {
      final best = dataPoints.reduce((a, b) => a.value >= b.value ? a : b);
      setState(() {
        _coeffA = null;
        _coeffB = null;
        _coeffC = null;
        _optimalRearPressure = best.key;
        final silcaRatio = _silcaRatios[widget.bikeType] ?? 0.923;
        _optimalFrontPressure = best.key * silcaRatio;
        _rSquared = 0.0;
        _vibrationLossPercent = null;
        _confidenceLevel = 'LOW';
        _dataQualityWarning = extraWarning ?? 'Only ${dataPoints.length} data points; chose best observed.';
      });
      return;
    }

    final n = dataPoints.length;
    final meanP = dataPoints.fold(0.0, (sum, p) => sum + p.key) / n;
    final meanE = dataPoints.fold(0.0, (sum, p) => sum + p.value) / n;

    double sumX2 = 0, sumX3 = 0, sumX4 = 0;
    double sumY = 0, sumXY = 0, sumX2Y = 0;

    for (final point in dataPoints) {
      final x = point.key - meanP;
      final y = point.value - meanE;
      
      sumX2 += x * x;
      sumX3 += x * x * x;
      sumX4 += x * x * x * x;
      sumY += y;
      sumXY += x * y;
      sumX2Y += x * x * y;
    }

    final det = n * (sumX2 * sumX4 - sumX3 * sumX3) - 
                0 * (0 * sumX4 - sumX3 * sumX2) + 
                sumX2 * (0 * sumX3 - sumX2 * sumX2);

    if (det.abs() < 1e-10) {
      setState(() {
        _errorMessage = 'Singular matrix: cannot fit quadratic';
      });
      return;
    }

    final cPrime = (sumY * (sumX2 * sumX4 - sumX3 * sumX3) -
                    sumXY * (0 * sumX4 - sumX3 * sumX2) +
                    sumX2Y * (0 * sumX3 - sumX2 * sumX2)) / det;

    final b = (n * (sumXY * sumX4 - sumX2Y * sumX3) -
               sumY * (0 * sumX4 - sumX3 * sumX2) +
               sumX2Y * (0 * sumX3 - sumX2 * sumX2)) / det;

    final a = (n * (sumX2 * sumX2Y - sumX3 * sumXY) -
               0 * (0 * sumX2Y - sumX3 * sumXY) +
               sumX2 * (0 * sumXY - sumX2 * sumXY)) / det;

    final cFinal = cPrime + meanE - b * meanP - a * meanP * meanP;
    double optimalP = -b / (2 * a);

    if (optimalP < 0 || optimalP.isInfinite) {
      setState(() {
        _errorMessage = 'Invalid optimal pressure calculated';
      });
      return;
    }

    final avgY = dataPoints.fold(0.0, (sum, p) => sum + p.value) / n;
    final ssRes = dataPoints.fold(0.0, (sum, p) {
      final yPred = a * p.key * p.key + b * p.key + cFinal;
      return sum + (p.value - yPred) * (p.value - yPred);
    });
    final ssTot = dataPoints.fold(0.0, (sum, p) => sum + (p.value - avgY) * (p.value - avgY));
    final rSquared = ssTot > 0 ? 1.0 - (ssRes / ssTot) : 0.0;

    final maxPressure = dataPoints.map((p) => p.key).reduce((a, b) => a > b ? a : b);
    final efficiencyAtMax = a * maxPressure * maxPressure + b * maxPressure + cFinal;
    final efficiencyAtOptimal = a * optimalP * optimalP + b * optimalP + cFinal;
    final vibrationLoss = ((efficiencyAtOptimal - efficiencyAtMax) / efficiencyAtMax * 100).abs();

    // Validate data quality and set warnings
    String? warning = extraWarning;
    String confidence = 'HIGH';
    
    if (rSquared < 0.7) {
      confidence = 'LOW';
      final rWarn = '⚠ Low R² (${rSquared.toStringAsFixed(2)}): Data is noisy, results may be unreliable.';
      warning = warning == null ? rWarn : '$warning\n$rWarn';
    } else if (rSquared < 0.85) {
      confidence = 'MEDIUM';
    }
    
    if (powerCvPercent != null && powerCvPercent > _powerCvWarnThreshold) {
      confidence = confidence == 'HIGH' ? 'MEDIUM' : 'LOW';
      final powerWarning = '⚠ Power varied significantly between laps (${powerCvPercent.toStringAsFixed(1)}%). Results may be less reliable.';
      warning = warning == null ? powerWarning : '$warning\n$powerWarning';
    }

    setState(() {
      _coeffA = a;
      _coeffB = b;
      _coeffC = cFinal;
      _optimalRearPressure = optimalP;
      final silcaRatio = _silcaRatios[widget.bikeType] ?? 0.923;
      _optimalFrontPressure = optimalP * silcaRatio;
      _rSquared = rSquared.clamp(0, 1);
      _vibrationLossPercent = vibrationLoss;
      _confidenceLevel = confidence;
      _dataQualityWarning = warning;
    });
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
          'ANALYSIS RESULTS',
          style: TextStyle(color: Color(0xFF222222), fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16),
        ),
        centerTitle: true,
        foregroundColor: const Color(0xFF222222),
        actions: widget.isOverlay ? null : const [AppMenuButton()],
      ),
      body: _isLoading
          ? _buildLoadingScreen()
          : _errorMessage != null
              ? _buildErrorScreen()
              : _buildResultsScreen(),
    );
  }

  Widget _buildResultsScreen() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // PRESSURE-EFFICIENCY CURVE
          AppCard(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'EFFICIENCY CURVE',
                        style: TextStyle(color: accentGemini, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                      ),
                      Row(
                        children: [
                          if (_powerConsistencyPercent != null && widget.protocol != 'coast_down') ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: (_powerConsistencyPercent! <= 10.0 ? Colors.green : Colors.orange).withAlpha((0.08 * 255).round()),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _powerConsistencyPercent! <= 10.0 ? Icons.check_circle : Icons.warning_rounded,
                                    size: 12,
                                    color: _powerConsistencyPercent! <= 10.0 ? Colors.green : Colors.orange,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Power: ${_powerConsistencyPercent!.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      color: _powerConsistencyPercent! <= 10.0 ? Colors.green : Colors.orange,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: accentGemini.withAlpha((0.08 * 255).round()),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'R² = ${_rSquared.toStringAsFixed(3)}',
                              style: const TextStyle(color: accentGemini, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 240,
                    child: _buildPressureEfficiencyCurve(),
                  ),
                  const SizedBox(height: 8),
                  if (_dataQualityWarning != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withAlpha((0.05 * 255).round()),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withAlpha((0.3 * 255).round()), width: 1),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info, color: Colors.orange, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _dataQualityWarning!,
                              style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.w600, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_confidenceLevel.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: (_confidenceLevel == 'HIGH' ? Colors.green : _confidenceLevel == 'MEDIUM' ? Colors.orange : Colors.red).withAlpha((0.05 * 255).round()),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (_confidenceLevel == 'HIGH' ? Colors.green : _confidenceLevel == 'MEDIUM' ? Colors.orange : Colors.red).withAlpha((0.2 * 255).round()),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _confidenceLevel == 'HIGH' ? Icons.verified : _confidenceLevel == 'MEDIUM' ? Icons.check_circle : Icons.error,
                    color: _confidenceLevel == 'HIGH' ? Colors.green : _confidenceLevel == 'MEDIUM' ? Colors.orange : Colors.red,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$_confidenceLevel CONFIDENCE',
                    style: TextStyle(
                      color: _confidenceLevel == 'HIGH' ? Colors.green : _confidenceLevel == 'MEDIUM' ? Colors.orange : Colors.red,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // OPTIMAL PRESSURE RESULT
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text(
                    'RECOMMENDED SYSTEM PRESSURE',
                    style: TextStyle(color: Color(0xFF888888), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 24),
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        // FRONT PRESSURE
                        Expanded(
                          child: Column(
                            children: [
                              const Text('FRONT', style: TextStyle(color: Color(0xFFBBBBBB), fontSize: 10, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 8),
                              Text(
                                _formatPressureValueOnly(_optimalFrontPressure),
                                style: const TextStyle(color: Color(0xFF222222), fontSize: 38, fontWeight: FontWeight.w800, height: 1),
                              ),
                              Text(_pressureUnit.toUpperCase(), style: const TextStyle(color: Color(0xFF999999), fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        VerticalDivider(color: Colors.grey.withAlpha((0.2 * 255).round()), thickness: 1, indent: 5, endIndent: 5),
                        // REAR PRESSURE
                        Expanded(
                          child: Column(
                            children: [
                              const Text('REAR', style: TextStyle(color: Color(0xFFBBBBBB), fontSize: 10, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 8),
                              Text(
                                _formatPressureValueOnly(_optimalRearPressure),
                                style: const TextStyle(color: accentGemini, fontSize: 38, fontWeight: FontWeight.w800, height: 1),
                              ),
                              Text(_pressureUnit.toUpperCase(), style: const TextStyle(color: accentGemini, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_vibrationLossPercent != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.green.withAlpha((0.05 * 255).round()),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withAlpha((0.1 * 255).round()), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt, color: Colors.green, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_vibrationLossPercent!.toStringAsFixed(1)}% VIBRATION REDUCTION',
                                  style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.3),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'vs the highest pressure',
                                  style: TextStyle(color: Colors.green.withAlpha((0.7 * 255).round()), fontSize: 9, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ACTION BUTTONS
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  label: 'SAVE DATA',
                  icon: Icons.ios_share,
                  color: const Color(0xFF444444),
                  onPressed: _saveTest,
                  isFilled: false,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  label: 'NEW TEST',
                  icon: Icons.refresh_rounded,
                  color: accentGemini,
                  onPressed: _startNewTest,
                  isFilled: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool isFilled = false,
  }) {
    return SizedBox(
      height: 55,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isFilled ? color : Colors.white,
          foregroundColor: isFilled ? Colors.white : color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
            side: isFilled ? BorderSide.none : BorderSide(color: color.withAlpha((0.2 * 255).round()), width: 1.5),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.8),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveTest() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = DateTime.now().toIso8601String();
      final testKey = 'test_$timestamp';
      
      final testData = {
        'timestamp': timestamp,
        'protocol': widget.protocol,
        'bikeType': widget.bikeType,
        'optimalFrontPressure': _optimalFrontPressure ?? 0.0,
        'optimalRearPressure': _optimalRearPressure ?? 0.0,
        'pressureUnit': _pressureUnit,
        'rSquared': _rSquared,
        'vibrationLossPercent': _vibrationLossPercent ?? 0.0,
        'dataPointsCount': _regressionDataPoints.length,
        'fitFilePath': widget.fitFilePath,
      };
      
      await prefs.setString(testKey, jsonEncode(testData));
      final testsList = prefs.getStringList('test_keys') ?? [];
      testsList.add(testKey);
      await prefs.setStringList('test_keys', testsList);

      // Append to durable history file (JSONL)
      final file = await _historyFile();
      await file.create(recursive: true);
      await file.writeAsString('${jsonEncode(testData)}\n', mode: FileMode.append, flush: true);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Results saved to history'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF333333),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<File> _historyFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'test_history.jsonl'));
  }

  void _startNewTest() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 40, height: 40,
            child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(accentGemini), strokeWidth: 3),
          ),
          const SizedBox(height: 24),
          Text(
            _feedbackMessage.toUpperCase(),
            style: const TextStyle(color: Color(0xFF999999), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.0),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.redAccent, size: 48),
            const SizedBox(height: 24),
            const Text('ANALYSIS FAILED', style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Unknown error',
              style: const TextStyle(color: Color(0xFF777777), fontSize: 13, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatPressureValueOnly(double? psi) {
    if (psi == null) return '--';
    return _pressureUnit == 'Bar' ? _psiToBar(psi).toStringAsFixed(2) : psi.toStringAsFixed(1);
  }

  Widget _buildPressureEfficiencyCurve() {
    if (_regressionDataPoints.isEmpty || _coeffA == null || _coeffB == null || _coeffC == null) {
      return const Center(child: Text('Insufficient data', style: TextStyle(color: Colors.grey)));
    }

    final List<FlSpot> dataPoints = [];
    double minPressure = double.infinity;
    double maxPressure = 0;
    double maxEfficiency = 0;

    for (final point in _regressionDataPoints) {
      dataPoints.add(FlSpot(point.key, point.value));
      minPressure = minPressure > point.key ? point.key : minPressure;
      maxPressure = maxPressure < point.key ? point.key : maxPressure;
      maxEfficiency = maxEfficiency < point.value ? point.value : maxEfficiency;
    }

    final List<FlSpot> curvePoints = [];
    final double pressureRange = maxPressure - minPressure;
    final double step = pressureRange / 50.0;

    for (double p = minPressure; p <= maxPressure; p += step) {
      final efficiency = _coeffA! * p * p + _coeffB! * p + _coeffC!;
      curvePoints.add(FlSpot(p, efficiency));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withAlpha((0.1 * 255).round()), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: pressureRange > 0 ? pressureRange / 3 : 1,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(value.toStringAsFixed(1), style: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text(value.toStringAsFixed(2), style: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minX: minPressure - (pressureRange * 0.1),
        maxX: maxPressure + (pressureRange * 0.1),
        minY: 0,
        maxY: maxEfficiency * 1.2,
        lineBarsData: [
          LineChartBarData(
            spots: curvePoints,
            isCurved: true,
            color: accentGemini,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [accentGemini.withAlpha((0.2 * 255).round()), accentGemini.withAlpha((0.0 * 255).round())],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          LineChartBarData(
            spots: dataPoints,
            color: Colors.transparent,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                radius: 4,
                color: Colors.white,
                strokeWidth: 3,
                strokeColor: accentGemini,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
