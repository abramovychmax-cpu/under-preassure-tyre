import 'dart:math' as math;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Data Classes ──────────────────────────────────────────────────────────────

/// Pure descent segment extracted and validated from a recording run.
/// Output of the 6-stage coast-down analysis pipeline.
class DescentSegment {
  final int runIndex;           // Original lapIndex from recording
  final double frontPressure;   // Front tire pressure (PSI)
  final double rearPressure;    // Rear tire pressure (PSI) — regression X-axis
  final double altitudeDrop;    // Elevation loss during descent (meters)
  final double durationSeconds; // Duration of pure descent (seconds)
  final double avgSpeed;        // Mean speed during descent (m/s)
  final double maxSpeed;        // Peak speed during descent (m/s)
  final double distance;        // Distance covered (meters)
  final double startLat;        // GPS latitude at descent start
  final double startLon;        // GPS longitude at descent start
  final double endLat;          // GPS latitude at descent end
  final double endLon;          // GPS longitude at descent end
  final double crr;             // Coefficient of rolling resistance
  final double efficiency;      // distance / maxSpeed — regression Y-axis
  final int numRecords;         // Number of data points in descent

  DescentSegment({
    required this.runIndex,
    required this.frontPressure,
    required this.rearPressure,
    required this.altitudeDrop,
    required this.durationSeconds,
    required this.avgSpeed,
    required this.maxSpeed,
    required this.distance,
    required this.startLat,
    required this.startLon,
    required this.endLat,
    required this.endLon,
    required this.crr,
    required this.efficiency,
    required this.numRecords,
  });
}

/// Route signature learned from 3+ validated descents.
/// Stored per GPS location for adaptive thresholds on return visits.
class RouteSignature {
  final double meanAltitudeDrop;
  final double stdDevAltitudeDrop;
  final double meanDuration;
  final double stdDevDuration;
  final double meanSpeed;
  final double stdDevSpeed;
  final double centerLat;
  final double centerLon;
  final DateTime learnedAt;
  final int sampleCount;

  // Adaptive thresholds: mean ± 1.5σ
  late final double minAltitudeDrop;
  late final double maxAltitudeDrop;
  late final double minDuration;
  late final double maxDuration;
  late final double minSpeed;
  late final double maxSpeed;

  RouteSignature({
    required this.meanAltitudeDrop,
    required this.stdDevAltitudeDrop,
    required this.meanDuration,
    required this.stdDevDuration,
    required this.meanSpeed,
    required this.stdDevSpeed,
    required this.centerLat,
    required this.centerLon,
    required this.learnedAt,
    required this.sampleCount,
  }) {
    const k = 1.5;
    minAltitudeDrop = meanAltitudeDrop - stdDevAltitudeDrop * k;
    maxAltitudeDrop = meanAltitudeDrop + stdDevAltitudeDrop * k;
    minDuration = meanDuration - stdDevDuration * k;
    maxDuration = meanDuration + stdDevDuration * k;
    minSpeed = meanSpeed - stdDevSpeed * k;
    maxSpeed = meanSpeed + stdDevSpeed * k;
  }

  Map<String, dynamic> toJson() => {
        'meanAltitudeDrop': meanAltitudeDrop,
        'stdDevAltitudeDrop': stdDevAltitudeDrop,
        'meanDuration': meanDuration,
        'stdDevDuration': stdDevDuration,
        'meanSpeed': meanSpeed,
        'stdDevSpeed': stdDevSpeed,
        'centerLat': centerLat,
        'centerLon': centerLon,
        'learnedAt': learnedAt.toIso8601String(),
        'sampleCount': sampleCount,
      };

  static RouteSignature fromJson(Map<String, dynamic> json) {
    return RouteSignature(
      meanAltitudeDrop: (json['meanAltitudeDrop'] as num).toDouble(),
      stdDevAltitudeDrop: (json['stdDevAltitudeDrop'] as num).toDouble(),
      meanDuration: (json['meanDuration'] as num).toDouble(),
      stdDevDuration: (json['stdDevDuration'] as num).toDouble(),
      meanSpeed: (json['meanSpeed'] as num).toDouble(),
      stdDevSpeed: (json['stdDevSpeed'] as num).toDouble(),
      centerLat: (json['centerLat'] as num).toDouble(),
      centerLon: (json['centerLon'] as num).toDouble(),
      learnedAt: DateTime.parse(json['learnedAt'] as String),
      sampleCount: (json['sampleCount'] as num).toInt(),
    );
  }

  @override
  String toString() => 'RouteSignature('
      'alt=${meanAltitudeDrop.toStringAsFixed(1)}m±${stdDevAltitudeDrop.toStringAsFixed(1)}, '
      'dur=${meanDuration.toStringAsFixed(1)}s±${stdDevDuration.toStringAsFixed(1)}, '
      'spd=${meanSpeed.toStringAsFixed(2)}m/s±${stdDevSpeed.toStringAsFixed(2)}, '
      'runs=$sampleCount)';
}

// ─── 6-Stage Coast-Down Analysis Pipeline ──────────────────────────────────────
//
// Stage 1: Extract pure descent from each recording run
//          (altitude profile scanning, turnaround detection, noise filtering)
// Stage 2: Adaptive baseline validation
//          (first run = reference, duration ±10%, speed ≥95% of slowest, alt ≥5m)
// Stage 3: GPS route matching
//          (start-to-start ≤100m AND end-to-end ≤100m → same hill, same route)
// Stage 4: Route signature learning + persistence
//          (mean ± 1.5σ for altitude/duration/speed, stored by GPS for return visits)
// Stage 5: Cluster quality ranking
//          (score = N × duration_consistency × GPS_tightness, pick best ≥3 runs)
// Stage 6: Output validated segments for quadratic regression
//

class CoastDownClusteringService {
  // ── Pipeline constants ──
  static const double _gpsClusterRadiusM = 100.0;
  static const double _durationTolerancePct = 10.0;
  static const double _minAltitudeDropM = 5.0;
  static const double _maxAltitudeErrorRate = 0.20; // 20% erratic points allowed
  static const double _minDescentSpeedMs = 2.0;     // Must be moving at descent start
  static const double _speedThresholdPct = 95.0;    // 95% of slowest max_speed
  static const double _signatureMatchRadiusM = 1000.0;
  static const int _consecutiveDrops = 3;           // Consecutive falling points to detect start
  static const int _flatOrUpTolerance = 3;          // Points before descent end declared
  static const String _signatureKey = 'route_signatures_v2';

  // ────────────────────────────────────────────────────────────────────────────
  // MAIN ENTRY POINT
  // ────────────────────────────────────────────────────────────────────────────

  /// Run the full 6-stage pipeline on parsed JSONL data.
  /// [recordsByRun] — sensor records grouped by lapIndex
  /// [runMetadata]  — pressure metadata per lapIndex
  /// Returns validated [DescentSegment]s ready for quadratic regression.
  static Future<List<DescentSegment>> analyzeDescents(
    Map<int, List<Map<String, dynamic>>> recordsByRun,
    Map<int, Map<String, dynamic>> runMetadata,
  ) async {
    // ── Stage 1: Extract pure descent from each run ──
    final segments = <DescentSegment>[];
    for (final runIdx in recordsByRun.keys) {
      final records = recordsByRun[runIdx]!;
      final meta = runMetadata[runIdx] ?? {};
      final front = (meta['frontPressure'] as num?)?.toDouble() ?? 0.0;
      final rear = (meta['rearPressure'] as num?)?.toDouble() ?? 0.0;

      final segment = _extractDescent(records, runIdx, front, rear);
      if (segment != null) {
        segments.add(segment);
        print('✓ Stage 1 | Run $runIdx: '
            '${segment.durationSeconds.toStringAsFixed(0)}s, '
            '${segment.altitudeDrop.toStringAsFixed(1)}m drop, '
            '${segment.maxSpeed.toStringAsFixed(1)}m/s max');
      } else {
        print('✗ Stage 1 | Run $runIdx: no valid descent extracted');
      }
    }

    if (segments.length < 3) {
      throw Exception(
          'Stage 1: Only ${segments.length} valid descents found (need 3+)');
    }

    // ── Stage 2: Adaptive baseline validation ──
    final validated = _validateAgainstBaseline(segments);
    print('✓ Stage 2 | ${validated.length}/${segments.length} passed baseline');

    if (validated.length < 3) {
      throw Exception(
          'Stage 2: Only ${validated.length} runs passed validation (need 3+)');
    }

    // ── Stage 3: GPS route clustering (start AND end) ──
    final clusters = _clusterByGPS(validated);
    print('✓ Stage 3 | ${clusters.length} GPS cluster(s) formed');

    if (clusters.isEmpty) {
      throw Exception('Stage 3: No GPS clusters formed');
    }

    // ── Stage 5: Quality ranking (before 4 so we pick best first) ──
    clusters.sort((a, b) =>
        _clusterQualityScore(b).compareTo(_clusterQualityScore(a)));
    final best = clusters.first;
    print('✓ Stage 5 | Best cluster: ${best.length} runs, '
        'quality=${_clusterQualityScore(best).toStringAsFixed(3)}');

    if (best.length < 3) {
      throw Exception(
          'Stage 5: Best cluster has ${best.length} runs (need 3+)');
    }

    // ── Stage 4: Learn and store route signature ──
    try {
      await _learnAndStoreSignature(best);
    } catch (e) {
      print('⚠ Stage 4 | Signature storage failed: $e');
    }

    // ── Stage 6: Return validated descent segments ──
    print('✓ Pipeline complete: ${best.length}/${recordsByRun.length} runs → regression');
    return best;
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Stage 1: Extract pure descent from a single recording run
  // ────────────────────────────────────────────────────────────────────────────
  //
  // Scans altitude profile for consistent downhill movement.
  // Discards: walk-back, standing at top, flat run-out at bottom.
  // Validates: altitude consistency ≤ 20% erratic, drop ≥ 5m.

  static DescentSegment? _extractDescent(
    List<Map<String, dynamic>> records,
    int runIdx,
    double frontPressure,
    double rearPressure,
  ) {
    if (records.length < 5) return null;

    // Build parallel arrays from JSONL records
    final altitudes = <double>[];
    final speeds = <double>[]; // m/s
    final lats = <double>[];
    final lons = <double>[];

    for (final r in records) {
      altitudes.add((r['altitude'] as num?)?.toDouble() ?? 0.0);
      speeds.add(((r['speed_kmh'] as num?)?.toDouble() ?? 0.0) / 3.6);
      lats.add((r['lat'] as num?)?.toDouble() ?? 0.0);
      lons.add((r['lon'] as num?)?.toDouble() ?? 0.0);
    }

    // ── Find descent START: N consecutive altitude drops while moving ──
    int start = -1;
    for (int i = 0; i < altitudes.length - _consecutiveDrops; i++) {
      bool dropping = true;
      for (int j = 0; j < _consecutiveDrops - 1; j++) {
        if (altitudes[i + j] <= altitudes[i + j + 1]) {
          dropping = false;
          break;
        }
      }
      if (dropping && speeds[i] > _minDescentSpeedMs) {
        start = i;
        break;
      }
    }
    if (start == -1) return null;

    // ── Find descent END: altitude reverses, speed dies, or GPS turnaround ──
    int end = start;
    int flatCount = 0;

    for (int i = start + 1; i < altitudes.length - 1; i++) {
      if (altitudes[i] > altitudes[i + 1]) {
        flatCount = 0; // Still descending — reset counter
      } else {
        flatCount++;
      }

      // Speed died
      if (speeds[i] < 1.0) flatCount++;

      // GPS turnaround (moving back toward descent start)
      if (_isGpsTurnaround(lats, lons, start, i)) {
        end = i;
        break;
      }

      // Too many non-descending points
      if (flatCount >= _flatOrUpTolerance) {
        end = i;
        break;
      }

      end = i;
    }

    if (end <= start + 3) return null; // Too short

    // ── Validate altitude profile ──
    final dAlt = altitudes.sublist(start, end + 1);
    final dSpd = speeds.sublist(start, end + 1);

    // Count erratic points (altitude goes up during supposed descent)
    int errors = 0;
    for (int i = 0; i < dAlt.length - 1; i++) {
      if (dAlt[i] <= dAlt[i + 1]) errors++;
    }
    final errorRate = errors / dAlt.length;
    if (errorRate > _maxAltitudeErrorRate) {
      print('  ✗ Run $runIdx: altitude error rate '
          '${(errorRate * 100).toStringAsFixed(0)}% > '
          '${(_maxAltitudeErrorRate * 100).toStringAsFixed(0)}%');
      return null;
    }

    final altDrop = dAlt.first - dAlt.last;
    if (altDrop < _minAltitudeDropM) {
      print('  ✗ Run $runIdx: altitude drop '
          '${altDrop.toStringAsFixed(1)}m < ${_minAltitudeDropM}m');
      return null;
    }

    // ── Compute metrics ──
    final duration = dAlt.length.toDouble(); // 1 record ≈ 1 second
    final avgSpd = dSpd.reduce((a, b) => a + b) / dSpd.length;
    final maxSpd = dSpd.reduce((a, b) => a > b ? a : b);
    final vStart = dSpd.first;
    final vEnd = dSpd.last;
    final dist = avgSpd * duration;
    final crr = _calculateCRR(altDrop, dist, vStart, vEnd);
    final efficiency = dist / math.max(maxSpd, 0.1);

    return DescentSegment(
      runIndex: runIdx,
      frontPressure: frontPressure,
      rearPressure: rearPressure,
      altitudeDrop: altDrop,
      durationSeconds: duration,
      avgSpeed: avgSpd,
      maxSpeed: maxSpd,
      distance: dist,
      startLat: lats[start],
      startLon: lons[start],
      endLat: lats[end],
      endLon: lons[end],
      crr: crr,
      efficiency: efficiency,
      numRecords: dAlt.length,
    );
  }

  /// Detect GPS turnaround: rider moving back toward descent start point.
  /// Compares current distance-from-start against max seen in last 10 points.
  /// If current < 50% of max and max > 50m, we're turning around.
  static bool _isGpsTurnaround(
    List<double> lats,
    List<double> lons,
    int origin,
    int idx,
  ) {
    if (idx - origin < 10) return false;

    final currentDist = _haversine(
      lats[origin], lons[origin],
      lats[idx], lons[idx],
    );

    double maxDist = 0;
    for (int i = math.max(origin, idx - 10); i < idx; i++) {
      final d = _haversine(lats[origin], lons[origin], lats[i], lons[i]);
      if (d > maxDist) maxDist = d;
    }

    return maxDist > 50 && currentDist < maxDist * 0.5;
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Stage 2: Adaptive baseline validation
  // ────────────────────────────────────────────────────────────────────────────
  //
  // First valid descent = baseline reference.
  // Duration: ±10% of baseline.
  // Max speed: ≥ 95% of the slowest max_speed across ALL runs.
  // Altitude drop: ≥ 5m minimum.

  static List<DescentSegment> _validateAgainstBaseline(
    List<DescentSegment> segments,
  ) {
    if (segments.isEmpty) return [];

    final baseline = segments.first;
    final durTol = baseline.durationSeconds * (_durationTolerancePct / 100.0);

    // Speed threshold: 95% of the slowest max_speed
    final slowestMax = segments.map((s) => s.maxSpeed).reduce(math.min);
    final minSpd = slowestMax * (_speedThresholdPct / 100.0);

    final passed = <DescentSegment>[];

    for (final s in segments) {
      final durOk =
          (s.durationSeconds - baseline.durationSeconds).abs() <= durTol;
      final spdOk = s.maxSpeed >= minSpd;
      final altOk = s.altitudeDrop >= _minAltitudeDropM;

      if (durOk && spdOk && altOk) {
        passed.add(s);
      } else {
        print('  ✗ Run ${s.runIndex} rejected: '
            'dur=${durOk ? "✓" : "✗"}(${s.durationSeconds.toStringAsFixed(0)}s) '
            'spd=${spdOk ? "✓" : "✗"}(${s.maxSpeed.toStringAsFixed(1)}m/s) '
            'alt=${altOk ? "✓" : "✗"}(${s.altitudeDrop.toStringAsFixed(1)}m)');
      }
    }

    return passed;
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Stage 3: GPS route clustering (start AND end within radius)
  // ────────────────────────────────────────────────────────────────────────────
  //
  // Both conditions required: same hilltop start AND same bottom end.
  // Prevents merging two different hills that share a starting area.

  static List<List<DescentSegment>> _clusterByGPS(
    List<DescentSegment> segments,
  ) {
    final clusters = <List<DescentSegment>>[];
    final used = <int>{};

    for (int i = 0; i < segments.length; i++) {
      if (used.contains(i)) continue;

      final cluster = [segments[i]];
      used.add(i);
      final ref = segments[i];

      for (int j = i + 1; j < segments.length; j++) {
        if (used.contains(j)) continue;

        final test = segments[j];

        // Start-to-start proximity
        final startDist = _haversine(
          ref.startLat, ref.startLon,
          test.startLat, test.startLon,
        );

        // End-to-end proximity
        final endDist = _haversine(
          ref.endLat, ref.endLon,
          test.endLat, test.endLon,
        );

        if (startDist <= _gpsClusterRadiusM &&
            endDist <= _gpsClusterRadiusM) {
          cluster.add(test);
          used.add(j);
        }
      }

      clusters.add(cluster);
    }

    return clusters;
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Stage 4: Route signature learning + SharedPreferences persistence
  // ────────────────────────────────────────────────────────────────────────────
  //
  // From 3+ validated runs, compute mean ± 1.5σ for altitude, duration, speed.
  // Store keyed by GPS center (±1km match radius).
  // On return visit, signature auto-loads for tighter validation from run #1.

  static Future<void> _learnAndStoreSignature(
    List<DescentSegment> cluster,
  ) async {
    if (cluster.length < 3) return;

    double mean(Iterable<double> v) => v.reduce((a, b) => a + b) / v.length;
    double stdDev(Iterable<double> v, double m) {
      final variance =
          v.map((x) => (x - m) * (x - m)).reduce((a, b) => a + b) / v.length;
      return math.sqrt(variance);
    }

    final altDrops = cluster.map((s) => s.altitudeDrop);
    final durations = cluster.map((s) => s.durationSeconds);
    final avgSpeeds = cluster.map((s) => s.avgSpeed);

    final mAlt = mean(altDrops);
    final mDur = mean(durations);
    final mSpd = mean(avgSpeeds);

    final sig = RouteSignature(
      meanAltitudeDrop: mAlt,
      stdDevAltitudeDrop: stdDev(altDrops, mAlt),
      meanDuration: mDur,
      stdDevDuration: stdDev(durations, mDur),
      meanSpeed: mSpd,
      stdDevSpeed: stdDev(avgSpeeds, mSpd),
      centerLat: mean(cluster.map((s) => s.startLat)),
      centerLon: mean(cluster.map((s) => s.startLon)),
      learnedAt: DateTime.now(),
      sampleCount: cluster.length,
    );

    // Persist to SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString(_signatureKey);
      final List<dynamic> list =
          existing != null ? jsonDecode(existing) as List<dynamic> : [];

      // Find existing signature for this location (within 1km)
      final matchIdx = list.indexWhere((item) {
        final s = item as Map<String, dynamic>;
        return _haversine(
              sig.centerLat,
              sig.centerLon,
              (s['centerLat'] as num).toDouble(),
              (s['centerLon'] as num).toDouble(),
            ) <
            _signatureMatchRadiusM;
      });

      if (matchIdx >= 0) {
        list[matchIdx] = sig.toJson(); // Update existing
      } else {
        list.add(sig.toJson()); // Add new
      }

      await prefs.setString(_signatureKey, jsonEncode(list));
      print('✓ Stage 4 | Signature saved: $sig');
    } catch (e) {
      print('⚠ Stage 4 | Storage error: $e');
    }
  }

  /// Load a previously learned signature for a GPS location (within 1km).
  /// Returns null if no signature exists for this area.
  static Future<RouteSignature?> loadSignatureNearby(
    double lat,
    double lon,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_signatureKey);
      if (raw == null) return null;

      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      for (final item in list) {
        final s = item as Map<String, dynamic>;
        final dist = _haversine(
          lat,
          lon,
          (s['centerLat'] as num).toDouble(),
          (s['centerLon'] as num).toDouble(),
        );
        if (dist < _signatureMatchRadiusM) {
          return RouteSignature.fromJson(s);
        }
      }
    } catch (e) {
      print('⚠ Failed to load route signature: $e');
    }
    return null;
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Stage 5: Cluster quality scoring
  // ────────────────────────────────────────────────────────────────────────────
  //
  // Score = N × duration_consistency × GPS_tightness
  //   N                    = number of runs (more = better)
  //   duration_consistency = 1 / (1 + CV_duration)  (lower CV = better)
  //   GPS_tightness        = 1 / (1 + maxSpread/50) (smaller spread = better)

  static double _clusterQualityScore(List<DescentSegment> cluster) {
    if (cluster.isEmpty) return 0.0;
    final n = cluster.length.toDouble();

    // Duration consistency
    double durFactor = 1.0;
    if (cluster.length >= 2) {
      final durs = cluster.map((s) => s.durationSeconds).toList();
      final mean = durs.reduce((a, b) => a + b) / durs.length;
      final variance =
          durs.map((d) => (d - mean) * (d - mean)).reduce((a, b) => a + b) /
              durs.length;
      final cv = mean > 0 ? math.sqrt(variance) / mean : 0.0;
      durFactor = 1.0 / (1.0 + cv);
    }

    // GPS tightness (max pairwise start-point spread)
    double gpsFactor = 1.0;
    if (cluster.length >= 2) {
      double maxSpread = 0;
      for (final a in cluster) {
        for (final b in cluster) {
          final d = _haversine(a.startLat, a.startLon, b.startLat, b.startLon);
          if (d > maxSpread) maxSpread = d;
        }
      }
      gpsFactor = 1.0 / (1.0 + maxSpread / 50.0);
    }

    return n * durFactor * gpsFactor;
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Helpers
  // ────────────────────────────────────────────────────────────────────────────

  /// Haversine distance between two GPS points (meters).
  static double _haversine(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    const R = 6371000.0; // Earth radius in meters
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return R * 2 * math.asin(math.sqrt(a));
  }

  static double _rad(double deg) => deg * math.pi / 180.0;

  /// Coefficient of Rolling Resistance from energy balance.
  /// 
  /// Physics: m·g·Δh = CRR·m·g·d + ½m·(v_end² - v_start²) + air_drag
  /// Solving for CRR (ignoring air drag at low speeds):
  /// CRR = (Δh - Δ(v²/2g)) / d
  /// 
  /// This accounts for the change in kinetic energy during coast-down.
  /// Previously used Δh/d which is only valid when v_start ≈ v_end.
  /// 
  /// Returns realistic tire CRR [0.002, 0.020].
  static double _calculateCRR(
    double altDrop, 
    double distance,
    double vStart,  // m/s
    double vEnd,    // m/s
  ) {
    if (distance <= 0) return 0.01;
    
    const g = 9.81; // m/s²
    
    // Change in kinetic energy per unit mass: Δ(v²/2)
    // Note: vEnd < vStart in coast-down → negative ΔKE → adds to available energy
    final deltaKineticEnergy = (vEnd * vEnd - vStart * vStart) / 2.0;
    
    // Energy balance: gravity_potential = rolling_resistance + kinetic_change
    // altDrop = CRR·distance + deltaKineticEnergy/g
    // CRR = (altDrop - deltaKineticEnergy/g) / distance
    final crr = (altDrop - deltaKineticEnergy / g) / distance;
    
    return crr.clamp(0.002, 0.020);
  }
}
