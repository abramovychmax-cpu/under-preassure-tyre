import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

/// Represents one complete circle lap at a specific tire pressure
class CircleLapData {
  final int lapIndex;           // Which lap (pressure level) this is
  final double pressure;        // Tire pressure (PSI) for this lap
  final double avgPower;        // Average power across lap (watts)
  final double avgSpeed;        // Average speed across lap (km/h)
  final double vibrationRms;    // RMS vibration across lap
  final double efficiency;      // avg_speed / avg_power (km/h per watt)
  final double rrResidual;      // Aero-corrected rolling resistance: mean((P − P_aero) / v)
                                // Units: kg·m/s² (= CRR × mass × g); comparable across power levels
  final double duration;        // Duration of lap (seconds)
  final double distance;        // Total distance (km)
  final int numRecords;         // Number of data points in lap
  final DateTime startTime;
  final DateTime endTime;
  
  // Data quality metrics
  final double powerCv;         // Coefficient of variation of power
  final double speedCv;         // Coefficient of variation of speed
  final double minPower;        // Minimum power during lap
  final double maxPower;        // Maximum power during lap
  final double dataQuality;     // 0.0-1.0 score (1.0 = perfect)

  CircleLapData({
    required this.lapIndex,
    required this.pressure,
    required this.avgPower,
    required this.avgSpeed,
    required this.vibrationRms,
    required this.efficiency,
    required this.rrResidual,
    required this.duration,
    required this.distance,
    required this.numRecords,
    required this.startTime,
    required this.endTime,
    required this.powerCv,
    required this.speedCv,
    required this.minPower,
    required this.maxPower,
    required this.dataQuality,
  });

  /// Check if this lap is complete and valid for regression
  bool isValid({
    double minRecords = 30,       // At least 30 data points
    double maxPowerCv = 0.25,     // Power variation < 25%
    double minAvgPower = 50.0,    // At least 50W average
  }) {
    return numRecords >= minRecords &&
        avgPower >= minAvgPower &&
        powerCv <= maxPowerCv;
  }

  /// Check if this lap matches another by duration (same route)
  bool matchesDuration(CircleLapData other, {
    double tolerancePercent = 10.0,
  }) {
    final durDiff = (duration - other.duration).abs();
    final durPercent = (durDiff / math.max(duration, other.duration)) * 100.0;
    return durPercent <= tolerancePercent;
  }
}

/// Service for analyzing circle protocol data
class CircleProtocolService {
  /// Load JSONL and analyze each lap as a complete circle
  /// Filters out invalid laps (incomplete, erratic power, etc.)
  static Future<List<CircleLapData>> analyzeLapsFromJsonl(
    String jsonlPath, {
    double cda = 0.320,
    double rho = 1.204,
  }) async {
    final jsonlFile = File(jsonlPath);
    if (!jsonlFile.existsSync()) {
      throw Exception('JSONL file not found: $jsonlPath');
    }

    final jsonlLines = await jsonlFile.readAsLines();
    
    // Group records by lap
    final Map<int, List<Map<String, dynamic>>> recordsByLap = {};
    final Map<int, Map<String, dynamic>> lapMetadata = {};

    for (final line in jsonlLines) {
      if (line.trim().isEmpty) continue;
      try {
        final json = jsonDecode(line) as Map<String, dynamic>;
        final lapIdx = json['lapIndex'] as int?;
        
        if (lapIdx == null) continue;
        
        // Lap metadata (pressure, vibration) has these fields
        if (json.containsKey('frontPressure')) {
          lapMetadata[lapIdx] = json;
        }
        
        // Sensor records (timestamp, power, speed, cadence, vibration) have these fields
        if (json.containsKey('timestamp') || json.containsKey('power')) {
          recordsByLap.putIfAbsent(lapIdx, () => []).add(json);
        }
      } catch (e) {
        print('ERROR: Failed to parse JSONL line: $e');
      }
    }

    // Analyze each lap
    final allLaps = <CircleLapData>[];
    for (int lapIdx = 0; lapIdx < recordsByLap.length; lapIdx++) {
      final lapRecords = recordsByLap[lapIdx] ?? [];
      final metadata = lapMetadata[lapIdx] ?? {};
      
      if (lapRecords.isEmpty) continue;
      
      // Use REAR pressure for regression X-axis; front derived via Silca ratio
      final pressure = (metadata['rearPressure'] as num?)?.toDouble() ?? 0.0;
      final lapData = _analyzeLap(lapRecords, lapIdx, pressure, cda, rho);
      
      if (lapData != null) {
        allLaps.add(lapData);
      }
    }

    // ── Validate laps: filter out low-quality ones ──
    print('📊 Analyzing ${allLaps.length} laps:');
    final validLaps = <CircleLapData>[];
    for (final lap in allLaps) {
      if (lap.isValid()) {
        validLaps.add(lap);
      } else {
        print('  ✗ Lap ${lap.lapIndex} @ ${lap.pressure.toStringAsFixed(1)}: '
            'REJECTED (power_cv=${lap.powerCv.toStringAsFixed(2)}, '
            'quality=${lap.dataQuality.toStringAsFixed(2)})');
      }
    }

    if (validLaps.isEmpty) {
      throw Exception('No valid laps found. Ensure enough complete laps with stable power output.');
    }

    // ── Duration matching: verify all valid laps took ~same time ──
    print('🔄 Checking duration consistency across ${validLaps.length} laps:');
    final baseDuration = validLaps.first.duration;
    for (final lap in validLaps) {
      if (!lap.matchesDuration(validLaps.first, tolerancePercent: 10.0)) {
        print('  ⚠ Lap ${lap.lapIndex}: duration ${lap.duration.toStringAsFixed(0)}s '
            'vs baseline ${baseDuration.toStringAsFixed(0)}s (mismatch > 10%)');
      } else {
        print('  ✓ Lap ${lap.lapIndex}: ${lap.duration.toStringAsFixed(0)}s (consistent)');
      }
    }

    // ── Cross-lap power spread check ─────────────────────────────────────────
    // Aero drag ∝ v³ so different power levels produce different speeds.
    // The RR residual formula corrects for this, but a large spread hints at
    // inconsistent pacing — warn the user but do not reject the data.
    if (validLaps.length >= 2) {
      final lapPowers = validLaps.map((l) => l.avgPower).toList();
      final maxP = lapPowers.reduce(math.max);
      final minP = lapPowers.reduce(math.min);
      final spread = maxP > 0 ? (maxP - minP) / maxP : 0.0;
      if (spread > 0.10) {
        print('⚠ Cross-lap power spread ${(spread * 100).toStringAsFixed(1)}% '
            '(${minP.toStringAsFixed(0)}–${maxP.toStringAsFixed(0)} W). '
            'Aero correction applied (CdA=$cda, ρ=${rho.toStringAsFixed(3)}). '
            'Best results when power is consistent across laps.');
      } else {
        print('✓ Cross-lap power spread ${(spread * 100).toStringAsFixed(1)}% — within 10% tolerance');
      }
    }

    return validLaps;
  }

  /// Analyze a single lap: calculate avg power, speed, vibration, efficiency + quality metrics
  static CircleLapData? _analyzeLap(
    List<Map<String, dynamic>> records,
    int lapIdx,
    double pressure,
    double cda,
    double rho,
  ) {
    if (records.isEmpty) return null;

    final powers = <double>[];
    final speeds = <double>[];
    final vibrations = <double>[];
    final rrSamples = <double>[]; // aero-corrected RR residual samples
    DateTime? startTime, endTime;
    double totalDistance = 0;

    for (final record in records) {
      final power = (record['power'] as num?)?.toDouble() ?? 0.0;
      final speed = (record['speed'] as num?)?.toDouble() ?? 0.0;
      final vibration = (record['vibrationRms'] as num?)?.toDouble() ?? 0.0;
      final timestamp = record['timestamp'] as String?;

      powers.add(power);
      speeds.add(speed);
      vibrations.add(vibration);

      // Aero-corrected RR residual: (P − 0.5·CdA·ρ·v³) / v  (speed in m/s)
      if (speed > 0.5) {
        final pAero = 0.5 * cda * rho * speed * speed * speed;
        rrSamples.add((power - pAero) / speed);
      }

      // Accumulate distance: speed (m/s) * 1 second
      totalDistance += speed;

      if (timestamp != null) {
        final dt = DateTime.tryParse(timestamp);
        if (dt != null) {
          startTime ??= dt;
          endTime = dt;
        }
      }
    }

    // Aero-corrected rolling resistance residual
    final avgRr = rrSamples.isEmpty ? 0.0
        : rrSamples.fold<double>(0.0, (a, b) => a + b) / rrSamples.length;

    // Calculate averages
    final avgPower = powers.fold<double>(0, (a, b) => a + b) / powers.length;
    final avgSpeed = speeds.fold<double>(0, (a, b) => a + b) / speeds.length;
    
    // Calculate vibration RMS as root mean square of all vibration values
    final vibrationSquares = vibrations.fold<double>(0, (sum, v) => sum + v * v);
    final vibrationRms = math.sqrt(vibrationSquares / vibrations.length);
    
    // ── Data Quality Metrics ──
    
    // Power CV: stability of power throughout lap
    final minPower = powers.reduce((a, b) => a < b ? a : b);
    final maxPower = powers.reduce((a, b) => a > b ? a : b);
    final powerVariance = powers.fold<double>(0, (sum, p) => sum + (p - avgPower) * (p - avgPower)) / powers.length;
    final powerCv = avgPower > 0 ? math.sqrt(powerVariance) / avgPower : 1.0;
    
    // Speed CV: stability of speed throughout lap
    final speedVariance = speeds.fold<double>(0, (sum, s) => sum + (s - avgSpeed) * (s - avgSpeed)) / speeds.length;
    final speedCv = avgSpeed > 0 ? math.sqrt(speedVariance) / avgSpeed : 1.0;
    
    // Overall data quality: combines completeness, power stability, speed stability
    // Quality = 1.0 × (1 / (1 + powerCv)) × (1 / (1 + speedCv))
    // Max 1.0 when both CV ~0, degrades as variation increases
    final powerFactor = 1.0 / (1.0 + powerCv * 2.0);     // Power stability weighted at 2x
    final speedFactor = 1.0 / (1.0 + speedCv);
    final dataQuality = (records.length.toDouble() / 60.0).clamp(0.5, 1.0) * powerFactor * speedFactor;

    // Efficiency: avg_speed / avg_power (km/h per watt)
    final efficiency = avgPower > 0 ? avgSpeed / avgPower : 0.0;

    // Duration and distance
    final duration = records.length.toDouble(); // Approximate in seconds
    final distance = totalDistance / 1000; // Convert to km

    final lap = CircleLapData(
      lapIndex: lapIdx,
      pressure: pressure,
      avgPower: avgPower,
      avgSpeed: avgSpeed,
      vibrationRms: vibrationRms,
      efficiency: efficiency,
      rrResidual: avgRr,
      duration: duration,
      distance: distance,
      numRecords: records.length,
      startTime: startTime ?? DateTime.now(),
      endTime: endTime ?? DateTime.now(),
      powerCv: powerCv,
      speedCv: speedCv,
      minPower: minPower,
      maxPower: maxPower,
      dataQuality: dataQuality,
    );

    // Log lap quality
    print('🔄 Lap $lapIdx @ ${pressure.toStringAsFixed(1)} PSI: '
        'power_cv=${powerCv.toStringAsFixed(2)} '
        'speed_cv=${speedCv.toStringAsFixed(2)} '
        'quality=${dataQuality.toStringAsFixed(2)} '
        '${lap.isValid() ? "✓ VALID" : "✗ REJECTED"}');

    return lap;
  }

  /// Build regression data points: (pressure, efficiency) pairs
  /// Only includes valid laps with good data quality
  static List<MapEntry<double, double>> buildRegressionPoints(
    List<CircleLapData> laps,
  ) {
    final points = <MapEntry<double, double>>[];

    print('📊 Building regression dataset from ${laps.length} laps:');
    for (final lap in laps) {
      if (lap.isValid()) {
        points.add(MapEntry(lap.pressure, lap.rrResidual));
        print('  ✓ Lap ${lap.lapIndex} @ ${lap.pressure.toStringAsFixed(1)} PSI: '
            'rrResidual=${lap.rrResidual.toStringAsFixed(2)} '
            'efficiency=${lap.efficiency.toStringAsFixed(4)} '
            '(quality=${lap.dataQuality.toStringAsFixed(2)})');
      } else {
        print('  ✗ Lap ${lap.lapIndex}: SKIPPED (quality=${lap.dataQuality.toStringAsFixed(2)})');
      }
    }

    print('📈 Total regression points: ${points.length}');
    return points;
  }

  /// Get vibration profile: which pressure has lowest vibration
  static Map<double, double> getVibrationProfile(
    List<CircleLapData> laps,
  ) {
    final profile = <double, double>{};

    for (final lap in laps) {
      profile[lap.pressure] = lap.vibrationRms;
    }

    return profile;
  }

  /// Provide analysis summary for UI display
  static Map<String, dynamic> getAnalysisSummary(
    List<CircleLapData> laps,
  ) {
    if (laps.isEmpty) {
      return {
        'totalLaps': 0,
        'regressionDataPoints': 0,
        'dataQuality': 'NO DATA',
      };
    }

    // Count valid laps
    final validLaps = laps.where((l) => l.isValid()).toList();
    final pressures = laps.map((l) => l.pressure).toSet().length;
    final minVibration = laps.map((l) => l.vibrationRms).reduce((a, b) => a < b ? a : b);
    final maxVibration = laps.map((l) => l.vibrationRms).reduce((a, b) => a > b ? a : b);
    final avgQuality = laps.isNotEmpty 
        ? laps.map((l) => l.dataQuality).reduce((a, b) => a + b) / laps.length
        : 0.0;

    return {
      'totalLaps': laps.length,
      'validLaps': validLaps.length,
      'invalidLaps': laps.length - validLaps.length,
      'uniquePressures': pressures,
      'regressionDataPoints': validLaps.length,
      'minVibration': minVibration,
      'maxVibration': maxVibration,
      'vibrationRange': maxVibration - minVibration,
      'avgDataQuality': avgQuality,
      'dataQuality': validLaps.length >= 3 ? 'GOOD (≥3 valid laps)' : 'POOR (<3 valid laps)',
    };
  }
}
