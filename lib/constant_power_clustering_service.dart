import 'dart:math' as math;
import 'dart:convert';
import 'dart:io';

/// Represents a single constant-power segment within a lap
class ConstantPowerSegment {
  final int segmentIndex;        // Segment ID within lap
  final int lapIndex;            // Which lap (pressure level) this segment belongs to
  final double pressure;         // Tire pressure (PSI) for this lap
  final double avgLat;           // Mean GPS latitude of segment
  final double avgLon;           // Mean GPS longitude of segment
  final double avgPower;         // Average power (watts)
  final double cvPower;          // Coefficient of variation of power
  final double avgSpeed;         // Average speed (km/h)
  final double distance;         // Distance traveled (meters)
  final double duration;         // Duration (seconds)
  final double efficiency;       // speed / power (km/h per watt)
  final int numRecords;          // Number of data points
  final DateTime startTime;
  final DateTime endTime;

  ConstantPowerSegment({
    required this.segmentIndex,
    required this.lapIndex,
    required this.pressure,
    required this.avgLat,
    required this.avgLon,
    required this.avgPower,
    required this.cvPower,
    required this.avgSpeed,
    required this.distance,
    required this.duration,
    required this.efficiency,
    required this.numRecords,
    required this.startTime,
    required this.endTime,
  });

  /// Check if this segment matches another by GPS proximity, power, and duration
  /// Tolerances: GPS ±50m (realistic), Power ±10%, Duration ±15%
  bool matchesWith(ConstantPowerSegment other, {
    double gpsToleranceM = 50.0,      // Relaxed from 10m (GPS noise tolerance)
    double powerTolerancePercent = 10.0,
    double durationTolerancePercent = 15.0,
  }) {
    // GPS check: within ±50m (realistic GPS variance)
    final gpsDist = _haversineDistance(avgLat, avgLon, other.avgLat, other.avgLon);
    if (gpsDist > gpsToleranceM) return false;

    // Power check: within ±10%
    final powerDiff = (avgPower - other.avgPower).abs();
    final maxPower = math.max(avgPower, other.avgPower);
    final powerPercent = (powerDiff / maxPower) * 100.0;
    if (powerPercent > powerTolerancePercent) return false;

    // Duration check: within ±15% (rider consistency)
    final durDiff = (duration - other.duration).abs();
    final durPercent = (durDiff / math.max(duration, other.duration)) * 100.0;
    if (durPercent > durationTolerancePercent) return false;

    return true;
  }

  /// Calculate matching score for preferred segment selection
  /// Higher score = better match. Prefers: index match, GPS proximity, duration match
  double matchScore(ConstantPowerSegment other) {
    final gpsDist = _haversineDistance(avgLat, avgLon, other.avgLat, other.avgLon);
    final powerDiff = (avgPower - other.avgPower).abs() / math.max(avgPower, 1.0);
    final durDiff = (duration - other.duration).abs() / math.max(duration, 1.0);
    
    // Score: lower distances/diffs are better (negative to maximize)
    // Index match is handled separately in matchSegmentsAcrossLaps
    return -(gpsDist / 50.0 + powerDiff * 100.0 + durDiff * 100.0);
  }

  /// Haversine distance in meters
  static double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371.0; // Earth radius in km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.asin(math.sqrt(a));
    return R * c * 1000; // Convert to meters
  }

  static double _toRadians(double degrees) {
    return degrees * math.pi / 180.0;
  }
}

/// Matched segment across multiple laps with validation
class MatchedSegment {
  final int segmentId;  // Logical segment number (0, 1, 2, ...)
  final Map<int, ConstantPowerSegment> segmentsByLap;  // lapIndex -> segment
  final List<double> pressures;
  final List<double> efficiencies;
  bool isIncomplete = false;  // True if missing from any lap

  MatchedSegment({
    required this.segmentId,
    required this.segmentsByLap,
    required this.pressures,
    required this.efficiencies,
  });
}

class ConstantPowerClusteringService {
  /// Detect constant-power segments from FIT+JSONL data
  /// Returns List<List<ConstantPowerSegment>> where outer list is laps, inner list is segments
  /// Note: fit_tool SDK v1.0.5 doesn't support FIT decoding. All data comes from JSONL.
  static Future<List<List<ConstantPowerSegment>>> detectSegmentsFromFitAndJsonl(
    List<int> fitBytes,
    String jsonlPath,
  ) async {
    final allSegments = <List<ConstantPowerSegment>>[];

    // Parse JSONL for sensor data and pressure metadata
    final jsonlFile = File(jsonlPath);
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
        
        // Sensor records (timestamp, power, speed, cadence) have these fields
        if (json.containsKey('timestamp') || json.containsKey('power')) {
          recordsByLap.putIfAbsent(lapIdx, () => []).add(json);
        }
      } catch (e) {
        print('ERROR: Failed to parse JSONL line: $e');
      }
    }

    // Process each lap
    for (int lapIdx = 0; lapIdx < recordsByLap.length; lapIdx++) {
      final lapRecords = recordsByLap[lapIdx] ?? [];
      final metadata = lapMetadata[lapIdx] ?? {};
      
      // Use REAR pressure for regression X-axis; front derived via Silca ratio
      final pressure = (metadata['rearPressure'] as num?)?.toDouble() ?? 0.0;

      // Detect constant-power segments from JSONL records
      final segments = _detectConstantPowerSegmentsFromJsonl(
        lapRecords,
        lapIdx,
        pressure,
      );

      allSegments.add(segments);
    }

    return allSegments;
  }


  /// Detect constant-power segments within a lap from JSONL records (CV < 10%)
  static List<ConstantPowerSegment> _detectConstantPowerSegmentsFromJsonl(
    List<Map<String, dynamic>> records,
    int lapIdx,
    double pressure,
  ) {
    if (records.isEmpty) return [];

    final segments = <ConstantPowerSegment>[];
    final segmentThreshold = 0.10; // 10% CV threshold for constant power

    int i = 0;
    int segmentId = 0;

    while (i < records.length) {
      // Find a window of constant power
      final windowSize = 10; // ~10 records at 1 Hz
      if (i + windowSize > records.length) break;

      final window = records.sublist(i, i + windowSize);
      final powers = <double>[];
      final speeds = <double>[];
      final lats = <double>[];
      final lons = <double>[];
      DateTime? startTime, endTime;

      for (final record in window) {
        final power = (record['power'] as num?)?.toDouble() ?? 0.0;
        final speed = (record['speed'] as num?)?.toDouble() ?? 0.0;
        final lat = (record['gpsLatitude'] as num?)?.toDouble() ?? 0.0;
        final lon = (record['gpsLongitude'] as num?)?.toDouble() ?? 0.0;
        final timestamp = record['timestamp'] as String?;

        powers.add(power);
        speeds.add(speed);
        lats.add(lat);
        lons.add(lon);

        if (timestamp != null) {
          final dt = DateTime.tryParse(timestamp);
          if (dt != null) {
            startTime ??= dt;
            endTime = dt;
          }
        }
      }

      // Calculate CV of power
      final avgPower = powers.fold<double>(0, (a, b) => a + b) / powers.length;
      if (avgPower > 0) {
        final variance = powers.fold<double>(0, (sum, p) => sum + math.pow(p - avgPower, 2)) /
            powers.length;
        final stdDev = math.sqrt(variance);
        final cv = stdDev / avgPower;

        // If CV < 10%, this is a constant-power segment
        if (cv < segmentThreshold && avgPower > 0) {
          final avgSpeed = speeds.fold<double>(0, (a, b) => a + b) / speeds.length;
          final avgLat = lats.fold<double>(0, (a, b) => a + b) / lats.length;
          final avgLon = lons.fold<double>(0, (a, b) => a + b) / lons.length;
          final duration = window.length.toDouble(); // Approximate in seconds
          final distance = avgSpeed * duration; // meters

          final efficiency = avgPower > 0 ? avgSpeed / avgPower : 0.0;

          segments.add(ConstantPowerSegment(
            segmentIndex: segmentId,
            lapIndex: lapIdx,
            pressure: pressure,
            avgLat: avgLat,
            avgLon: avgLon,
            avgPower: avgPower,
            cvPower: cv,
            avgSpeed: avgSpeed,
            distance: distance,
            duration: duration,
            efficiency: efficiency,
            numRecords: window.length,
            startTime: startTime ?? DateTime.now(),
            endTime: endTime ?? DateTime.now(),
          ));

          segmentId++;
          i += windowSize; // Move past this segment
        } else {
          i += 1; // Move by 1 if not constant-power
        }
      } else {
        i += 1;
      }
    }

    return segments;
  }

  /// Match segments across all laps with improved strategy:
  /// 1. Prefer segments at same index + within GPS ±50m / Power ±10% / Duration ±15%
  /// 2. Score optimally by GPS proximity + power/duration consistency
  /// 3. Only include if found in ALL laps (complete match)
  static List<MatchedSegment> matchSegmentsAcrossLaps(
    List<List<ConstantPowerSegment>> allLaps,
  ) {
    if (allLaps.isEmpty) return [];

    final matchedSegments = <MatchedSegment>[];
    final numLaps = allLaps.length;

    // Use first lap as reference for segment discovery
    final referenceSegments = allLaps.first;

    for (int refSegIdx = 0; refSegIdx < referenceSegments.length; refSegIdx++) {
      final refSeg = referenceSegments[refSegIdx];
      final matchedMap = <int, ConstantPowerSegment>{};
      final pressures = <double>[];
      final efficiencies = <double>[];
      final durationVariations = <double>[];
      final powerVariations = <double>[];

      bool isComplete = true;

      // Try to find matching segment in each lap
      for (int lapIdx = 0; lapIdx < numLaps; lapIdx++) {
        final lapSegments = allLaps[lapIdx];

        ConstantPowerSegment? bestMatch;
        double bestScore = double.negativeInfinity;

        // Strategy 1: Prefer segments at same index (stable numbering)
        for (final seg in lapSegments) {
          if (seg.segmentIndex == refSeg.segmentIndex) {
            if (refSeg.matchesWith(seg)) {
              bestMatch = seg;
              bestScore = 1000.0; // High priority for index match
              break;
            }
          }
        }

        // Strategy 2: If no index match, find best by GPS + power + duration score
        if (bestMatch == null) {
          for (final seg in lapSegments) {
            if (refSeg.matchesWith(seg)) {
              final score = refSeg.matchScore(seg);
              if (score > bestScore) {
                bestMatch = seg;
                bestScore = score;
              }
            }
          }
        }

        if (bestMatch != null) {
          matchedMap[lapIdx] = bestMatch;
          pressures.add(bestMatch.pressure);
          efficiencies.add(bestMatch.efficiency);
          powerVariations.add((bestMatch.avgPower - refSeg.avgPower).abs());
          durationVariations.add((bestMatch.duration - refSeg.duration).abs());
        } else {
          isComplete = false;
        }
      }

      // Only include if we found matches in ALL laps
      if (isComplete && matchedMap.length == numLaps) {
        // Calculate quality metrics before adding
        final quality = _calculateSegmentClusterQuality(
          refSeg,
          matchedMap,
          powerVariations,
          durationVariations,
        );

        final matched = MatchedSegment(
          segmentId: refSegIdx,
          segmentsByLap: matchedMap,
          pressures: pressures,
          efficiencies: efficiencies,
        );

        // Log quality score
        final powerCv = (quality['powerCv'] as num?)?.toDouble();
        final durationCv = (quality['durationCv'] as num?)?.toDouble();
        final score = (quality['score'] as num?)?.toDouble();
        print('✓ Segment $refSegIdx matched: power stability=${powerCv?.toStringAsFixed(2) ?? 'n/a'}, '
          'duration stability=${durationCv?.toStringAsFixed(2) ?? 'n/a'}, '
          'quality_score=${score?.toStringAsFixed(3) ?? 'n/a'}');

        matchedSegments.add(matched);
      } else if (!isComplete) {
        print('✗ Segment $refSegIdx rejected: missing from ${numLaps - matchedMap.length} laps');
      }
    }

    return matchedSegments;
  }

  /// Calculate quality score for a matched segment cluster
  /// Score = N × power_consistency × duration_consistency
  /// Higher = better
  static Map<String, double> _calculateSegmentClusterQuality(
    ConstantPowerSegment refSeg,
    Map<int, ConstantPowerSegment> matchedMap,
    List<double> powerVariations,
    List<double> durationVariations,
  ) {
    final n = matchedMap.length.toDouble();

    // Power consistency: CV of power across laps
    double powerCv = 0.0;
    if (powerVariations.isNotEmpty && refSeg.avgPower > 0) {
      final meanVar = powerVariations.fold(0.0, (a, b) => a + b) / powerVariations.length;
      powerCv = meanVar / refSeg.avgPower;
    }

    // Duration consistency: CV of duration across laps
    double durationCv = 0.0;
    if (durationVariations.isNotEmpty && refSeg.duration > 0) {
      final meanVar = durationVariations.fold(0.0, (a, b) => a + b) / durationVariations.length;
      durationCv = meanVar / refSeg.duration;
    }

    // Final score = N × (quality factors)
    final powerFactor = 1.0 / (1.0 + powerCv); // Max 1.0 at CV=0
    final durationFactor = 1.0 / (1.0 + durationCv);
    final qualityScore = n * powerFactor * durationFactor;

    return {
      'powerCv': powerCv,
      'durationCv': durationCv,
      'powerFactor': powerFactor,
      'durationFactor': durationFactor,
      'score': qualityScore,
    };
  }

  /// Build regression data points: collect all (pressure, efficiency) pairs
  /// Only includes complete, high-quality matches
  static List<MapEntry<double, double>> buildRegressionPoints(
    List<MatchedSegment> matchedSegments,
  ) {
    final points = <MapEntry<double, double>>[];

    print('📊 Building regression dataset from ${matchedSegments.length} matched segments:');
    int includedPoints = 0;

    for (final matched in matchedSegments) {
      if (matched.isIncomplete) {
        print('  ✗ Segment ${matched.segmentId}: marked incomplete');
        continue; // Skip incomplete segments
      }

      if (matched.pressures.isEmpty || matched.efficiencies.isEmpty) {
        print('  ✗ Segment ${matched.segmentId}: empty data');
        continue;
      }

      for (int i = 0; i < matched.pressures.length; i++) {
        points.add(MapEntry(
          matched.pressures[i],
          matched.efficiencies[i],
        ));
        includedPoints++;
      }

      print('  ✓ Segment ${matched.segmentId}: ${matched.pressures.length} points added '
          '(pressures: ${matched.pressures.map((p) => p.toStringAsFixed(1)).join(', ')}, '
          'efficiencies: ${matched.efficiencies.map((e) => e.toStringAsFixed(3)).join(', ')})');
    }

    print('💾 Total regression points: $includedPoints');
    return points;
  }

  /// Provide analysis summary for UI display
  static Map<String, dynamic> getAnalysisSummary(
    List<List<ConstantPowerSegment>> allLaps,
    List<MatchedSegment> matchedSegments,
  ) {
    int totalSegmentsDetected = 0;
    for (final lap in allLaps) {
      totalSegmentsDetected += lap.length;
    }

    final matchedCount = matchedSegments.length;
    final incompleteCount =
        matchedSegments.where((s) => s.isIncomplete).length;
    
    // Calculate data quality metrics
    int totalDataPoints = 0;
    for (final matched in matchedSegments) {
      if (!matched.isIncomplete) {
        totalDataPoints += matched.pressures.length;
      }
    }

    return {
      'totalLaps': allLaps.length,
      'segmentsPerLap': allLaps.map((lap) => lap.length).toList(),
      'totalSegmentsDetected': totalSegmentsDetected,
      'matchedSegments': matchedCount,
      'incompleteSegments': incompleteCount,
      'regressionDataPoints': totalDataPoints,
      'dataQuality': matchedCount >= 3 ? 'GOOD (≥3 segments)' : 'POOR (<3 segments)',
    };
  }
}
