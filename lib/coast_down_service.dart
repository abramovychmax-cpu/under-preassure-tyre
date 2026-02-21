import 'dart:io';
import 'app_logger.dart';
import 'dart:convert';
import 'clustering_service.dart';

// Re-export DescentSegment as CoastDownRunData so analysis_page.dart keeps working
// without changing its type references.
typedef CoastDownRunData = DescentSegment;

/// Thin coast-down service: parses JSONL sensor files, groups records by lap,
/// extracts pressure metadata, then delegates to [CoastDownClusteringService]
/// for the 6-stage descent analysis pipeline.
class CoastDownService {
  /// Main entry point called by AnalysisPage.
  /// [jsonlPath] — path to the .jsonl companion file
  /// [fitBytes]  — raw FIT file bytes (used for lap pressure metadata fallback)
  /// Returns validated [CoastDownRunData] segments ready for regression.
  static Future<List<CoastDownRunData>> analyzeDescentRunsFromJsonl(
    String jsonlPath,
    List<int> fitBytes,
  ) async {
    // ── 1. Load and parse JSONL records ──
    final sensorRecordsPath = jsonlPath.replaceFirst('.jsonl', '.sensor_records.jsonl');
    final sensorFile = File(sensorRecordsPath);
    final jsonlFile = File(jsonlPath);

    // Try sensor_records.jsonl first (higher resolution), fall back to .jsonl
    final File sourceFile;
    if (sensorFile.existsSync()) {
      sourceFile = sensorFile;
      AppLogger.log('📂 Loading sensor records: $sensorRecordsPath');
    } else if (jsonlFile.existsSync()) {
      sourceFile = jsonlFile;
      AppLogger.log('📂 Loading JSONL: $jsonlPath');
    } else {
      throw Exception('No JSONL data file found at $jsonlPath');
    }

    final lines = await sourceFile.readAsLines();
    if (lines.isEmpty) {
      throw Exception('JSONL file is empty');
    }

    // ── 2. Parse metadata header and group records by lap ──
    final recordsByRun = <int, List<Map<String, dynamic>>>{};
    final runMetadata = <int, Map<String, dynamic>>{};

    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      try {
        final Map<String, dynamic> record =
            jsonDecode(line) as Map<String, dynamic>;

        final type = record['type'] as String? ?? 'record';

        if (type == 'lap' || type == 'lap_metadata') {
          // Lap metadata: contains pressure info
          final lapIdx = (record['lap_index'] as num?)?.toInt() ??
              (record['lapIndex'] as num?)?.toInt() ??
              recordsByRun.length;
          runMetadata[lapIdx] = record;
        } else if (type == 'record' || type == 'sensor') {
          // Sensor data point
          final lapIdx = (record['lap_index'] as num?)?.toInt() ??
              (record['lapIndex'] as num?)?.toInt() ??
              0;

          recordsByRun.putIfAbsent(lapIdx, () => []);
          recordsByRun[lapIdx]!.add(record);
        }
      } catch (e) {
        // Skip malformed lines
        continue;
      }
    }

    if (recordsByRun.isEmpty) {
      throw Exception('No sensor records found in JSONL');
    }

    // ── 3. Ensure metadata exists for each run ──
    // If lap metadata wasn't in JSONL, try to extract from FIT bytes
    for (final lapIdx in recordsByRun.keys) {
      if (!runMetadata.containsKey(lapIdx)) {
        runMetadata[lapIdx] = _extractPressureFromFit(fitBytes, lapIdx);
      }
    }

    AppLogger.log('📊 Parsed ${recordsByRun.length} runs, '
        '${runMetadata.length} metadata entries');

    // ── 4. Delegate to 6-stage clustering pipeline ──
    return CoastDownClusteringService.analyzeDescents(
      recordsByRun,
      runMetadata,
    );
  }

  /// Attempt to extract pressure metadata from FIT lap messages.
  /// Returns a map with frontPressure / rearPressure if found.
  static Map<String, dynamic> _extractPressureFromFit(
    List<int> fitBytes,
    int lapIndex,
  ) {
    // Minimal fallback — if pressure is embedded in FIT developer fields
    // this would parse them. For now return empty so the pipeline
    // uses whatever the JSONL had (pressure may be 0.0 → user warning).
    return {
      'frontPressure': 0.0,
      'rearPressure': 0.0,
    };
  }
}
