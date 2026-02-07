import 'dart:math';

/// Result of tire pressure optimization analysis
class OptimizationResult {
  final double a; // Quadratic coefficient
  final double b; // Linear coefficient
  final double c; // Constant
  final double optimalPressure; // P_optimal = -b/(2a)
  final double maxAcceleration; // Acceleration at optimal pressure
  final double rSquared; // R² goodness of fit
  final List<AccelerationDataPoint> dataPoints;
  final String status; // "success", "insufficient_data", "invalid_curve", etc.
  final String? errorMessage;

  OptimizationResult({
    required this.a,
    required this.b,
    required this.c,
    required this.optimalPressure,
    required this.maxAcceleration,
    required this.rSquared,
    required this.dataPoints,
    this.status = "success",
    this.errorMessage,
  });

  /// Evaluate the fitted curve at a given pressure
  double evaluateAt(double pressure) {
    return a * pressure * pressure + b * pressure + c;
  }

  @override
  String toString() => '''
OptimizationResult(
  P_optimal: ${optimalPressure.toStringAsFixed(2)} bar,
  max_accel: ${maxAcceleration.toStringAsFixed(4)} km/h/s,
  curve: ${a.toStringAsFixed(6)}·P² + ${b.toStringAsFixed(6)}·P + ${c.toStringAsFixed(6)},
  R²: ${rSquared.toStringAsFixed(4)},
  status: $status
)
''';
}

/// Single acceleration measurement
class AccelerationDataPoint {
  final int lapIndex;
  final double pressure; // Bar
  final double acceleration; // km/h/s
  final double vPeak; // km/h
  final int numRecords; // Records in acceleration phase
  final bool isValid;

  AccelerationDataPoint({
    required this.lapIndex,
    required this.pressure,
    required this.acceleration,
    required this.vPeak,
    required this.numRecords,
    this.isValid = true,
  });

  @override
  String toString() =>
      'Lap $lapIndex: P=${pressure.toStringAsFixed(1)} bar, '
      'a=${acceleration.toStringAsFixed(4)} km/h/s, '
      'v_peak=${vPeak.toStringAsFixed(2)} km/h';
}

/// Tire pressure optimization service
/// Uses acceleration phase analysis to find optimal tire pressure
class TireOptimizationService {
  static const double accelThresholdFraction = 0.95;
  static const double minCadenceForCoasting = 0.5; // RPM
  static const double minSpeedForValidation = 2.0; // km/h
  static const int minRecordsForAccelPhase = 5;
  static const int minDataPointsForRegression = 3;

  /// Extract acceleration phase from sensor records
  /// Returns records where cadence ≈ 0 and speed ≤ threshold
  static List<Map<String, dynamic>> extractAccelerationPhase(
    List<Map<String, dynamic>> sensorRecords,
    double speedThreshold,
  ) {
    return sensorRecords
        .where((r) {
          final cadence = (r['cadence'] as num?)?.toDouble() ?? 0.0;
          final speed = (r['speed_kmh'] as num?)?.toDouble() ?? 0.0;
          return cadence <= minCadenceForCoasting && speed <= speedThreshold;
        })
        .toList();
  }

  /// Calculate acceleration from records in acceleration phase
  /// Assumes 1 Hz sampling (1 record = 1 second)
  static double calculateAcceleration(
    List<Map<String, dynamic>> accelRecords,
  ) {
    if (accelRecords.isEmpty) return 0.0;

    final speeds = <double>[];
    for (final r in accelRecords) {
      final speed = (r['speed_kmh'] as num?)?.toDouble() ?? 0.0;
      speeds.add(speed);
    }

    if (speeds.isEmpty) return 0.0;

    final speedStart = speeds.first;
    final speedEnd = speeds.last;
    final duration = accelRecords.length / 1.0; // 1 Hz

    return (speedEnd - speedStart) / duration;
  }

  /// Find minimum v_peak across all data points
  static double findMinVPeak(List<AccelerationDataPoint> dataPoints) {
    if (dataPoints.isEmpty) return 0.0;
    return dataPoints.map((p) => p.vPeak).reduce(min);
  }

  /// Fit quadratic regression: a·P² + b·P + c
  /// Uses centered coordinates for numerical stability
  static OptimizationResult fitQuadraticRegression(
    List<AccelerationDataPoint> dataPoints,
  ) {
    // Validate input
    if (dataPoints.isEmpty) {
      return OptimizationResult(
        a: 0,
        b: 0,
        c: 0,
        optimalPressure: 0,
        maxAcceleration: 0,
        rSquared: 0,
        dataPoints: [],
        status: "no_data",
        errorMessage: "No data points provided",
      );
    }

    if (dataPoints.length < minDataPointsForRegression) {
      return OptimizationResult(
        a: 0,
        b: 0,
        c: 0,
        optimalPressure: 0,
        maxAcceleration: 0,
        rSquared: 0,
        dataPoints: dataPoints,
        status: "insufficient_data",
        errorMessage:
            "Need at least $minDataPointsForRegression data points, got ${dataPoints.length}",
      );
    }

    // Extract valid data points only
    final validPoints =
        dataPoints.where((p) => p.isValid).toList();

    if (validPoints.length < minDataPointsForRegression) {
      return OptimizationResult(
        a: 0,
        b: 0,
        c: 0,
        optimalPressure: 0,
        maxAcceleration: 0,
        rSquared: 0,
        dataPoints: dataPoints,
        status: "insufficient_valid_data",
        errorMessage:
            "Need at least $minDataPointsForRegression valid points, got ${validPoints.length}",
      );
    }

    // Extract pressures and accelerations
    final pressures = validPoints.map((p) => p.pressure).toList();
    final accelerations = validPoints.map((p) => p.acceleration).toList();

    // Center pressure data for numerical stability
    final pMean = pressures.reduce((a, b) => a + b) / pressures.length;
    final pCentered = pressures.map((p) => p - pMean).toList();

    // Compute sums for least squares
    final n = pCentered.length;
    double sumP2 = 0, sumP3 = 0, sumP4 = 0, sumPA = 0, sumP2A = 0, sumA = 0;

    for (int i = 0; i < n; i++) {
      final pc = pCentered[i];
      final a = accelerations[i];

      sumP2 += pc * pc;
      sumP3 += pc * pc * pc;
      sumP4 += pc * pc * pc * pc;
      sumPA += pc * a;
      sumP2A += pc * pc * a;
      sumA += a;
    }

    // Solve normal equations using Cramer's rule (3x3 system)
    // Matrix for centered data (sumP = 0):
    // | sumP4  sumP3  sumP2 | | a |   | sumP2A |
    // | sumP3  sumP2  0     | | b | = | sumPA  |
    // | sumP2  0      n     | | c |   | sumA   |
    
    // Determinant of coefficient matrix
    final det = n * (sumP4 * sumP2 - sumP3 * sumP3);

    if (det.abs() < 1e-10) {
      return OptimizationResult(
        a: 0,
        b: 0,
        c: 0,
        optimalPressure: 0,
        maxAcceleration: 0,
        rSquared: 0,
        dataPoints: validPoints,
        status: "singular_matrix",
        errorMessage: "Cannot solve regression (singular matrix)",
      );
    }

    // Determinants for Cramer's rule
    final detA = n * (sumP2A * sumP2 - sumPA * sumP3);
    final detB = n * (sumP4 * sumPA - sumP3 * sumP2A);
    final detC = sumA * (sumP4 * sumP2 - sumP3 * sumP3) +
                 sumP2 * (sumP3 * sumPA - sumP2 * sumP2A);

    final a = detA / det;
    final b = detB / det;
    final c = detC / det;

    // Find optimal pressure (vertex of parabola)
    double optimalPressure = 0;
    double maxAcceleration = 0;

    if (a.abs() > 1e-10) {
      final pOptCentered = -b / (2 * a);
      optimalPressure = pOptCentered + pMean;
      maxAcceleration = a * pOptCentered * pOptCentered +
          b * pOptCentered +
          c;
    } else {
      // Linear fit (a ≈ 0)
      return OptimizationResult(
        a: a,
        b: b,
        c: c,
        optimalPressure: 0,
        maxAcceleration: 0,
        rSquared: 0,
        dataPoints: validPoints,
        status: "linear_fit",
        errorMessage: "Data fits linear model, not parabolic (a ≈ 0)",
      );
    }

    // Calculate R² (coefficient of determination)
    final meanA = sumA / n;
    double ssTot = 0, ssRes = 0;

    for (int i = 0; i < n; i++) {
      final pc = pCentered[i];
      final measured = accelerations[i];
      final fitted = a * pc * pc + b * pc + c;
      final error = measured - fitted;

      ssTot += (measured - meanA) * (measured - meanA);
      ssRes += error * error;
    }

    final rSquared =
        ssTot > 1e-10 ? 1 - (ssRes / ssTot) : 0.0;

    return OptimizationResult(
      a: a,
      b: b,
      c: c,
      optimalPressure: optimalPressure,
      maxAcceleration: maxAcceleration,
      rSquared: rSquared,
      dataPoints: validPoints,
      status: "success",
    );
  }

  /// Complete analysis pipeline:
  /// 1. Extract acceleration phase for all laps
  /// 2. Calculate acceleration for each
  /// 3. Fit quadratic regression
  /// 4. Return optimal pressure
  static OptimizationResult analyzeSession(
    Map<int, List<Map<String, dynamic>>> lapSensorRecords,
    Map<int, double> lapPressures, // lapIndex -> pressure (bar)
  ) {
    // Step 1: Extract v_peak for each lap and find minimum
    final vPeaks = <int, double>{};
    for (final lapIdx in lapSensorRecords.keys) {
      final records = lapSensorRecords[lapIdx]!;
      if (records.isEmpty) continue;

      final speeds = <double>[];
      for (final record in records) {
        final speed = (record['speed_kmh'] as num?)?.toDouble() ?? 0.0;
        speeds.add(speed);
      }
      final vPeak = speeds.isEmpty ? 0.0 : speeds.reduce(max);
      vPeaks[lapIdx] = vPeak;
    }

    if (vPeaks.isEmpty) {
      return OptimizationResult(
        a: 0,
        b: 0,
        c: 0,
        optimalPressure: 0,
        maxAcceleration: 0,
        rSquared: 0,
        dataPoints: [],
        status: "no_valid_laps",
        errorMessage: "No valid laps with speed data",
      );
    }

    final minVPeak = vPeaks.values.reduce(min);
    final speedThreshold = accelThresholdFraction * minVPeak;

    // Step 2: Extract acceleration phase and calculate acceleration for each lap
    final dataPoints = <AccelerationDataPoint>[];

    for (final lapIdx in lapSensorRecords.keys) {
      final pressure = lapPressures[lapIdx];
      if (pressure == null) continue;

      final records = lapSensorRecords[lapIdx]!;
      final accelRecords = extractAccelerationPhase(records, speedThreshold);

      if (accelRecords.length < minRecordsForAccelPhase) {
        dataPoints.add(
          AccelerationDataPoint(
            lapIndex: lapIdx,
            pressure: pressure,
            acceleration: 0,
            vPeak: vPeaks[lapIdx] ?? 0,
            numRecords: accelRecords.length,
            isValid: false,
          ),
        );
        continue;
      }

      final acceleration = calculateAcceleration(accelRecords);

      dataPoints.add(
        AccelerationDataPoint(
          lapIndex: lapIdx,
          pressure: pressure,
          acceleration: acceleration,
          vPeak: vPeaks[lapIdx] ?? 0,
          numRecords: accelRecords.length,
          isValid: true,
        ),
      );
    }

    // Step 3: Fit quadratic regression
    return fitQuadraticRegression(dataPoints);
  }
}
