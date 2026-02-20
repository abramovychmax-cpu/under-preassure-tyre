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

/// Internal holder for raw per-sample arrays and the detected coasting window.
/// Used between Stage 1 (extraction) and the trimming step so we can do
/// distance-based interpolation before building the final [DescentSegment].
class _RawDescent {
  final int runIdx;
  final double frontPressure;
  final double rearPressure;
  // Full-run parallel arrays (1 entry per recorded second)
  final List<double> altitudes;
  final List<double> speeds;      // m/s
  final List<double> distances;   // per-lap cumulative wheel distance (m)
  final List<double> lats;
  final List<double> lons;
  // Detected coasting window indices into the arrays above
  final int start;
  final int end;

  _RawDescent({
    required this.runIdx,
    required this.frontPressure,
    required this.rearPressure,
    required this.altitudes,
    required this.speeds,
    required this.distances,
    required this.lats,
    required this.lons,
    required this.start,
    required this.end,
  });

  /// Wheel-sensor distance covered during the coasting window (meters).
  double get coastingDistance => distances[end] - distances[start];
  double get startLat => lats[start];
  double get startLon => lons[start];
}

class CoastDownClusteringService {
  // ── Pipeline constants ──
  /// GPS radius used to confirm all runs started at the same physical point.
  /// Start-point only — end-point no longer used (trimming makes it irrelevant).
  static const double _startGpsRadiusM = 50.0;
  static const double _minAltitudeDropM = 5.0;
  static const double _maxAltitudeErrorRate = 0.20; // 20% erratic points allowed
  static const double _signatureMatchRadiusM = 1000.0;
  static const int _flatOrUpTolerance = 3;          // Points before descent end declared
  static const String _signatureKey = 'route_signatures_v2';

  // Standing-start, brake-aware triggers
  static const double _startSpeedThresholdMs = 0.3;   // First nonzero wheel speed (~1 km/h)
  static const int _pushOffIgnoreSeconds = 2;         // Skip early wobble from the shove-off
  static const double _powerSpikeThresholdW = 80.0;   // Keep start after any pedal spike
  static const int _powerSpikeLookahead = 1;          // Look ±1s around start for spikes
  static const double _brakeDecelThresholdMs2 = -1.25; // Rapid decel flag (m/s², 1 Hz delta)
  static const double _brakeDropFraction = 0.22;       // ≥22% speed drop within window = brake
  static const int _brakeWindowSeconds = 2;            // Window to evaluate braking

  // ────────────────────────────────────────────────────────────────────────────
  // MAIN ENTRY POINT
  // ────────────────────────────────────────────────────────────────────────────

  /// Run the revised coast-down analysis pipeline on parsed JSONL data.
  ///
  /// New approach (distance-based trimming):
  ///   Stage 1 — Extract coasting window from each run (cadence=0 + altitude drop)
  ///   Stage 2 — GPS start-point clustering (±50 m) — confirm same hill only
  ///   Stage 3 — Trim all runs to median wheel distance; interpolate vEnd + altDrop
  ///   Stage 4 — Learn and store route signature
  ///   Stage 5 — Quality rank clusters; pick best ≥3 runs
  ///   Stage 6 — Return validated [DescentSegment]s for quadratic regression
  static Future<List<DescentSegment>> analyzeDescents(
    Map<int, List<Map<String, dynamic>>> recordsByRun,
    Map<int, Map<String, dynamic>> runMetadata,
  ) async {
    // ── Stage 1: Extract raw coasting window from each run ──
    final rawDescents = <_RawDescent>[];
    for (final runIdx in recordsByRun.keys) {
      final records = recordsByRun[runIdx]!;
      final meta = runMetadata[runIdx] ?? {};
      final front = (meta['frontPressure'] as num?)?.toDouble() ?? 0.0;
      final rear  = (meta['rearPressure']  as num?)?.toDouble() ?? 0.0;

      final raw = _extractRawDescent(records, runIdx, front, rear);
      if (raw != null) {
        rawDescents.add(raw);
        print('✓ Stage 1 | Run $runIdx: '
            '${raw.coastingDistance.toStringAsFixed(0)} m wheel-dist, '
            '${(raw.end - raw.start)}s window');
      } else {
        print('✗ Stage 1 | Run $runIdx: no valid coasting window');
      }
    }

    if (rawDescents.length < 3) {
      throw Exception('Stage 1: Only ${rawDescents.length} valid descents found (need 3+)');
    }

    // ── Stage 2: GPS start-point clustering (±${_startGpsRadiusM}m) ──
    final gpsGroups = _clusterByStartGPS(rawDescents);
    print('✓ Stage 2 | ${gpsGroups.length} GPS start cluster(s)');

    if (gpsGroups.isEmpty) {
      throw Exception('Stage 2: No GPS start clusters formed — runs started too far apart');
    }

    // Pick the largest group with ≥3 runs
    gpsGroups.sort((a, b) => b.length.compareTo(a.length));
    final bestGroup = gpsGroups.first;
    if (bestGroup.length < 3) {
      throw Exception('Stage 2: Largest cluster has only ${bestGroup.length} runs (need 3+)');
    }
    print('✓ Stage 2 | Best cluster: ${bestGroup.length} runs within ${_startGpsRadiusM}m start radius');

    // ── Stage 3: Trim to gate distance (minimum run length); recalculate vEnd + altDrop ──
    final segments = _trimToGateDistance(bestGroup);
    print('✓ Stage 3 | Trimmed ${segments.length} runs to gate distance');

    if (segments.length < 3) {
      throw Exception('Stage 3: Only ${segments.length} runs survived trimming (need 3+)');
    }

    // ── Stage 4: Learn and store route signature ──
    try {
      await _learnAndStoreSignature(segments);
    } catch (e) {
      print('⚠ Stage 4 | Signature storage failed: $e');
    }

    // ── Stage 5: Quality rank (duration consistency within trimmed set) ──
    // All runs are now the same distance — just return all ≥3; rank by CRR spread
    segments.sort((a, b) => a.rearPressure.compareTo(b.rearPressure));
    print('✓ Pipeline complete: ${segments.length}/${recordsByRun.length} runs → regression');

    return segments;
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Stage 1: Extract raw coasting window from a single recording run
  // ────────────────────────────────────────────────────────────────────────────
  //
  // Returns a [_RawDescent] with full per-sample arrays and detected
  // start/end indices. End is set at braking / GPS turnaround / flat run-out.
  // The arrays are NOT trimmed here — distance-based trimming happens in Stage 3.

  static _RawDescent? _extractRawDescent(
    List<Map<String, dynamic>> records,
    int runIdx,
    double frontPressure,
    double rearPressure,
  ) {
    if (records.length < 5) return null;

    final altitudes  = <double>[];
    final speeds     = <double>[]; // m/s
    final distances  = <double>[]; // per-lap cumulative wheel distance (m)
    final lats       = <double>[];
    final lons       = <double>[];
    final powers     = <double>[];

    for (final r in records) {
      altitudes.add((r['altitude']  as num?)?.toDouble() ?? 0.0);
      speeds.add(((r['speed_kmh']   as num?)?.toDouble() ?? 0.0) / 3.6);
      distances.add((r['distance']  as num?)?.toDouble() ?? 0.0);
      lats.add((r['lat']            as num?)?.toDouble() ?? 0.0);
      lons.add((r['lon']            as num?)?.toDouble() ?? 0.0);
      powers.add((r['power']        as num?)?.toDouble() ?? 0.0);
    }

    // ── Find coasting START ──
    int start = speeds.indexWhere((s) => s > _startSpeedThresholdMs);
    if (start == -1) return null;
    start = math.min(start + _pushOffIgnoreSeconds, speeds.length - 1);
    for (int i = start; i < speeds.length; i++) {
      final w0 = math.max(0, i - _powerSpikeLookahead);
      final w1 = math.min(speeds.length - 1, i + _powerSpikeLookahead);
      double maxPow = 0;
      for (int j = w0; j <= w1; j++) { if (powers[j] > maxPow) maxPow = powers[j]; }
      if (maxPow <= _powerSpikeThresholdW) { start = i; break; }
    }
    if (start >= altitudes.length - 3) return null;

    // ── Find coasting END: brake → GPS turnaround → flat run-out ──
    int end = start;
    int flatCount = 0;
    for (int i = start + 1; i < altitudes.length - 1; i++) {
      final deltaV = speeds[i] - speeds[i - 1];
      final wStart = math.max(start, i - _brakeWindowSeconds);
      final wMax   = speeds.sublist(wStart, i + 1).reduce(math.max);
      final drop   = wMax > 0 ? (wMax - speeds[i]) / wMax : 0.0;

      if (deltaV <= _brakeDecelThresholdMs2 || drop >= _brakeDropFraction) {
        end = i;
        break;
      }
      if (altitudes[i] > altitudes[i + 1]) { flatCount = 0; } else { flatCount++; }
      if (speeds[i] < 1.0) flatCount++;
      if (_isGpsTurnaround(lats, lons, start, i)) { end = i; break; }
      if (flatCount >= _flatOrUpTolerance) { end = i; break; }
      end = i;
    }
    if (end <= start + 3) return null;

    // ── Validate altitude profile ──
    final dAlt = altitudes.sublist(start, end + 1);
    int errors = 0;
    for (int i = 0; i < dAlt.length - 1; i++) { if (dAlt[i] <= dAlt[i + 1]) errors++; }
    if (errors / dAlt.length > _maxAltitudeErrorRate) return null;
    if (dAlt.first - dAlt.last < _minAltitudeDropM) return null;

    return _RawDescent(
      runIdx: runIdx,
      frontPressure: frontPressure,
      rearPressure: rearPressure,
      altitudes: altitudes,
      speeds: speeds,
      distances: distances,
      lats: lats,
      lons: lons,
      start: start,
      end: end,
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
  // Stage 2: GPS start-point clustering (start only, ±50 m)
  // ────────────────────────────────────────────────────────────────────────────
  //
  // Groups runs whose coasting start points are within [_startGpsRadiusM].
  // End-point is no longer matched — trimming in Stage 3 handles that.

  static List<List<_RawDescent>> _clusterByStartGPS(
    List<_RawDescent> raws,
  ) {
    final clusters = <List<_RawDescent>>[];
    final used = <int>{};

    for (int i = 0; i < raws.length; i++) {
      if (used.contains(i)) continue;
      final cluster = [raws[i]];
      used.add(i);
      for (int j = i + 1; j < raws.length; j++) {
        if (used.contains(j)) continue;
        final d = _haversine(
          raws[i].startLat, raws[i].startLon,
          raws[j].startLat, raws[j].startLon,
        );
        if (d <= _startGpsRadiusM) {
          cluster.add(raws[j]);
          used.add(j);
        }
      }
      clusters.add(cluster);
    }
    return clusters;
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Stage 3: Trim all runs to median wheel distance; build DescentSegments
  // ────────────────────────────────────────────────────────────────────────────
  //
  // 1. Compute coasting distance (wheel revs) for each run.
  // 2. Reference = median distance (avoids outlier short/long runs).
  // 3. For each run, interpolate speed and altitude at the reference distance.
  // 4. Calculate CRR using the trimmed vEnd and altDrop.

  // ────────────────────────────────────────────────────────────────────────────
  // Stage 3: Gate-based distance trim (Strava-style fixed exit gate)
  // ────────────────────────────────────────────────────────────────────────────
  //
  // The exit gate is placed at minDist meters from the shared start point.
  // Every run is trimmed to that gate via linear interpolation so all CRR
  // calculations use identical road length.
  //
  // Ratio log: if min/max < 0.5 one run braked very early — worth investigating,
  // but we still proceed with the minimum gate rather than discarding runs.

  static List<DescentSegment> _trimToGateDistance(
    List<_RawDescent> raws,
  ) {
    // Entry gate = latest coasting start across all runs
    //              (every run is guaranteed to have been freewheeling from here)
    // Exit gate  = earliest coasting end
    //              (every run is guaranteed to have still been coasting until here)
    final entryGate  = raws.map((r) => r.distances[r.start]).reduce(math.max);
    final exitGate   = raws.map((r) => r.distances[r.end]).reduce(math.min);
    final gateLength = exitGate - entryGate;

    if (gateLength <= 0) {
      throw Exception(
        'Stage 3: Coasting windows do not overlap '
        '(entry=${entryGate.toStringAsFixed(0)} m, exit=${exitGate.toStringAsFixed(0)} m). '
        'Runs may cover different sections of the descent.',
      );
    }

    final allRunDists = raws
        .map((r) => r.distances[r.end] - r.distances[r.start])
        .toList()..sort();
    final ratio = allRunDists.last > 0 ? gateLength / allRunDists.last : 1.0;
    print('  ↳ Gate: entry=${entryGate.toStringAsFixed(0)} m'
        ' → exit=${exitGate.toStringAsFixed(0)} m'
        '  |  length=${gateLength.toStringAsFixed(0)} m'
        '  |  ratio=${ratio.toStringAsFixed(2)}'
        '${ratio < 0.5 ? '  ⚠ one run has very short/late coasting' : ''}');

    // Linear interpolation helper
    double interpolate(List<double> arr, int i, double frac) =>
        arr[i] + (arr[i + 1] - arr[i]) * frac;

    final segments = <DescentSegment>[];

    for (final raw in raws) {
      final s = raw.start;
      final e = raw.end;

      // ── Find entry gate crossing ──────────────────────────────────────────
      int    entryIdx  = s;
      double entryFrac = 0.0;
      for (int i = s; i < e; i++) {
        if (raw.distances[i + 1] >= entryGate) {
          final span = raw.distances[i + 1] - raw.distances[i];
          entryFrac = span > 0 ? (entryGate - raw.distances[i]) / span : 0.0;
          entryIdx  = i;
          break;
        }
      }

      // ── Find exit gate crossing (search from entry onwards) ───────────────
      int    exitIdx  = e;
      double exitFrac = 0.0;
      for (int i = entryIdx; i < e; i++) {
        if (raw.distances[i + 1] >= exitGate) {
          final span = raw.distances[i + 1] - raw.distances[i];
          exitFrac = span > 0 ? (exitGate - raw.distances[i]) / span : 0.0;
          exitIdx  = i;
          break;
        }
      }

      // Interpolated values at both gate crossings
      final vEntry   = interpolate(raw.speeds,    entryIdx, entryFrac);
      final vExit    = interpolate(raw.speeds,    exitIdx,  exitFrac);
      final altEntry = interpolate(raw.altitudes, entryIdx, entryFrac);
      final altExit  = interpolate(raw.altitudes, exitIdx,  exitFrac);
      final altDrop  = altEntry - altExit;

      if (altDrop < _minAltitudeDropM) {
        print('  ✗ Run ${raw.runIdx}: altDrop=${altDrop.toStringAsFixed(1)} m'
            ' < $_minAltitudeDropM m after gate trim, skipping');
        continue;
      }

      final dSpd   = raw.speeds.sublist(entryIdx, exitIdx + 1);
      final avgSpd = dSpd.reduce((a, b) => a + b) / dSpd.length;
      final maxSpd = dSpd.reduce((a, b) => a > b ? a : b);
      final duration = (exitIdx - entryIdx).toDouble() + exitFrac - entryFrac;

      final crr        = _calculateCRR(altDrop, gateLength, vEntry, vExit);
      final efficiency = gateLength / math.max(maxSpd, 0.1);

      print('  ✓ Run ${raw.runIdx}: '
          'gate [${entryGate.toStringAsFixed(0)}, ${exitGate.toStringAsFixed(0)}] m | '
          'altDrop=${altDrop.toStringAsFixed(1)} m | '
          'vEntry=${vEntry.toStringAsFixed(1)}→vExit=${vExit.toStringAsFixed(1)} m/s | '
          'CRR=${crr.toStringAsFixed(5)}');

      segments.add(DescentSegment(
        runIndex:        raw.runIdx,
        frontPressure:   raw.frontPressure,
        rearPressure:    raw.rearPressure,
        altitudeDrop:    altDrop,
        durationSeconds: duration,
        avgSpeed:        avgSpd,
        maxSpeed:        maxSpd,
        distance:        gateLength,
        startLat:        interpolate(raw.lats, entryIdx, entryFrac),
        startLon:        interpolate(raw.lons, entryIdx, entryFrac),
        endLat:          interpolate(raw.lats, exitIdx,  exitFrac),
        endLon:          interpolate(raw.lons, exitIdx,  exitFrac),
        crr:             crr,
        efficiency:      efficiency,
        numRecords:      exitIdx - entryIdx + 1,
      ));
    }

    return segments;
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
