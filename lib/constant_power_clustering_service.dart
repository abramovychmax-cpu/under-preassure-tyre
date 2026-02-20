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

/// Internal holder for per-sample arrays within a confirmed constant-power window.
/// Used between detection and gate-based zone trimming so all laps can be compared
/// over identical road length (Strava-style fixed exit gate).
class _RawPowerSegment {
  final int lapIndex;
  final int segmentIndex;
  final double pressure;
  final List<double> powers;      // watts per 1-Hz sample
  final List<double> speeds;      // km/h per 1-Hz sample
  final List<double> distances;   // per-lap cumulative wheel distance (m)
  final List<double> lats;
  final List<double> lons;
  final DateTime startTime;
  final DateTime endTime;

  _RawPowerSegment({
    required this.lapIndex,
    required this.segmentIndex,
    required this.pressure,
    required this.powers,
    required this.speeds,
    required this.distances,
    required this.lats,
    required this.lons,
    required this.startTime,
    required this.endTime,
  });

  /// Total wheel distance covered in this segment (meters).
  double get segmentDistance =>
      distances.length < 2 ? 0.0 : distances.last - distances.first;

  double get startLat => lats.firstWhere((v) => v != 0.0, orElse: () => 0.0);
  double get startLon => lons.firstWhere((v) => v != 0.0, orElse: () => 0.0);
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


  /// Coefficient of variation helper
  static double _cv(List<double> values) {
    if (values.length < 2) return 0.0;
    final mean = values.fold(0.0, (a, b) => a + b) / values.length;
    if (mean <= 0) return double.infinity;
    final variance = values.fold(0.0, (s, v) => s + math.pow(v - mean, 2)) / values.length;
    return math.sqrt(variance) / mean;
  }

  /// Detect constant-power segments within a lap from JSONL records.
  ///
  /// Uses a **growing window**: starts at minWindow samples and extends
  /// forward as long as the power CV stays below [segmentThreshold].
  /// This avoids fragmenting long stable efforts into many 10-second pieces.
  static List<ConstantPowerSegment> _detectConstantPowerSegmentsFromJsonl(
    List<Map<String, dynamic>> records,
    int lapIdx,
    double pressure,
  ) {
    if (records.isEmpty) return [];

    final segments = <ConstantPowerSegment>[];
    const segmentThreshold = 0.10; // 10% CV = constant power
    const minWindow = 10;          // minimum stable run length (≈10 s at 1 Hz)

    int i = 0;
    int segmentId = 0;

    while (i + minWindow <= records.length) {
      // ── Seed: check the minimum window first ──────────────────────────────
      List<double> powers = records
          .sublist(i, i + minWindow)
          .map((r) => (r['power'] as num?)?.toDouble() ?? 0.0)
          .where((p) => p > 0)
          .toList();

      if (powers.length < minWindow ~/ 2 || _cv(powers) >= segmentThreshold) {
        i++;
        continue; // not enough data or too variable — slide by 1
      }

      // ── Grow: extend while the growing window stays stable ────────────────
      int end = i + minWindow; // exclusive end index
      while (end < records.length) {
        final p = (records[end]['power'] as num?)?.toDouble() ?? 0.0;
        if (p <= 0) break; // zero/missing power breaks the run
        final extended = [...powers, p];
        if (_cv(extended) >= segmentThreshold) break;
        powers = extended;
        end++;
      }

      // ── Extract all fields from the confirmed window ──────────────────────
      final window = records.sublist(i, end);
      final speeds      = <double>[];
      final lats        = <double>[];
      final lons        = <double>[];
      final vibrations  = <double>[];
      DateTime? startTime, endTime;

      for (final r in window) {
        speeds.add((r['speed_kmh'] as num?)?.toDouble() ?? 0.0);
        // GPS keys as written by SensorService: 'lat' / 'lon'
        lats.add((r['lat'] as num?)?.toDouble() ?? 0.0);
        lons.add((r['lon'] as num?)?.toDouble() ?? 0.0);
        vibrations.add((r['vibration'] as num?)?.toDouble() ?? 0.0);
        final ts = r['ts'] as String?;
        if (ts != null) {
          final dt = DateTime.tryParse(ts);
          if (dt != null) { startTime ??= dt; endTime = dt; }
        }
      }

      final avgPower = powers.fold(0.0, (a, b) => a + b) / powers.length;
      final cv       = _cv(powers);
      final avgSpeed = speeds.fold(0.0, (a, b) => a + b) / speeds.length;
      // Use the start GPS point for stable matching (not centroid)
      final startLat = lats.firstWhere((v) => v != 0.0, orElse: () => 0.0);
      final startLon = lons.firstWhere((v) => v != 0.0, orElse: () => 0.0);
      final duration  = window.length.toDouble(); // seconds at 1 Hz
      // Fix: avgSpeed is km/h → convert to m/s before multiplying by seconds
      final distance  = (avgSpeed / 3.6) * duration;
      final efficiency = avgPower > 0 ? avgSpeed / avgPower : 0.0;

      segments.add(ConstantPowerSegment(
        segmentIndex: segmentId,
        lapIndex: lapIdx,
        pressure: pressure,
        avgLat: startLat,
        avgLon: startLon,
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
      i = end; // advance past the entire confirmed window
    }

    return segments;
  }

  /// Detect constant-power windows and return raw per-sample arrays.
  /// Same growing-window CV logic as [_detectConstantPowerSegmentsFromJsonl]
  /// but retains per-sample speeds/distances/lats/lons for gate trimming.
  static List<_RawPowerSegment> _detectRawSegments(
    List<Map<String, dynamic>> records,
    int lapIdx,
    double pressure,
  ) {
    if (records.isEmpty) return [];

    final segments = <_RawPowerSegment>[];
    const segmentThreshold = 0.10;
    const minWindow = 10;

    int i = 0;
    int segmentId = 0;

    while (i + minWindow <= records.length) {
      List<double> powers = records
          .sublist(i, i + minWindow)
          .map((r) => (r['power'] as num?)?.toDouble() ?? 0.0)
          .where((p) => p > 0)
          .toList();

      if (powers.length < minWindow ~/ 2 || _cv(powers) >= segmentThreshold) {
        i++;
        continue;
      }

      int end = i + minWindow;
      while (end < records.length) {
        final p = (records[end]['power'] as num?)?.toDouble() ?? 0.0;
        if (p <= 0) break;
        final extended = [...powers, p];
        if (_cv(extended) >= segmentThreshold) break;
        powers = extended;
        end++;
      }

      final window        = records.sublist(i, end);
      final speeds        = <double>[];
      final distances     = <double>[];
      final lats          = <double>[];
      final lons          = <double>[];
      // Full-window powers aligned 1-to-1 with speeds/distances (no filtering).
      // The growing-window CV check uses the filtered 'powers' list above; we
      // store the unfiltered 'powersAligned' so array lengths always match.
      final powersAligned = <double>[];
      DateTime? startTime, endTime;

      for (final r in window) {
        speeds.add((r['speed_kmh'] as num?)?.toDouble() ?? 0.0);
        distances.add((r['distance'] as num?)?.toDouble() ?? 0.0);
        lats.add((r['lat'] as num?)?.toDouble() ?? 0.0);
        lons.add((r['lon'] as num?)?.toDouble() ?? 0.0);
        powersAligned.add((r['power'] as num?)?.toDouble() ?? 0.0);
        final ts = r['ts'] as String?;
        if (ts != null) {
          final dt = DateTime.tryParse(ts);
          if (dt != null) { startTime ??= dt; endTime = dt; }
        }
      }

      segments.add(_RawPowerSegment(
        lapIndex: lapIdx,
        segmentIndex: segmentId,
        pressure: pressure,
        powers: powersAligned,
        speeds: speeds,
        distances: distances,
        lats: lats,
        lons: lons,
        startTime: startTime ?? DateTime.now(),
        endTime: endTime ?? DateTime.now(),
      ));

      segmentId++;
      i = end;
    }

    return segments;
  }
  /// GPS radius for grouping segments from the same road section.
  static const double _gpsZoneRadiusM = 50.0;
  /// Loose power gate for zone membership — same effort level.
  static const double _zonePowerTolerancePct = 20.0;
  /// Minimum segment distance; filters accidental short blips.
  static const double _minSegmentDistanceM = 20.0;

  /// Group all detected segments by GPS zone, then compute per-lap
  /// distance-weighted average efficiency for each zone.
  ///
  /// A **zone** is a cluster of segment start-points within [_gpsZoneRadiusM].
  /// Duration is NOT used as a gate — one lap may contribute many short segments
  /// to a zone while another contributes one long segment; both are welcome.
  /// Each zone present in ALL laps produces one (pressure, efficiency) point
  /// per lap for the quadratic regression.
  static List<MatchedSegment> aggregateByGpsZone(
    List<List<ConstantPowerSegment>> allLaps,
  ) {
    if (allLaps.isEmpty) return [];
    final numLaps = allLaps.length;

    // ── Flatten and filter short blips ────────────────────────────────────────
    final all = <ConstantPowerSegment>[
      for (final lap in allLaps)
        ...lap.where((s) => s.distance >= _minSegmentDistanceM),
    ];

    if (all.isEmpty) {
      print('⚠ No segments ≥ ${_minSegmentDistanceM.toStringAsFixed(0)} m found across $numLaps laps');
      return [];
    }

    // ── GPS zone clustering (greedy, start-point only) ─────────────────────────
    final zones = <List<ConstantPowerSegment>>[];
    final used = <int>{};

    for (int i = 0; i < all.length; i++) {
      if (used.contains(i)) continue;
      final zone = [all[i]];
      used.add(i);
      for (int j = i + 1; j < all.length; j++) {
        if (used.contains(j)) continue;
        final d = ConstantPowerSegment._haversineDistance(
          all[i].avgLat, all[i].avgLon,
          all[j].avgLat, all[j].avgLon,
        );
        if (d > _gpsZoneRadiusM) continue;
        // Loose power gate — same effort level
        final maxP = math.max(all[i].avgPower, all[j].avgPower);
        if (maxP > 0) {
          final pct = (all[i].avgPower - all[j].avgPower).abs() / maxP * 100.0;
          if (pct > _zonePowerTolerancePct) continue;
        }
        zone.add(all[j]);
        used.add(j);
      }
      zones.add(zone);
    }

    print('📍 GPS zones found: ${zones.length} (${all.length} segments, $numLaps laps)');

    // ── Aggregate per zone ────────────────────────────────────────────────────
    final matched = <MatchedSegment>[];
    int zoneId = 0;

    for (final zone in zones) {
      // Group by lap
      final byLap = <int, List<ConstantPowerSegment>>{};
      for (final seg in zone) {
        byLap.putIfAbsent(seg.lapIndex, () => []).add(seg);
      }

      // Require representation in ALL laps
      if (byLap.length < numLaps) {
        print('✗ Zone $zoneId: ${byLap.length}/$numLaps laps — skipping');
        zoneId++;
        continue;
      }

      final pressures    = <double>[];
      final efficiencies = <double>[];
      final repByLap     = <int, ConstantPowerSegment>{};

      for (final lapIdx in byLap.keys.toList()..sort()) {
        final lapSegs = byLap[lapIdx]!;
        // Distance-weighted average efficiency for this lap in this zone
        final totalDist = lapSegs.fold(0.0, (s, seg) => s + seg.distance);
        final wavgEff = totalDist > 0
            ? lapSegs.fold(0.0, (s, seg) => s + seg.efficiency * seg.distance) / totalDist
            : lapSegs.fold(0.0, (s, seg) => s + seg.efficiency) / lapSegs.length;
        // Representative = longest segment
        final rep = lapSegs.reduce((a, b) => a.distance > b.distance ? a : b);
        pressures.add(rep.pressure);
        efficiencies.add(wavgEff);
        repByLap[lapIdx] = rep;
        print('  ↳ Zone $zoneId lap $lapIdx: ${lapSegs.length} seg(s) | '
            'pressure=${rep.pressure.toStringAsFixed(1)} psi | '
            'wavgEff=${wavgEff.toStringAsFixed(4)}');
      }

      print('✓ Zone $zoneId → ${pressures.length} regression points');
      matched.add(MatchedSegment(
        segmentId: zoneId,
        segmentsByLap: repByLap,
        pressures: pressures,
        efficiencies: efficiencies,
      ));
      zoneId++;
    }

    print('💾 Total zones for regression: ${matched.length}');
    return matched;
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Gate-trimmed analysis pipeline (preferred entry point)
  // ────────────────────────────────────────────────────────────────────────────

  /// Full constant-power analysis with Strava-style gate trimming.
  ///
  /// 1. Parse JSONL → raw per-sample segments per lap
  /// 2. GPS zone clustering (start ±50 m, power ±20%)
  /// 3. Per zone: exit gate = minimum segment distance; ratio gate ≥ 0.5
  /// 4. Trim every segment to the gate via linear interpolation
  /// 5. Distance-weighted efficiency per lap → [MatchedSegment] list
  static Future<List<MatchedSegment>> analyzeConstantPower(
    List<int> fitBytes,
    String jsonlPath, {
    double cda = 0.320,
    double rho = 1.204,
  }) async {
    final jsonlFile  = File(jsonlPath);
    final jsonlLines = await jsonlFile.readAsLines();

    final Map<int, List<Map<String, dynamic>>> recordsByLap = {};
    final Map<int, Map<String, dynamic>> lapMetadata = {};

    for (final line in jsonlLines) {
      if (line.trim().isEmpty) continue;
      try {
        final json   = jsonDecode(line) as Map<String, dynamic>;
        final lapIdx = json['lapIndex'] as int?;
        if (lapIdx == null) continue;
        if (json.containsKey('frontPressure')) lapMetadata[lapIdx] = json;
        if (json.containsKey('ts') || json.containsKey('power')) {
          recordsByLap.putIfAbsent(lapIdx, () => []).add(json);
        }
      } catch (e) {
        print('ERROR: Failed to parse JSONL line: $e');
      }
    }

    final rawLaps = <List<_RawPowerSegment>>[];
    for (int lapIdx = 0; lapIdx < recordsByLap.length; lapIdx++) {
      final records  = recordsByLap[lapIdx] ?? [];
      final metadata = lapMetadata[lapIdx]  ?? {};
      final pressure = (metadata['rearPressure'] as num?)?.toDouble() ?? 0.0;
      rawLaps.add(_detectRawSegments(records, lapIdx, pressure));
    }

    return _aggregateRawByGpsZone(rawLaps, rawLaps.length, cda: cda, rho: rho);
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Internal: GPS zone aggregation with gate trimming
  // ────────────────────────────────────────────────────────────────────────────

  static List<MatchedSegment> _aggregateRawByGpsZone(
    List<List<_RawPowerSegment>> rawLaps,
    int numLaps, {
    double cda = 0.320,
    double rho = 1.204,
  }) {
    // Flatten all raw segments. We do NOT pre-filter by length here since short
    // segments can still be fully contained within a valid overlap interval.
    final all = <_RawPowerSegment>[for (final lap in rawLaps) ...lap];

    if (all.isEmpty) {
      print('⚠ No raw segments found across $numLaps laps');
      return [];
    }

    // ── GPS zone clustering (greedy, start-point + power gate) ───────────────
    final zones = <List<_RawPowerSegment>>[];
    final used  = <int>{};

    for (int i = 0; i < all.length; i++) {
      if (used.contains(i)) continue;
      final zone = [all[i]];
      used.add(i);
      final avgPowI = all[i].powers.isEmpty ? 0.0
          : all[i].powers.fold(0.0, (a, b) => a + b) / all[i].powers.length;

      for (int j = i + 1; j < all.length; j++) {
        if (used.contains(j)) continue;
        final d = ConstantPowerSegment._haversineDistance(
          all[i].startLat, all[i].startLon,
          all[j].startLat, all[j].startLon,
        );
        if (d > _gpsZoneRadiusM) continue;
        final avgPowJ = all[j].powers.isEmpty ? 0.0
            : all[j].powers.fold(0.0, (a, b) => a + b) / all[j].powers.length;
        final maxP = math.max(avgPowI, avgPowJ);
        if (maxP > 0 &&
            (avgPowI - avgPowJ).abs() / maxP * 100.0 > _zonePowerTolerancePct) {
          continue;
        }
        zone.add(all[j]);
        used.add(j);
      }
      zones.add(zone);
    }

    print('📍 GPS zones (raw): ${zones.length} (${all.length} segments, $numLaps laps)');

    final matched = <MatchedSegment>[];
    int zoneId = 0;

    for (final zone in zones) {
      // ── Group by lap ──────────────────────────────────────────────────────
      final byLap = <int, List<_RawPowerSegment>>{};
      for (final seg in zone) {
        byLap.putIfAbsent(seg.lapIndex, () => []).add(seg);
      }

      if (byLap.length < numLaps) {
        print('✗ Zone $zoneId: ${byLap.length}/$numLaps laps — skipping');
        zoneId++;
        continue;
      }

      // ── Build coverage intervals per lap ──────────────────────────────────
      // Each raw segment covers [distances.first, distances.last] on the
      // per-lap cumulative wheel-distance axis, which is comparable across laps
      // because every lap starts at the same physical anchor point.
      final lapIntervals = <int, List<List<double>>>{};
      for (final entry in byLap.entries) {
        final raw = <List<double>>[];
        for (final seg in entry.value) {
          if (seg.distances.length < 2) continue;
          raw.add([seg.distances.first, seg.distances.last]);
        }
        lapIntervals[entry.key] = _mergeIntervals(raw);
      }

      // ── Sweep-line intersection: find road stretches ALL laps cover ───────
      final overlaps = _intersectAllLaps(lapIntervals, numLaps);
      final validOverlaps = overlaps
          .where((iv) => iv[1] - iv[0] >= _minSegmentDistanceM)
          .toList();

      if (validOverlaps.isEmpty) {
        print('✗ Zone $zoneId: no shared interval ≥'
            ' ${_minSegmentDistanceM.toStringAsFixed(0)} m — skipping');
        zoneId++;
        continue;
      }

      print('  ↳ Zone $zoneId: ${validOverlaps.length} valid overlap(s)'
          ' (${overlaps.length} raw) across $numLaps laps');

      // ── One MatchedSegment per valid overlap interval ─────────────────────
      for (final overlap in validOverlaps) {
        final entryGate = overlap[0];
        final exitGate  = overlap[1];
        final pressures    = <double>[];
        final efficiencies = <double>[];
        final repByLap     = <int, ConstantPowerSegment>{};

        for (final lapIdx in byLap.keys.toList()..sort()) {
          final lapSegs = byLap[lapIdx]!;
          double totalDist = 0.0;
          double wEff      = 0.0;
          ConstantPowerSegment? rep;

          for (final raw in lapSegs) {
            if (raw.distances.isEmpty) continue;
            // Skip segments with no overlap with this interval
            if (raw.distances.last < entryGate ||
                raw.distances.first > exitGate) { continue; }
            final extracted =
                _subExtractFromInterval(raw, entryGate, exitGate, cda, rho);
            if (extracted == null) continue;
            wEff      += extracted.efficiency * extracted.distance;
            totalDist += extracted.distance;
            rep ??= extracted;
          }

          if (totalDist == 0.0 || rep == null) continue;
          final wavgEff = wEff / totalDist;

          pressures.add(rep.pressure);
          efficiencies.add(wavgEff);
          repByLap[lapIdx] = ConstantPowerSegment(
            segmentIndex: rep.segmentIndex,
            lapIndex:     rep.lapIndex,
            pressure:     rep.pressure,
            avgLat:       rep.avgLat,
            avgLon:       rep.avgLon,
            avgPower:     rep.avgPower,
            cvPower:      rep.cvPower,
            avgSpeed:     rep.avgSpeed,
            distance:     totalDist,
            duration:     rep.duration,
            efficiency:   wavgEff,
            numRecords:   rep.numRecords,
            startTime:    rep.startTime,
            endTime:      rep.endTime,
          );
          print('    lap $lapIdx gate'
              ' [${entryGate.toStringAsFixed(0)}, ${exitGate.toStringAsFixed(0)}] m'
              ' | pressure=${rep.pressure.toStringAsFixed(1)} psi'
              ' | wavgEff=${wavgEff.toStringAsFixed(4)}');
        }

        if (pressures.length < numLaps) {
          print('✗   [${entryGate.toStringAsFixed(0)}, '
              '${exitGate.toStringAsFixed(0)}]: '
              '${pressures.length}/$numLaps laps — skipping');
          continue;
        }

        print('✓ Zone $zoneId overlap'
            ' [${entryGate.toStringAsFixed(0)}, ${exitGate.toStringAsFixed(0)}] m'
            ' → ${pressures.length} regression points');
        matched.add(MatchedSegment(
          segmentId:     zoneId,
          segmentsByLap: repByLap,
          pressures:     pressures,
          efficiencies:  efficiencies,
        ));
        zoneId++;
      }
    }

    print('💾 Total overlap zones for regression: ${matched.length}');
    return matched;
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Sweep-line overlap helpers
  // ────────────────────────────────────────────────────────────────────────────

  /// Merge overlapping / touching 1-D intervals.
  /// Input: list of [start, end] (each a 2-element list). Output: sorted, merged.
  static List<List<double>> _mergeIntervals(List<List<double>> intervals) {
    if (intervals.isEmpty) return [];
    final sorted = [...intervals]..sort((a, b) => a[0].compareTo(b[0]));
    final merged = [sorted.first.toList()];
    for (int i = 1; i < sorted.length; i++) {
      if (sorted[i][0] <= merged.last[1]) {
        merged.last[1] = math.max(merged.last[1], sorted[i][1]);
      } else {
        merged.add(sorted[i].toList());
      }
    }
    return merged;
  }

  /// Sweep-line intersection: find all contiguous intervals covered by EVERY lap.
  ///
  /// [lapIntervals] maps lapIndex → list of merged [start, end] intervals.
  /// Returns intervals where all [numLaps] laps are simultaneously active.
  static List<List<double>> _intersectAllLaps(
    Map<int, List<List<double>>> lapIntervals,
    int numLaps,
  ) {
    // Build events: (position, delta +1/-1, lapIndex)
    final events = <List<num>>[];
    for (final entry in lapIntervals.entries) {
      for (final iv in entry.value) {
        events.add([iv[0],  1, entry.key.toDouble()]);
        events.add([iv[1], -1, entry.key.toDouble()]);
      }
    }
    // Sort by position; opens (+1) before closes (-1) at same position
    events.sort((a, b) {
      final cmp = a[0].compareTo(b[0]);
      return cmp != 0 ? cmp : b[1].compareTo(a[1]);
    });

    final openLaps = <int>{};
    double? fullStart;
    final result = <List<double>>[];

    for (final event in events) {
      final pos   = event[0].toDouble();
      final delta = event[1].toInt();
      final lap   = event[2].toInt();

      // On close: if we had full coverage, record the interval
      if (delta == -1 && fullStart != null && pos > fullStart) {
        result.add([fullStart, pos]);
        fullStart = null;
      }

      // Update open set
      if (delta == 1) {
        openLaps.add(lap);
      } else {
        openLaps.remove(lap);
      }

      // Start tracking once all laps are simultaneously active
      if (openLaps.length == numLaps && fullStart == null) {
        fullStart = pos;
      }
    }
    return result;
  }

  /// Sub-extract a [_RawPowerSegment] to exactly the [entryGate..exitGate]
  /// interval, interpolating at both boundary crossings.
  ///
  /// Returns null if the segment does not span the full interval.
  static ConstantPowerSegment? _subExtractFromInterval(
    _RawPowerSegment raw,
    double entryGate,
    double exitGate,
    double cda,
    double rho,
  ) {
    if (raw.distances.isEmpty) return null;
    if (raw.distances.first > entryGate || raw.distances.last < exitGate) return null;

    double lerp(List<double> arr, int i, double f) {
      if (i + 1 >= arr.length) return arr[i];
      return arr[i] + f * (arr[i + 1] - arr[i]);
    }

    // Find entry crossing
    int    entryIdx  = 0;
    double entryFrac = 0.0;
    for (int i = 0; i < raw.distances.length - 1; i++) {
      if (raw.distances[i + 1] >= entryGate) {
        final span = raw.distances[i + 1] - raw.distances[i];
        entryFrac = span > 0 ? (entryGate - raw.distances[i]) / span : 0.0;
        entryIdx  = i;
        break;
      }
    }

    // Find exit crossing (search from entry onwards)
    int    exitIdx  = raw.distances.length - 1;
    double exitFrac = 0.0;
    for (int i = entryIdx; i < raw.distances.length - 1; i++) {
      if (raw.distances[i + 1] >= exitGate) {
        final span = raw.distances[i + 1] - raw.distances[i];
        exitFrac = span > 0 ? (exitGate - raw.distances[i]) / span : 0.0;
        exitIdx  = i;
        break;
      }
    }

    // Build slices with interpolated boundary samples
    final slicePow = <double>[lerp(raw.powers, entryIdx, entryFrac)];
    final sliceSpd = <double>[lerp(raw.speeds,  entryIdx, entryFrac)];
    for (int i = entryIdx + 1; i <= exitIdx; i++) {
      slicePow.add(raw.powers[i]);
      sliceSpd.add(raw.speeds[i]);
    }
    // Replace last sample with interpolated exit value (if range is non-trivial)
    if (exitIdx > entryIdx) {
      slicePow[slicePow.length - 1] = lerp(raw.powers, exitIdx, exitFrac);
      sliceSpd[sliceSpd.length - 1] = lerp(raw.speeds,  exitIdx, exitFrac);
    }

    if (slicePow.isEmpty) return null;

    final gateLength = exitGate - entryGate;
    final avgPow = slicePow.fold(0.0, (a, b) => a + b) / slicePow.length;
    final avgSpd = sliceSpd.fold(0.0, (a, b) => a + b) / sliceSpd.length;
    final duration = (exitIdx - entryIdx).toDouble() + exitFrac - entryFrac;

    // Aero-corrected rolling resistance residual: mean((P − 0.5·CdA·ρ·v³) / v)
    // speeds are in km/h → convert to m/s.  Units: kg·m/s² (= CRR × mass × g)
    double rrSum = 0.0;
    int rrCount = 0;
    for (int i = 0; i < slicePow.length; i++) {
      final vMs = sliceSpd[i] / 3.6;
      if (vMs > 0.5) {
        final pAero = 0.5 * cda * rho * vMs * vMs * vMs;
        rrSum += (slicePow[i] - pAero) / vMs;
        rrCount++;
      }
    }
    final rrResidual = rrCount > 0
        ? rrSum / rrCount
        : (avgPow > 0 ? avgSpd / avgPow : 0.0);

    return ConstantPowerSegment(
      segmentIndex: raw.segmentIndex,
      lapIndex:     raw.lapIndex,
      pressure:     raw.pressure,
      avgLat:       raw.startLat,
      avgLon:       raw.startLon,
      avgPower:     avgPow,
      cvPower:      _cv(slicePow),
      avgSpeed:     avgSpd,
      distance:     gateLength,
      duration:     duration,
      efficiency:   rrResidual,
      numRecords:   slicePow.length,
      startTime:    raw.startTime,
      endTime:      raw.endTime,
    );
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
